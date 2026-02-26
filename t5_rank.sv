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
  localparam int unsigned NUM_MATRICES      = (SMALLN / MATRIX_BITS);

  localparam int unsigned ROWS_PER_BLOCK    = (BIGM / Q);          // e.g. 128/16 = 8
  localparam int unsigned BLOCKS_PER_MATRIX = (MATRIX_BITS / BIGM); // e.g. 256/128 = 2
  localparam int unsigned NUM_BLOCKS        = (SMALLN / BIGM);

  // --------------------------
  // Block extraction (combinational mux)
  // --------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      // block k starts at bit (SMALLN - (k+1)*BIGM)
      base      = SMALLN - (k+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // --------------------------
  // FSM + datapath regs
  // --------------------------
  enum logic [3:0] {S_IDLE   = 4'd0, S_LOAD0  = 4'd1, S_LOAD1  = 4'd2,
                    S_PIVOT  = 4'd3, S_ELIM   = 4'd4, S_NEXT   = 4'd5,
                    S_ACCUM  = 4'd6, S_DONE   = 4'd7} state, next_state;

  // Working matrix rows (GF(2)), updated over many cycles
  logic [Q-1:0] a [0:Q-1];

  // Two blocks for current matrix
  logic [BIGM-1:0] blk0_reg, blk1_reg;

  // Indices / counters
  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  logic [MW-1:0] m_idx;                 // 0..NUM_MATRICES-1
  logic [QW:0]   pivot_row;             // 0..Q
  logic signed [$clog2(Q+1):0] col;     // Q-1 .. -1 (signed)

  logic [QW-1:0] elim_r;                // 0..Q-1
  logic [QW:0]   rank_reg;              // 0..Q

  // Pivot selection (combinational in S_PIVOT)
  logic                  found_pivot;
  logic [QW-1:0]          sel_row;
  logic [Q-1:0]           pivot_vec;

  // --------------------------
  // Combinational pivot finder
  // --------------------------
  always_comb begin
    found_pivot = 1'b0;
    sel_row     = '0;

    // Only meaningful when col >= 0 and pivot_row < Q
    for (int r = 0; r < Q; r++) begin
      if (!found_pivot &&
          (r >= int'(pivot_row)) &&
          (col >= 0) &&
          a[r][col[$clog2(Q+1)-1:0]]) begin
        found_pivot = 1'b1;
        sel_row = r[QW-1:0];
      end
    end

    pivot_vec = a[pivot_row[QW-1:0]];
  end

  // --------------------------
  // Next-state logic
  // --------------------------
  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:   next_state = (en && start) ? S_LOAD0 : S_IDLE;
      S_LOAD0:  next_state = S_LOAD1;
      S_LOAD1:  next_state = S_PIVOT;

      // If finished this matrix, go accumulate; else pivot/eliminate
      S_PIVOT: begin
        if (pivot_row == Q || col < 0) next_state = S_ACCUM;
        else if (found_pivot)          next_state = S_ELIM;
        else                           next_state = S_NEXT; // no pivot in this col -> just col--
      end

      S_ELIM:   next_state = (elim_r == (Q-1)) ? S_NEXT : S_ELIM;

      // After a column step, either continue or finish
      S_NEXT:   next_state = S_PIVOT;

      // After rank computed, update counters / advance matrix
      S_ACCUM:  next_state = (m_idx == (NUM_MATRICES-1)) ? S_DONE : S_LOAD0;

      S_DONE:   next_state = en ? S_DONE : S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  // --------------------------
  // Outputs (simple: valid only in DONE)
  // --------------------------
  always_comb begin
    done = (state == S_DONE);
    pass = (state == S_DONE); // T5 here: no threshold in your simplified spec
  end

  // --------------------------
  // Sequential datapath
  // --------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      rfull    <= 32'd0;
      rfullm1  <= 32'd0;

      m_idx    <= '0;
      blk0_reg <= '0;
      blk1_reg <= '0;

      pivot_row <= '0;
      col       <= '0;
      elim_r    <= '0;
      rank_reg  <= '0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      unique case (state)
        S_IDLE: begin
          if (en && start) begin
            // Fresh run
            rfull    <= 32'd0;
            rfullm1  <= 32'd0;
            m_idx    <= '0;

            // Init rank engine for first matrix (after load)
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;
          end
        end

        S_LOAD0: begin
          // Capture block 0 of matrix m_idx
          blk0_reg <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 0);

          // Prep rank engine (safe to re-init here)
          pivot_row <= '0;
          col       <= $signed(int'(Q-1));
          elim_r    <= '0;
          rank_reg  <= '0;
        end

        S_LOAD1: begin
          // Capture block 1 and unpack rows into a[0..Q-1]
          blk1_reg <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 1);

          // Unpack blk0_reg -> a[0..ROWS_PER_BLOCK-1]
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk] <= blk0_reg[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
          // Unpack blk1 (combinational get_block just captured, but use get_block again or blk1_reg next cycle)
          // Use get_block directly to avoid 1-cycle latency on blk1_reg.
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk + int'(ROWS_PER_BLOCK)]
              <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 1)[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
        end

        S_PIVOT: begin
          if (!(pivot_row == Q || col < 0)) begin
            if (found_pivot) begin
              // Swap pivot_row <-> sel_row if needed
              if (sel_row != pivot_row[QW-1:0]) begin
                logic [Q-1:0] tmp;
                tmp                   = a[pivot_row[QW-1:0]];
                a[pivot_row[QW-1:0]] <= a[sel_row];
                a[sel_row]           <= tmp;
              end
              // Start elimination over rows
              elim_r <= '0;
            end
            // else: no pivot, handled in S_NEXT by col--
          end
        end

        S_ELIM: begin
          // Row-by-row elimination against current pivot row and current col
          int rr;
          rr = int'(elim_r);

          // Use updated pivot row vector (after possible swap) from array
          logic [Q-1:0] piv;
          piv = a[pivot_row[QW-1:0]];

          if (rr != int'(pivot_row) && col >= 0) begin
            int cidx;
            cidx = int'(col);
            if (a[rr][cidx]) begin
              a[rr] <= a[rr] ^ piv;
            end
          end

          // Advance row counter
          if (elim_r != (Q-1)) elim_r <= elim_r + 1'b1;
        end

        S_NEXT: begin
          // Decide what to do after a pivot/elimination attempt on this column
          if (!(pivot_row == Q || col < 0)) begin
            if (found_pivot) begin
              // Successful pivot => rank++ and pivot_row++
              rank_reg  <= rank_reg + 1'b1;
              pivot_row <= pivot_row + 1'b1;
            end
            // Move to next column regardless
            col <= col - 1'sd1;
          end
        end

        S_ACCUM: begin
          // Update counts based on final rank of this matrix
          if (rank_reg == Q[QW:0])        rfull   <= rfull + 32'd1;
          else if (rank_reg == (Q-1)[QW:0]) rfullm1 <= rfullm1 + 32'd1;

          // Advance to next matrix (or finish)
          if (m_idx != (NUM_MATRICES-1)) begin
            m_idx <= m_idx + 1'b1;

            // Prep next matrix rank engine (LOAD0 will also init)
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;
          end
        end

        S_DONE: begin
          // Hold results until en deasserts (then back to IDLE)
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule
