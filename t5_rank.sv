`default_nettype none

module t5_rank #(
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned Q      = 16
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,

  output logic              done,     // 1-cycle pulse (safe for wrapper capture)
  output logic              pass,     // 1-cycle pulse (safe for wrapper capture)
  output logic [31:0]       rfull,
  output logic [31:0]       rfullm1
);

  // ------------------------------------------------------------
  // Derived constants (matches TB assumptions for defaults)
  // ------------------------------------------------------------
  localparam int unsigned MATRIX_BITS       = Q*Q;               // 256
  localparam int unsigned NUM_MATRICES      = SMALLN / MATRIX_BITS;     // 8
  localparam int unsigned ROWS_PER_BLOCK    = BIGM / Q;                 // 8
  localparam int unsigned BLOCKS_PER_MATRIX = MATRIX_BITS / BIGM;       // 2

  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  // ------------------------------------------------------------
  // Block extraction (must match working version’s mapping)
  // ------------------------------------------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base      = SMALLN - (k+1)*BIGM;     // block k starts here
      get_block = trng[base +: BIGM];
    end
  endfunction

  // ------------------------------------------------------------
  // Working matrix storage
  // ------------------------------------------------------------
  logic [Q-1:0]     a [0:Q-1];
  logic [BIGM-1:0]  blk_hi, blk_lo;

  // Gaussian elimination control
  logic signed [$clog2(Q+1):0] col;        // signed so it can go negative
  logic [QW:0]                 pivot_row;  // 0..Q
  logic [QW:0]                 scan_row;   // 0..Q
  logic [QW-1:0]               sel_row;    // 0..Q-1
  logic                        found_pivot;
  logic [QW-1:0]               elim_row;   // 0..Q-1
  logic [QW:0]                 rank_reg;   // 0..Q

  // Matrix index / counters
  logic [MW-1:0] m_idx;
  logic [31:0]   rfull_run, rfullm1_run;

  // Output pulse control (IMPORTANT for wrapper)
  logic done_q, pass_q;
  assign done = done_q;
  assign pass = pass_q;

  logic done_sent; // ensures done/pass are exactly 1-cycle

  // ------------------------------------------------------------
  // FSM
  // ------------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE     = 4'd0,
    S_CAP      = 4'd1,
    S_UNPACK   = 4'd2,

    S_INIT     = 4'd3,
    S_SCAN     = 4'd4,
    S_SWAP     = 4'd5,
    S_ELIM     = 4'd6,
    S_ADV      = 4'd7,

    S_ACCUM    = 4'd8,
    S_PUBLISH  = 4'd9,   // write rfull/rfullm1 regs
    S_DONEPULSE= 4'd10,  // pulse done/pass ONE CYCLE AFTER publish
    S_HOLD     = 4'd11   // stay here until en drops
  } state_t;

  state_t state, next_state;

  // Next-state logic
  always_comb begin
    next_state = state;

    unique case (state)
      S_IDLE:      next_state = (en && start) ? S_CAP : S_IDLE;

      S_CAP:       next_state = S_UNPACK;
      S_UNPACK:    next_state = S_INIT;

      S_INIT:      next_state = S_SCAN;

      S_SCAN: begin
        if (pivot_row == Q || col < 0)
          next_state = S_ACCUM;
        else if (scan_row == Q)
          next_state = found_pivot ? S_SWAP : S_ADV;
        else
          next_state = S_SCAN;
      end

      S_SWAP:      next_state = S_ELIM;
      S_ELIM:      next_state = (elim_row == Q-1) ? S_ADV : S_ELIM;
      S_ADV:       next_state = S_SCAN;

      S_ACCUM:     next_state = (m_idx == (NUM_MATRICES-1)) ? S_PUBLISH : S_CAP;

      S_PUBLISH:   next_state = S_DONEPULSE;
      S_DONEPULSE: next_state = S_HOLD;
      S_HOLD:      next_state = en ? S_HOLD : S_IDLE;

      default:     next_state = S_IDLE;
    endcase
  end

  // ------------------------------------------------------------
  // Sequential
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;

      rfull       <= 32'd0;
      rfullm1     <= 32'd0;

      rfull_run   <= 32'd0;
      rfullm1_run <= 32'd0;
      m_idx       <= '0;

      blk_hi      <= '0;
      blk_lo      <= '0;

      col         <= '0;
      pivot_row   <= '0;
      scan_row    <= '0;
      sel_row     <= '0;
      found_pivot <= 1'b0;
      elim_row    <= '0;
      rank_reg    <= '0;

      done_q      <= 1'b0;
      pass_q      <= 1'b0;
      done_sent   <= 1'b0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      // defaults each cycle
      done_q <= 1'b0;
      pass_q <= 1'b0;

      unique case (state)

        // --------------------------------------------------
        // Start of run: clear counters, start at matrix 0
        // --------------------------------------------------
        S_IDLE: begin
          if (en && start) begin
            rfull_run   <= 32'd0;
            rfullm1_run <= 32'd0;
            m_idx       <= '0;
          end
        end

        // --------------------------------------------------
        // Capture the two 128b blocks for this matrix
        // --------------------------------------------------
        S_CAP: begin
          blk_hi <= get_block(int'(m_idx)*BLOCKS_PER_MATRIX + 0);
          blk_lo <= get_block(int'(m_idx)*BLOCKS_PER_MATRIX + 1);
        end

        // --------------------------------------------------
        // Unpack into 16 rows (matches TB mapping)
        // row0 comes from MSB chunk of blk_hi, etc.
        // --------------------------------------------------
        S_UNPACK: begin
          for (int r = 0; r < int'(ROWS_PER_BLOCK); r++) begin
            a[r]                  <= blk_hi[(ROWS_PER_BLOCK-1-r)*Q +: Q];
            a[r + ROWS_PER_BLOCK] <= blk_lo[(ROWS_PER_BLOCK-1-r)*Q +: Q];
          end
        end

        // --------------------------------------------------
        // Init elimination for this matrix
        // --------------------------------------------------
        S_INIT: begin
          rank_reg    <= '0;
          pivot_row   <= '0;
          col         <= $signed(int'(Q-1));

          scan_row    <= '0;     // start scanning at pivot_row = 0
          found_pivot <= 1'b0;
          sel_row     <= '0;
          elim_row    <= '0;
        end

        // --------------------------------------------------
        // Scan for pivot in current column
        // --------------------------------------------------
        S_SCAN: begin
          if (scan_row < Q) begin
            if (!found_pivot && a[scan_row][int'(col)]) begin
              found_pivot <= 1'b1;
              sel_row     <= scan_row[QW-1:0];
            end
            scan_row <= scan_row + 1'b1;
          end
        end

        // --------------------------------------------------
        // Swap selected pivot row into pivot_row
        // --------------------------------------------------
        S_SWAP: begin
          if (found_pivot && (sel_row != pivot_row[QW-1:0])) begin
            logic [Q-1:0] tmp;
            tmp                    = a[pivot_row[QW-1:0]];
            a[pivot_row[QW-1:0]]  <= a[sel_row];
            a[sel_row]            <= tmp;
          end
          elim_row <= '0;
        end

        // --------------------------------------------------
        // Eliminate rows one per cycle (pipelined)
        // --------------------------------------------------
        S_ELIM: begin
          int er;
          er = int'(elim_row);

          if (er != int'(pivot_row)) begin
            if (a[er][int'(col)]) begin
              a[er] <= a[er] ^ a[pivot_row[QW-1:0]];
            end
          end

          if (elim_row != Q-1)
            elim_row <= elim_row + 1'b1;
        end

        // --------------------------------------------------
        // Advance to next column, update rank/pivot_row if pivot found
        // --------------------------------------------------
        S_ADV: begin
          logic [QW:0] next_pivot;
          next_pivot = pivot_row + (found_pivot ? 1'b1 : 1'b0);

          if (found_pivot) begin
            rank_reg <= rank_reg + 1'b1;
          end

          pivot_row <= next_pivot;
          col       <= col - 1'sd1;

          // re-init scan for next column using next_pivot
          scan_row    <= next_pivot;
          found_pivot <= 1'b0;
          sel_row     <= '0;
          elim_row    <= '0;
        end

        // --------------------------------------------------
        // Accumulate this matrix result
        // --------------------------------------------------
        S_ACCUM: begin
          if (rank_reg == Q)        rfull_run   <= rfull_run + 32'd1;
          else if (rank_reg == Q-1) rfullm1_run <= rfullm1_run + 32'd1;

          if (m_idx != (NUM_MATRICES-1))
            m_idx <= m_idx + 1'b1;
        end

        // --------------------------------------------------
        // Publish final counters into output registers
        // IMPORTANT: do NOT pulse done here (NBA ordering issue)
        // --------------------------------------------------
        S_PUBLISH: begin
          rfull     <= rfull_run;
          rfullm1   <= rfullm1_run;
          done_sent <= 1'b0;       // arm pulse for next state
        end

        // --------------------------------------------------
        // Pulse done/pass ONE CYCLE AFTER publish
        // so wrapper captures updated rfull/rfullm1
        // --------------------------------------------------
        S_DONEPULSE: begin
          if (!done_sent) begin
            done_q    <= 1'b1;
            pass_q    <= 1'b1;
            done_sent <= 1'b1;
          end
        end

        // --------------------------------------------------
        // Hold until en drops (matches your wrapper behavior)
        // --------------------------------------------------
        S_HOLD: begin
          // nothing
        end

        default: ;
      endcase
    end
  end

endmodule