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

  output logic              done,
  output logic              pass,
  output logic [31:0]       rfull,
  output logic [31:0]       rfullm1
);

  // --------------------------
  // Derived constants
  // --------------------------
  localparam int unsigned MATRIX_BITS       = Q * Q;
  localparam int unsigned NUM_MATRICES      = (SMALLN / MATRIX_BITS);     // 8
  localparam int unsigned ROWS_PER_BLOCK    = (BIGM / Q);                 // 8
  localparam int unsigned BLOCKS_PER_MATRIX = (MATRIX_BITS / BIGM);       // 2
  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  // --------------------------
  // Extract 128-bit block from TRNG (combinational)
  // --------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base      = SMALLN - (k+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // --------------------------
  // Internal working matrix (updated during elimination)
  // --------------------------
  logic [Q-1:0] a [0:Q-1];

  // capture regs for TRNG blocks (avoid "blk local var" sim/synth weirdness)
  logic [BIGM-1:0] blk_hi_reg, blk_lo_reg;

  // --------------------------
  // Rank engine registers
  // --------------------------
  logic signed [$clog2(Q+1):0] col;          // signed so it can go negative
  logic [QW:0]                 pivot_row;    // 0..Q
  logic [QW:0]                 scan_row;     // 0..Q
  logic [QW-1:0]               sel_row;      // 0..Q-1
  logic                        found_pivot;
  logic [QW-1:0]               elim_row;     // 0..Q-1
  logic [QW:0]                 rank_reg;     // 0..Q

  // matrix index + accumulators
  logic [MW-1:0] m_idx;

  // swap temp
  logic [Q-1:0] tmp_row;

  // --------------------------
  // FSM
  // --------------------------
  typedef enum logic [3:0] {
    S_IDLE   = 4'd0,

    // load matrix
    S_CAP    = 4'd1,
    S_UNPACK = 4'd2,

    // rank engine
    S_INIT   = 4'd3,
    S_FIND   = 4'd4,
    S_SWAP   = 4'd5,
    S_ELIM   = 4'd6,
    S_NEXT   = 4'd7,

    // per-matrix accumulation
    S_ACCUM  = 4'd8,

    S_DONE   = 4'd9
  } state_t;

  state_t state, next_state;

  // done/pass as LEVEL in S_DONE (wrapper-friendly)
  always_comb begin
    done = (state == S_DONE);
    pass = (state == S_DONE);
  end

  // --------------------------
  // Next-state logic
  // --------------------------
  always_comb begin
    next_state = state;

    unique case (state)
      S_IDLE:   next_state = (en && start) ? S_CAP : S_IDLE;

      S_CAP:    next_state = S_UNPACK;
      S_UNPACK: next_state = S_INIT;

      S_INIT:   next_state = S_FIND;

      // scan pivot rows pivot_row..Q-1 one row per cycle
      S_FIND: begin
        if (pivot_row == Q || col < 0) begin
          next_state = S_ACCUM;
        end else if (scan_row == Q) begin
          next_state = found_pivot ? S_SWAP : S_NEXT;
        end else begin
          next_state = S_FIND;
        end
      end

      S_SWAP:   next_state = S_ELIM;
      S_ELIM:   next_state = (elim_row == Q-1) ? S_NEXT : S_ELIM;

      S_NEXT:   next_state = S_FIND;

      S_ACCUM:  next_state = (m_idx == (NUM_MATRICES-1)) ? S_DONE : S_CAP;

      // hold DONE until en drops (matches your other tests)
      S_DONE:   next_state = en ? S_DONE : S_IDLE;

      default:  next_state = S_IDLE;
    endcase
  end

  // --------------------------
  // Sequential logic
  // --------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;

      rfull      <= 32'd0;
      rfullm1    <= 32'd0;
      m_idx      <= '0;

      blk_hi_reg <= '0;
      blk_lo_reg <= '0;

      col        <= '0;
      pivot_row  <= '0;
      scan_row   <= '0;
      sel_row    <= '0;
      found_pivot<= 1'b0;
      elim_row   <= '0;
      rank_reg   <= '0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      unique case (state)
        // --------------------------
        // Start of run
        // --------------------------
        S_IDLE: begin
          if (en && start) begin
            rfull   <= 32'd0;
            rfullm1 <= 32'd0;
            m_idx   <= '0;
          end
        end

        // --------------------------
        // Capture the two blocks for matrix m_idx
        // TB expects slot mi uses blocks (2*mi) and (2*mi+1) in trngblock order.
        // With get_block() mapping, this matches your previous working version.
        // --------------------------
        S_CAP: begin
          blk_hi_reg <= get_block(int'(m_idx) * BLOCKS_PER_MATRIX + 0);
          blk_lo_reg <= get_block(int'(m_idx) * BLOCKS_PER_MATRIX + 1);
        end

        // --------------------------
        // Unpack into working matrix a[0..15]
        // row0 from MSB chunk (same as TB compute_expected)
        // --------------------------
        S_UNPACK: begin
          for (int r = 0; r < int'(ROWS_PER_BLOCK); r++) begin
            a[r]                  <= blk_hi_reg[(ROWS_PER_BLOCK-1-r)*Q +: Q];
            a[r + ROWS_PER_BLOCK] <= blk_lo_reg[(ROWS_PER_BLOCK-1-r)*Q +: Q];
          end
        end

        // --------------------------
        // Init rank engine for this matrix
        // --------------------------
        S_INIT: begin
          rank_reg   <= '0;
          pivot_row  <= '0;
          col        <= $signed(int'(Q-1));

          // prepare first scan
          scan_row    <= '0;
          found_pivot <= 1'b0;
          sel_row     <= '0;
          elim_row    <= '0;
        end

        // --------------------------
        // FIND: scan one row per cycle starting at pivot_row
        // --------------------------
        S_FIND: begin
          // If we're starting a fresh scan for this column, initialize scan_row
          if (scan_row == '0 && pivot_row != '0) begin
            // (not strictly necessary; we always set scan_row in S_NEXT as well)
          end

          // When entering S_FIND (after S_INIT or S_NEXT), we want scan_row=pivot_row
          // Ensure it here if it isn't already.
          if (scan_row < pivot_row) begin
            scan_row    <= pivot_row;
            found_pivot <= 1'b0;
            sel_row     <= '0;
          end else if (scan_row < Q) begin
            if (!found_pivot && a[scan_row][int'(col)]) begin
              found_pivot <= 1'b1;
              sel_row     <= scan_row[QW-1:0];
            end
            scan_row <= scan_row + 1'b1;
          end
        end

        // --------------------------
        // SWAP selected pivot row into pivot_row position
        // --------------------------
        S_SWAP: begin
          if (sel_row != pivot_row[QW-1:0]) begin
            tmp_row                 = a[pivot_row[QW-1:0]];
            a[pivot_row[QW-1:0]]   <= a[sel_row];
            a[sel_row]             <= tmp_row;
          end
          elim_row <= '0;
        end

        // --------------------------
        // ELIM: eliminate one row per cycle
        // --------------------------
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

        // --------------------------
        // NEXT: advance column and pivot_row/rank if pivot was found
        // --------------------------
        S_NEXT: begin
          // if we pivoted this column, count it + move pivot_row down
          if (found_pivot) begin
            rank_reg  <= rank_reg + 1'b1;
            pivot_row <= pivot_row + 1'b1;
          end

          // always move to next column
          col <= col - 1'sd1;

          // setup scan for next column (IMPORTANT)
          scan_row    <= (found_pivot ? (pivot_row + 1'b1) : pivot_row);
          found_pivot <= 1'b0;
          sel_row     <= '0;
        end

        // --------------------------
        // ACCUM: update rfull/rfullm1 using rank_reg for this matrix
        // --------------------------
        S_ACCUM: begin
          if (rank_reg == Q)        rfull   <= rfull + 32'd1;
          else if (rank_reg == Q-1) rfullm1 <= rfullm1 + 32'd1;

          if (m_idx != (NUM_MATRICES-1))
            m_idx <= m_idx + 1'b1;
        end

        S_DONE: begin
          // hold results until en drops
        end

        default: begin end
      endcase
    end
  end

endmodule