`default_nettype none

module t5_rank #(parameter N = 2048, parameter BIGM = 128, parameter Q = 16) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,

  output logic         done,
  output logic         pass,
  output logic [31:0]  rfull,
  output logic [31:0]  rfullm1
);

  localparam int unsigned MATRIX_BITS      = Q * Q;
  localparam int unsigned NUM_MATRICES     = (N / MATRIX_BITS);

  localparam int unsigned ROWS_PER_BLOCK   = (BIGM / Q);
  localparam int unsigned BLOCKS_PER_MATRIX= (MATRIX_BITS / BIGM);
  localparam int unsigned NUM_BLOCKS       = (N / BIGM);

  // Block extraction
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base = N - (k+1)*BIGM; //block k start
      get_block = trng[base +: BIGM];
    end
  endfunction

  // GF(2) Rank of QxQ matrix
  function automatic int unsigned gf2_rank_q(input logic [Q-1:0] rows_in [0:Q-1]);
    logic [Q-1:0] a [0:Q-1];
    int unsigned rank;
    int pivot_row;
    int col;
    begin
      for (int r = 0; r < Q; r++) a[r] = rows_in[r];

      rank = 0;
      pivot_row = 0;

      for (col = Q-1; col >= 0; col--) begin
        int sel;
        sel = -1;

        for (int r = pivot_row; r < Q; r++) begin
          if (a[r][col]) begin
            sel = r;
            break;
          end
        end

        if (sel != -1) begin
          if (sel != pivot_row) begin
            logic [Q-1:0] tmp;
            tmp          = a[pivot_row];
            a[pivot_row] = a[sel];
            a[sel]       = tmp;
          end

          for (int r = 0; r < Q; r++) begin
            if ((r != pivot_row) && a[r][col]) begin
              a[r] = a[r] ^ a[pivot_row];
            end
          end

          rank++;
          pivot_row++;
          if (pivot_row == Q) break;
        end
      end

      gf2_rank_q = rank;
    end
  endfunction

  // Rank of matrix m
  function automatic int unsigned matrix_rank(input int unsigned m);
    logic [Q-1:0] rows [0:Q-1];
    int unsigned row_global;
    begin
      for (int r = 0; r < Q; r++) rows[r] = '0;

      row_global = 0;
      for (int unsigned bi = 0; bi < BLOCKS_PER_MATRIX; bi++) begin
        logic [BIGM-1:0] blk;
        blk = get_block(m*BLOCKS_PER_MATRIX + bi);

        for (int unsigned rblk = 0; rblk < ROWS_PER_BLOCK; rblk++) begin
          rows[row_global] = blk[(ROWS_PER_BLOCK-1-rblk)*Q +: Q];
          row_global++;
        end
      end

      matrix_rank = gf2_rank_q(rows);
    end
  endfunction

  // fsm
  typedef enum logic [1:0] {S_IDLE, S_COMPUTE, S_DONE} state_t;
  state_t state, next_state;

  logic [31:0] rfull_d, rfullm1_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      rfull   <= 32'd0;
      rfullm1 <= 32'd0;
    end else begin
      state <= next_state;
      if (state == S_COMPUTE) begin
        rfull   <= rfull_d;
        rfullm1 <= rfullm1_d;
      end
    end
  end

  always_comb begin
    rfull_d   = 32'd0;
    rfullm1_d = 32'd0;

    for (int unsigned m = 0; m < NUM_MATRICES; m++) begin
      int unsigned rk;
      rk = matrix_rank(m);
      if (rk == Q)       rfull_d++;
      else if (rk == Q-1) rfullm1_d++;
    end

    if (state == S_DONE) begin done = 1'b1; pass = 1'b1; end
    else begin done = 1'b0; pass = 1'b0; end
  end

  always_comb begin
    unique case (state)
      S_IDLE:    next_state = (en && start) ? S_COMPUTE : S_IDLE;
      S_COMPUTE: next_state = S_DONE;
      S_DONE:    next_state = en ? S_DONE : S_IDLE;
      default:   next_state = S_IDLE;
    endcase
  end

endmodule
