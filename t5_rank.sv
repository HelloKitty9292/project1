`default_nettype none

module t5_rank #(
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned Q      = 16
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  en,
  input  logic                  start,
  input  logic [SMALLN-1:0]     trng,

  output logic                  done,
  output logic                  pass,
  output logic [31:0]           rfull,
  output logic [31:0]           rfullm1
);

  // 2048 / (16*16) = 8 matrices for default params
  localparam int unsigned MATRIX_BITS  = Q * Q;
  localparam int unsigned NUM_MATRICES = (SMALLN / MATRIX_BITS);

  // ----------------------------
  // Helper: get 128-bit block k
  // Matches TB: trng = {blk0, blk1, ..., blk15}
  // So blk0 is MSBs of trng.
  // ----------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] msb;
    begin
      msb = SMALLN - 1 - (k * BIGM);
      get_block = trng[msb -: BIGM];
    end
  endfunction

  // Working matrix rows (16 rows of 16 bits)
  logic [Q-1:0] m [0:Q-1];

  // Rank engine state
  typedef enum logic [3:0] {
    S_IDLE,
    S_LOAD,
    S_FIND_PIVOT,
    S_SWAP,
    S_ELIM,
    S_FINISH_MATRIX,
    S_DONE
  } state_t;

  state_t state;

  // Indices/counters
  logic [$clog2(NUM_MATRICES)-1:0] mi;      // matrix index 0..NUM_MATRICES-1
  logic [$clog2(Q)-1:0]            pivot;   // pivot row
  logic signed [6:0]               col;     // 15..0, signed so we can go <0
  logic [$clog2(Q)-1:0]            scan_r;  // scanning rows for pivot
  logic [$clog2(Q)-1:0]            elim_r;  // elimination row index
  logic [$clog2(Q)-1:0]            found_r; // found pivot row
  logic                            found_valid;

  logic [5:0] rank_cnt; // up to 16

  // Outputs are registered
  logic [31:0] rfull_q, rfullm1_q;
  assign rfull   = rfull_q;
  assign rfullm1 = rfullm1_q;

  // Spec: T5 always "passes" (SW interprets counters)
  assign pass = 1'b1;

  // ----------------------------
  // Main FSM
  // ----------------------------
  integer rr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;

      mi         <= '0;
      pivot      <= '0;
      col        <= '0;
      scan_r     <= '0;
      elim_r     <= '0;
      found_r    <= '0;
      found_valid<= 1'b0;

      rank_cnt   <= '0;
      rfull_q    <= 32'h0;
      rfullm1_q  <= 32'h0;

      for (rr = 0; rr < Q; rr++) m[rr] <= '0;

    end else begin
      // If not enabled, hold everything (wrapper keeps en=1 during RUN)
      if (!en) begin
        // do nothing
      end else begin
        unique case (state)

          // ------------------------
          // IDLE: wait for start
          // ------------------------
          S_IDLE: begin
            done <= 1'b0;
            if (start) begin
              rfull_q   <= 32'h0;
              rfullm1_q <= 32'h0;
              mi        <= '0;
              state     <= S_LOAD;
            end
          end

          // ------------------------
          // LOAD: load matrix mi from two 128-bit blocks, exactly like TB
          // rows 0..7 from blk_hi MSB-first, rows 8..15 from blk_lo MSB-first
          // ------------------------
          S_LOAD: begin
            logic [BIGM-1:0] blk_hi, blk_lo;
            blk_hi = get_block(mi * 2);
            blk_lo = get_block(mi * 2 + 1);

            for (rr = 0; rr < 8; rr++) begin
              m[rr]     <= blk_hi[(7 - rr) * 16 +: 16];
              m[8 + rr] <= blk_lo[(7 - rr) * 16 +: 16];
            end

            rank_cnt    <= 6'd0;
            pivot       <= '0;
            col         <= $signed(Q-1); // 15
            scan_r      <= '0;
            found_valid <= 1'b0;

            state <= S_FIND_PIVOT;
          end

          // ------------------------
          // FIND_PIVOT: scan rows pivot..15 to find first row with 1 in column col
          // ------------------------
          S_FIND_PIVOT: begin
            if (col < 0 || pivot == Q[$clog2(Q)-1:0]) begin
              // done with elimination for this matrix
              state <= S_FINISH_MATRIX;
            end else begin
              // initialize scan on first entry into this state for this column
              if (!found_valid && scan_r == '0) begin
                scan_r <= pivot;
              end

              // scanning
              if (scan_r < Q[$clog2(Q)-1:0]) begin
                if (m[scan_r][col] == 1'b1 && !found_valid) begin
                  found_r     <= scan_r;
                  found_valid <= 1'b1;
                  state       <= S_SWAP;
                end else begin
                  // continue scan
                  if (scan_r == Q-1) begin
                    // not found in this column
                    col        <= col - 1;
                    scan_r     <= pivot;
                    found_valid<= 1'b0;
                  end else begin
                    scan_r <= scan_r + 1;
                  end
                end
              end else begin
                // safety
                col        <= col - 1;
                scan_r     <= pivot;
                found_valid<= 1'b0;
              end
            end
          end

          // ------------------------
          // SWAP: swap pivot row with found row (if different), then eliminate
          // ------------------------
          S_SWAP: begin
            if (found_valid) begin
              if (found_r != pivot) begin
                logic [Q-1:0] tmp;
                tmp        = m[pivot];
                m[pivot]   <= m[found_r];
                m[found_r] <= tmp;
              end
              elim_r <= '0;
              state  <= S_ELIM;
            end else begin
              // shouldn't happen; go try next column
              col    <= col - 1;
              scan_r <= pivot;
              state  <= S_FIND_PIVOT;
            end
          end

          // ------------------------
          // ELIM: for all rows r != pivot, if m[r][col]==1, do m[r] ^= m[pivot]
          // One row per cycle (fast enough for 200MHz).
          // ------------------------
          S_ELIM: begin
            if (elim_r < Q[$clog2(Q)-1:0]) begin
              if (elim_r != pivot && m[elim_r][col] == 1'b1) begin
                m[elim_r] <= m[elim_r] ^ m[pivot];
              end
              if (elim_r == Q-1) begin
                // finished elimination for this column
                rank_cnt    <= rank_cnt + 1;
                pivot       <= pivot + 1;
                col         <= col - 1;
                scan_r      <= pivot + 1; // next pivot start
                found_valid <= 1'b0;
                elim_r      <= '0;
                state       <= S_FIND_PIVOT;
              end else begin
                elim_r <= elim_r + 1;
              end
            end else begin
              // safety: treat as done
              rank_cnt    <= rank_cnt + 1;
              pivot       <= pivot + 1;
              col         <= col - 1;
              scan_r      <= pivot + 1;
              found_valid <= 1'b0;
              elim_r      <= '0;
              state       <= S_FIND_PIVOT;
            end
          end

          // ------------------------
          // FINISH_MATRIX: update counters, move to next matrix or done
          // ------------------------
          S_FINISH_MATRIX: begin
            if (rank_cnt == Q) begin
              rfull_q <= rfull_q + 1;
            end else if (rank_cnt == (Q-1)) begin
              rfullm1_q <= rfullm1_q + 1;
            end

            if (mi == NUM_MATRICES-1) begin
              state <= S_DONE;
            end else begin
              mi    <= mi + 1;
              state <= S_LOAD;
            end
          end

          // ------------------------
          // DONE: hold done=1 until next start (wrapper will clear sr_done/result on start)
          // ------------------------
          S_DONE: begin
            done <= 1'b1;
            if (start) begin
              done      <= 1'b0;
              rfull_q   <= 32'h0;
              rfullm1_q <= 32'h0;
              mi        <= '0;
              state     <= S_LOAD;
            end
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

endmodule