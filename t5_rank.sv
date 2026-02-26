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
  localparam int unsigned ROWS_PER_BLOCK    = (BIGM / Q);
  localparam int unsigned BLOCKS_PER_MATRIX = (MATRIX_BITS / BIGM);

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
  enum logic [3:0] {
    S_IDLE   = 4'd0, S_LOAD0  = 4'd1, S_LOAD1  = 4'd2,
    S_PIVOT  = 4'd3, S_ELIM   = 4'd4, S_NEXT   = 4'd5,
    S_ACCUM  = 4'd6, S_DONE   = 4'd7
  } state, next_state;

  // Working matrix rows (GF(2)), updated over many cycles
  logic [Q-1:0] a [0:Q-1];
  logic [BIGM-1:0] blk0_reg;

  // Indices / counters
  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : myclog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : myclog2(Q);

  logic [MW-1:0] m_idx;
  logic [QW:0]   pivot_row;
  logic signed [myclog2(Q+1):0] col;

  logic [QW-1:0] elim_r;
  logic [QW:0]   rank_reg;

  // Pivot finder (combinational)
  logic         found_pivot;
  logic [QW-1:0] sel_row;

  // Registered pivot decision (FFs, not latches)
  logic         had_pivot_q;
  logic [QW-1:0] pivot_idx_q;
  logic signed [myclog2(Q+1):0] col_q;

  // Temps (declared outside procedural blocks for tool compatibility)
  logic [Q-1:0] tmp_row;
  logic [Q-1:0] piv_row;
  int           rr;
  int           cidx;

  // --------------------------
  // Pivot finder
  // --------------------------
  always_comb begin
    found_pivot = 1'b0;
    sel_row     = '0;

    if (col >= 0) begin
      for (int r = 0; r < Q; r++) begin
        if (!found_pivot &&
            (r >= int'(pivot_row)) &&
            a[r][int'(col)]) begin
          found_pivot = 1'b1;
          sel_row     = r[QW-1:0];
        end
      end
    end
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

      S_PIVOT: begin
        if (pivot_row == Q || col < 0) next_state = S_ACCUM;
        else if (found_pivot)          next_state = S_ELIM;
        else                           next_state = S_NEXT;
      end

      S_ELIM:   next_state = (elim_r == (Q-1)) ? S_NEXT : S_ELIM;
      S_NEXT:   next_state = S_PIVOT;
      S_ACCUM:  next_state = (m_idx == (NUM_MATRICES-1)) ? S_DONE : S_LOAD0;
      S_DONE:   next_state = en ? S_DONE : S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  // --------------------------
  // Outputs
  // --------------------------
  always_comb begin
    done = (state == S_DONE);
    // In this lab version, T5 "pass" is simply "finished".
    // If you later add threshold checks, compute them in S_ACCUM/S_DONE.
    pass = (state == S_DONE);
  end

  // --------------------------
  // Sequential datapath
  // --------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      rfull     <= 32'd0;
      rfullm1   <= 32'd0;

      m_idx     <= '0;
      blk0_reg  <= '0;

      pivot_row <= '0;
      col       <= '0;
      elim_r    <= '0;
      rank_reg  <= '0;

      had_pivot_q <= 1'b0;
      pivot_idx_q <= '0;
      col_q       <= '0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          if (en && start) begin
            // Fresh run
            rfull     <= 32'd0;
            rfullm1   <= 32'd0;
            m_idx     <= '0;

            // Init rank engine for matrix 0
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;

            had_pivot_q <= 1'b0;
            pivot_idx_q <= '0;
            col_q       <= '0;
          end
        end

        S_LOAD0: begin
          // Capture block 0 of matrix m_idx
          blk0_reg  <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 0);

          // Prep rank engine for this matrix
          pivot_row <= '0;
          col       <= $signed(int'(Q-1));
          elim_r    <= '0;
          rank_reg  <= '0;

          had_pivot_q <= 1'b0;
          pivot_idx_q <= '0;
          col_q       <= '0;
        end

        S_LOAD1: begin
          // Unpack block0 into top half of rows
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk] <= blk0_reg[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
          // Unpack block1 directly into bottom half of rows
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk + int'(ROWS_PER_BLOCK)]
              <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 1)[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
        end

        S_PIVOT: begin
          // Default each column attempt
          had_pivot_q <= 1'b0;

          if (!(pivot_row == Q || col < 0)) begin
            if (found_pivot) begin
              // Register pivot info for ELIM/NEXT
              had_pivot_q <= 1'b1;
              pivot_idx_q <= pivot_row[QW-1:0];
              col_q       <= col;

              // Swap selected row into pivot_row position if needed
              if (sel_row != pivot_row[QW-1:0]) begin
                tmp_row               = a[pivot_row[QW-1:0]];
                a[pivot_row[QW-1:0]] <= a[sel_row];
                a[sel_row]           <= tmp_row;
              end

              // Start eliminating at row 0
              elim_r <= '0;
            end
          end
        end

        S_ELIM: begin
          rr   = int'(elim_r);
          cidx = int'(col_q);

          piv_row = a[pivot_idx_q];

          // Eliminate this row if it has a '1' in the pivot column
          if (rr != int'(pivot_idx_q)) begin
            if (a[rr][cidx]) begin
              a[rr] <= a[rr] ^ piv_row;
            end
          end

          // Next row
          if (elim_r != (Q-1)) elim_r <= elim_r + 1'b1;
        end

        S_NEXT: begin
          if (!(pivot_row == Q || col < 0)) begin
            if (had_pivot_q) begin
              rank_reg  <= rank_reg + 1'b1;
              pivot_row <= pivot_row + 1'b1;
            end
            col <= col - 1'sd1;
          end
        end

        S_ACCUM: begin
          // Update counts for this matrix
          if (rank_reg == Q)        rfull   <= rfull + 32'd1;
          else if (rank_reg == Q-1) rfullm1 <= rfullm1 + 32'd1;

          // Next matrix (or finish)
          if (m_idx != (NUM_MATRICES-1)) begin
            m_idx     <= m_idx + 1'b1;

            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;

            had_pivot_q <= 1'b0;
            pivot_idx_q <= '0;
            col_q       <= '0;
          end
        end

        S_DONE: begin
          // Hold until en deasserts, next_state handles return to IDLE
        end

        default: begin end
      endcase
    end
  end

endmodule`default_nettype none

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
  localparam int unsigned ROWS_PER_BLOCK    = (BIGM / Q);
  localparam int unsigned BLOCKS_PER_MATRIX = (MATRIX_BITS / BIGM);

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
  enum logic [3:0] {
    S_IDLE   = 4'd0, S_LOAD0  = 4'd1, S_LOAD1  = 4'd2,
    S_PIVOT  = 4'd3, S_ELIM   = 4'd4, S_NEXT   = 4'd5,
    S_ACCUM  = 4'd6, S_DONE   = 4'd7
  } state, next_state;

  // Working matrix rows (GF(2)), updated over many cycles
  logic [Q-1:0] a [0:Q-1];
  logic [BIGM-1:0] blk0_reg;

  // Indices / counters
  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : myclog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : myclog2(Q);

  logic [MW-1:0] m_idx;
  logic [QW:0]   pivot_row;
  logic signed [myclog2(Q+1):0] col;

  logic [QW-1:0] elim_r;
  logic [QW:0]   rank_reg;

  // Pivot finder (combinational)
  logic         found_pivot;
  logic [QW-1:0] sel_row;

  // Registered pivot decision (FFs, not latches)
  logic         had_pivot_q;
  logic [QW-1:0] pivot_idx_q;
  logic signed [myclog2(Q+1):0] col_q;

  // Temps (declared outside procedural blocks for tool compatibility)
  logic [Q-1:0] tmp_row;
  logic [Q-1:0] piv_row;
  int           rr;
  int           cidx;

  // --------------------------
  // Pivot finder
  // --------------------------
  always_comb begin
    found_pivot = 1'b0;
    sel_row     = '0;

    if (col >= 0) begin
      for (int r = 0; r < Q; r++) begin
        if (!found_pivot &&
            (r >= int'(pivot_row)) &&
            a[r][int'(col)]) begin
          found_pivot = 1'b1;
          sel_row     = r[QW-1:0];
        end
      end
    end
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

      S_PIVOT: begin
        if (pivot_row == Q || col < 0) next_state = S_ACCUM;
        else if (found_pivot)          next_state = S_ELIM;
        else                           next_state = S_NEXT;
      end

      S_ELIM:   next_state = (elim_r == (Q-1)) ? S_NEXT : S_ELIM;
      S_NEXT:   next_state = S_PIVOT;
      S_ACCUM:  next_state = (m_idx == (NUM_MATRICES-1)) ? S_DONE : S_LOAD0;
      S_DONE:   next_state = en ? S_DONE : S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  // --------------------------
  // Outputs
  // --------------------------
  always_comb begin
    done = (state == S_DONE);
    // In this lab version, T5 "pass" is simply "finished".
    // If you later add threshold checks, compute them in S_ACCUM/S_DONE.
    pass = (state == S_DONE);
  end

  // --------------------------
  // Sequential datapath
  // --------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      rfull     <= 32'd0;
      rfullm1   <= 32'd0;

      m_idx     <= '0;
      blk0_reg  <= '0;

      pivot_row <= '0;
      col       <= '0;
      elim_r    <= '0;
      rank_reg  <= '0;

      had_pivot_q <= 1'b0;
      pivot_idx_q <= '0;
      col_q       <= '0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          if (en && start) begin
            // Fresh run
            rfull     <= 32'd0;
            rfullm1   <= 32'd0;
            m_idx     <= '0;

            // Init rank engine for matrix 0
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;

            had_pivot_q <= 1'b0;
            pivot_idx_q <= '0;
            col_q       <= '0;
          end
        end

        S_LOAD0: begin
          // Capture block 0 of matrix m_idx
          blk0_reg  <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 0);

          // Prep rank engine for this matrix
          pivot_row <= '0;
          col       <= $signed(int'(Q-1));
          elim_r    <= '0;
          rank_reg  <= '0;

          had_pivot_q <= 1'b0;
          pivot_idx_q <= '0;
          col_q       <= '0;
        end

        S_LOAD1: begin
          // Unpack block0 into top half of rows
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk] <= blk0_reg[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
          // Unpack block1 directly into bottom half of rows
          for (int rblk = 0; rblk < int'(ROWS_PER_BLOCK); rblk++) begin
            a[rblk + int'(ROWS_PER_BLOCK)]
              <= get_block(int'(m_idx) * int'(BLOCKS_PER_MATRIX) + 1)[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          end
        end

        S_PIVOT: begin
          // Default each column attempt
          had_pivot_q <= 1'b0;

          if (!(pivot_row == Q || col < 0)) begin
            if (found_pivot) begin
              // Register pivot info for ELIM/NEXT
              had_pivot_q <= 1'b1;
              pivot_idx_q <= pivot_row[QW-1:0];
              col_q       <= col;

              // Swap selected row into pivot_row position if needed
              if (sel_row != pivot_row[QW-1:0]) begin
                tmp_row               = a[pivot_row[QW-1:0]];
                a[pivot_row[QW-1:0]] <= a[sel_row];
                a[sel_row]           <= tmp_row;
              end

              // Start eliminating at row 0
              elim_r <= '0;
            end
          end
        end

        S_ELIM: begin
          rr   = int'(elim_r);
          cidx = int'(col_q);

          piv_row = a[pivot_idx_q];

          // Eliminate this row if it has a '1' in the pivot column
          if (rr != int'(pivot_idx_q)) begin
            if (a[rr][cidx]) begin
              a[rr] <= a[rr] ^ piv_row;
            end
          end

          // Next row
          if (elim_r != (Q-1)) elim_r <= elim_r + 1'b1;
        end

        S_NEXT: begin
          if (!(pivot_row == Q || col < 0)) begin
            if (had_pivot_q) begin
              rank_reg  <= rank_reg + 1'b1;
              pivot_row <= pivot_row + 1'b1;
            end
            col <= col - 1'sd1;
          end
        end

        S_ACCUM: begin
          // Update counts for this matrix
          if (rank_reg == Q)        rfull   <= rfull + 32'd1;
          else if (rank_reg == Q-1) rfullm1 <= rfullm1 + 32'd1;

          // Next matrix (or finish)
          if (m_idx != (NUM_MATRICES-1)) begin
            m_idx     <= m_idx + 1'b1;

            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
            elim_r    <= '0;
            rank_reg  <= '0;

            had_pivot_q <= 1'b0;
            pivot_idx_q <= '0;
            col_q       <= '0;
          end
        end

        S_DONE: begin
          // Hold until en deasserts, next_state handles return to IDLE
        end

        default: begin end
      endcase
    end
  end

endmodule