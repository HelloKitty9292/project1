`default_nettype none

module t5_rank #(
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned Q      = 16
)(
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

  // --------------------------------------------------
  // Derived constants
  // --------------------------------------------------

  localparam int unsigned MATRIX_BITS       = Q * Q;
  localparam int unsigned NUM_MATRICES      = SMALLN / MATRIX_BITS;
  localparam int unsigned ROWS_PER_BLOCK    = BIGM / Q;
  localparam int unsigned BLOCKS_PER_MATRIX = MATRIX_BITS / BIGM;

  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);

  // --------------------------------------------------
  // Extract 128-bit block from TRNG
  // --------------------------------------------------

  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base      = SMALLN - (k+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // --------------------------------------------------
  // Matrix buffer (16 rows of 16 bits)
  // --------------------------------------------------

  logic [Q-1:0] rows_buf [0:Q-1];

  // --------------------------------------------------
  // GF2 rank engine interface
  // --------------------------------------------------

  logic        gf2_start;
  logic        gf2_done;
  logic [31:0] gf2_rank;

  gf2_rank_q #(.Q(Q)) gf2_core (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (gf2_start),
    .rows_in  (rows_buf),
    .rank     (gf2_rank),
    .done     (gf2_done)
  );

  // --------------------------------------------------
  // FSM
  // --------------------------------------------------

  typedef enum logic [2:0] {
    S_IDLE,
    S_LOAD,
    S_START,
    S_WAIT,
    S_ACCUM,
    S_DONE
  } state_t;

  state_t state, next_state;

  logic [MW-1:0] matrix_idx;

  // --------------------------------------------------
  // Next-state logic
  // --------------------------------------------------

  always_comb begin
    next_state = state;

    unique case (state)

      S_IDLE:
        next_state = (en && start) ? S_LOAD : S_IDLE;

      S_LOAD:
        next_state = S_START;

      S_START:
        next_state = S_WAIT;

      S_WAIT:
        next_state = (gf2_done) ? S_ACCUM : S_WAIT;

      S_ACCUM:
        next_state = (matrix_idx == NUM_MATRICES-1) ? S_DONE : S_LOAD;

      S_DONE:
        next_state = en ? S_DONE : S_IDLE;

      default:
        next_state = S_IDLE;
    endcase
  end

  // --------------------------------------------------
  // Sequential logic
  // --------------------------------------------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      matrix_idx <= '0;
      rfull      <= 32'd0;
      rfullm1    <= 32'd0;
      gf2_start  <= 1'b0;

    end else begin
      state <= next_state;

      gf2_start <= 1'b0;  // default

      case (state)

        // ----------------------------------------
        S_IDLE:
        begin
          if (en && start) begin
            rfull      <= 32'd0;
            rfullm1    <= 32'd0;
            matrix_idx <= '0;
          end
        end

        // ----------------------------------------
        // Load 16x16 matrix into rows_buf
        // ----------------------------------------
        S_LOAD:
        begin
          int unsigned bi;
          int unsigned row_global;

          row_global = 0;

          for (bi = 0; bi < BLOCKS_PER_MATRIX; bi++) begin
            logic [BIGM-1:0] blk;
            blk = get_block(matrix_idx*BLOCKS_PER_MATRIX + bi);

            for (int rblk = 0; rblk < ROWS_PER_BLOCK; rblk++) begin
              rows_buf[row_global]
                <= blk[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
              row_global++;
            end
          end
        end

        // ----------------------------------------
        // Start GF2 core
        // ----------------------------------------
        S_START:
        begin
          gf2_start <= 1'b1;
        end

        // ----------------------------------------
        // Accumulate result
        // ----------------------------------------
        S_ACCUM:
        begin
          if (gf2_rank == Q)
            rfull <= rfull + 1;
          else if (gf2_rank == Q-1)
            rfullm1 <= rfullm1 + 1;

          matrix_idx <= matrix_idx + 1'b1;
        end

        default: ;
      endcase
    end
  end

  // --------------------------------------------------
  // Outputs
  // --------------------------------------------------

  assign done = (state == S_DONE);
  assign pass = (state == S_DONE);

endmodule

// GF(2) Rank of QxQ matrix
module gf2_rank_q #(
  parameter int unsigned Q = 16
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start,
  input  logic [Q-1:0] rows_in [0:Q-1],
  output logic [31:0]  rank,
  output logic         done
);

  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  logic [Q-1:0] a [0:Q-1];

  typedef enum logic [2:0] {
    S_IDLE,
    S_LOAD,
    S_PIVOT,   // decide pivot for this column (combinational search)
    S_SWAP,    // optional swap
    S_ELIM,    // eliminate rows sequentially
    S_NEXT,    // advance column/pivot bookkeeping
    S_DONE
  } state_t;

  state_t state, next_state;

  logic signed [$clog2(Q+1):0] col;      // Q-1 down to -1
  logic [QW:0]                 pivot_row; // 0..Q
  logic [QW-1:0]               elim_row;  // 0..Q-1

  // combinational pivot finder for current column
  logic                        found_pivot;
  logic [QW-1:0]               sel_row;

  always_comb begin
    found_pivot = 1'b0;
    sel_row     = '0;

    if (col >= 0 && pivot_row < Q) begin
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

  // next state
  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:   next_state = start ? S_LOAD  : S_IDLE;
      S_LOAD:   next_state = S_PIVOT;

      S_PIVOT: begin
        if (col < 0 || pivot_row == Q) next_state = S_DONE;
        else if (found_pivot)          next_state = S_SWAP;
        else                           next_state = S_NEXT;
      end

      S_SWAP:   next_state = S_ELIM;
      S_ELIM:   next_state = (elim_row == Q-1) ? S_NEXT : S_ELIM;
      S_NEXT:   next_state = S_PIVOT;
      S_DONE:   next_state = S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  // sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      rank      <= 32'd0;
      done      <= 1'b0;
      col       <= '0;
      pivot_row <= '0;
      elim_row  <= '0;
      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;
      done  <= 1'b0; // pulse

      unique case (state)
        S_IDLE: begin
          if (start) begin
            rank      <= 32'd0;
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
          end
        end

        S_LOAD: begin
          for (int r = 0; r < Q; r++) a[r] <= rows_in[r];
        end

        S_PIVOT: begin
          // nothing sequential here; decision uses found_pivot/sel_row comb
        end

        S_SWAP: begin
          if (sel_row != pivot_row[QW-1:0]) begin
            logic [Q-1:0] tmp;
            tmp                   = a[pivot_row[QW-1:0]];
            a[pivot_row[QW-1:0]] <= a[sel_row];
            a[sel_row]           <= tmp;
          end
          elim_row <= '0;
        end

        S_ELIM: begin
          int er;
          er = int'(elim_row);

          if (er != int'(pivot_row)) begin
            if (a[er][int'(col)]) begin
              a[er] <= a[er] ^ a[pivot_row[QW-1:0]];
            end
          end

          if (elim_row != Q-1) elim_row <= elim_row + 1'b1;
        end

        S_NEXT: begin
          // if we pivoted in this column, consume it
          if (found_pivot) begin
            rank      <= rank + 32'd1;
            pivot_row <= pivot_row + 1'b1;
          end
          // always move to next column
          col <= col - 1'sd1;
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule