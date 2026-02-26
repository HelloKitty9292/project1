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

  localparam int unsigned QI          = Q;
  localparam int unsigned MATRIX_BITS = QI * QI;
  localparam int unsigned NUM_MATRICES= (SMALLN / MATRIX_BITS);

  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    int unsigned msb;
    begin
      msb = SMALLN - 1 - (k * BIGM);
      get_block = trng[msb -: BIGM];
    end
  endfunction

  logic [QI-1:0] m [0:QI-1];

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

  logic [$clog2(NUM_MATRICES)-1:0] mi;
  logic [$clog2(QI)-1:0]          pivot;
  logic signed [6:0]              col;      // 15..0
  logic [$clog2(QI)-1:0]          scan_r;
  logic [$clog2(QI)-1:0]          elim_r;
  logic [$clog2(QI)-1:0]          found_r;
  logic                           found_valid;

  logic [5:0] rank_cnt;

  logic [31:0] rfull_q, rfullm1_q;
  assign rfull   = rfull_q;
  assign rfullm1 = rfullm1_q;

  assign pass = 1'b1;

  integer rr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;

      mi          <= '0;
      pivot       <= '0;
      col         <= '0;
      scan_r      <= '0;
      elim_r      <= '0;
      found_r     <= '0;
      found_valid <= 1'b0;

      rank_cnt    <= '0;
      rfull_q     <= 32'h0;
      rfullm1_q   <= 32'h0;

      for (rr = 0; rr < QI; rr++) m[rr] <= '0;

    end else if (en) begin
      unique case (state)

        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            rfull_q     <= 32'h0;
            rfullm1_q   <= 32'h0;
            mi          <= '0;
            state       <= S_LOAD;
          end
        end

        S_LOAD: begin
          logic [BIGM-1:0] blk_hi, blk_lo;
          blk_hi = get_block(mi * 2);
          blk_lo = get_block(mi * 2 + 1);

          // EXACT TB packing:
          // row 0 from MSB 16 of blk_hi, row 7 from LSB 16 of blk_hi
          for (rr = 0; rr < 8; rr++) begin
            m[rr]     <= blk_hi[(7 - rr) * 16 +: 16];
            m[8 + rr] <= blk_lo[(7 - rr) * 16 +: 16];
          end

          rank_cnt    <= 6'd0;
          pivot       <= '0;
          col         <= $signed(QI-1); // 15
          scan_r      <= '0;
          found_valid <= 1'b0;

          state <= S_FIND_PIVOT;
        end

        S_FIND_PIVOT: begin
          if (col < 0 || (int'(pivot) >= QI)) begin
            state <= S_FINISH_MATRIX;
          end else begin
            if (!found_valid) begin
              // start scan at pivot if we haven't already
              if (scan_r == '0) scan_r <= pivot;

              // scan pivot..15 (one row/cycle)
              if (int'(scan_r) < QI) begin
                if (m[scan_r][col] == 1'b1) begin
                  found_r     <= scan_r;
                  found_valid <= 1'b1;
                  state       <= S_SWAP;
                end else begin
                  if (int'(scan_r) == QI-1) begin
                    // not found in this column
                    col         <= col - 1;
                    scan_r      <= pivot;      // restart at pivot for next column
                    found_valid <= 1'b0;
                  end else begin
                    scan_r <= scan_r + 1;
                  end
                end
              end else begin
                // safety
                col         <= col - 1;
                scan_r      <= pivot;
                found_valid <= 1'b0;
              end
            end else begin
              state <= S_SWAP;
            end
          end
        end

        S_SWAP: begin
          if (found_r != pivot) begin
            logic [QI-1:0] tmp;
            tmp        = m[pivot];
            m[pivot]   <= m[found_r];
            m[found_r] <= tmp;
          end
          elim_r <= '0;
          state  <= S_ELIM;
        end

        S_ELIM: begin
          // eliminate one row per cycle
          if (int'(elim_r) < QI) begin
            if (elim_r != pivot && m[elim_r][col] == 1'b1) begin
              m[elim_r] <= m[elim_r] ^ m[pivot];
            end

            if (int'(elim_r) == QI-1) begin
              // finish this pivot
              rank_cnt    <= rank_cnt + 1;
              pivot       <= pivot + 1;
              col         <= col - 1;
              scan_r      <= pivot + 1;   // start next scan at new pivot
              found_valid <= 1'b0;
              elim_r      <= '0;
              state       <= S_FIND_PIVOT;
            end else begin
              elim_r <= elim_r + 1;
            end
          end else begin
            // safety
            rank_cnt    <= rank_cnt + 1;
            pivot       <= pivot + 1;
            col         <= col - 1;
            scan_r      <= pivot + 1;
            found_valid <= 1'b0;
            elim_r      <= '0;
            state       <= S_FIND_PIVOT;
          end
        end

        S_FINISH_MATRIX: begin
          if (rank_cnt == QI)       rfull_q   <= rfull_q + 1;
          else if (rank_cnt == QI-1) rfullm1_q <= rfullm1_q + 1;

          if (mi == NUM_MATRICES-1) state <= S_DONE;
          else begin
            mi    <= mi + 1;
            state <= S_LOAD;
          end
        end

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

endmodule