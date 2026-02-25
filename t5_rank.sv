`default_nettype none

module t5_rank #(parameter SMALLN = 2048, parameter BIGM = 128, parameter Q = 16) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [SMALLN-1:0] trng,

  output logic         done,
  output logic         pass,
  output logic [31:0]  rfull,
  output logic [31:0]  rfullm1
);

  localparam int unsigned MATRIX_BITS      = Q * Q;
  localparam int unsigned NUM_MATRICES     = (SMALLN / MATRIX_BITS);

  localparam int unsigned ROWS_PER_BLOCK   = (BIGM / Q);
  localparam int unsigned BLOCKS_PER_MATRIX= (MATRIX_BITS / BIGM);
  localparam int unsigned NUM_BLOCKS       = (SMALLN / BIGM);

  // Block extraction
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base = SMALLN - (k+1)*BIGM; //block k start
      get_block = trng[base +: BIGM];
    end
  endfunction

  // GF(2) Rank of QxQ matrix
  function automatic int unsigned gf2_rank_q(input logic [Q-1:0] rows_in [0:Q-1]);
    logic [Q-1:0] a   [0:Q-1];
    logic [Q-1:0] tmp;

    int unsigned rank;
    int          pivot_row;
    int          col;
    int          r;

    int          sel;
    bit          found_pivot;

    begin
      for (r = 0; r < Q; r = r + 1)
        a[r] = rows_in[r];
  
      rank      = 0;
      pivot_row = 0;
  
      for (col = Q-1; col >= 0; col = col - 1) begin
        sel         = -1;
        found_pivot = 0;

        for (r = 0; r < Q; r = r + 1) begin
          if ((r >= pivot_row) && !found_pivot && a[r][col]) begin
            sel         = r;
            found_pivot = 1;
          end
        end

        if (sel != -1) begin
          if (sel != pivot_row) begin
            tmp          = a[pivot_row];
            a[pivot_row] = a[sel];
            a[sel]       = tmp;
          end

          for (r = 0; r < Q; r = r + 1) begin
            if ((r != pivot_row) && a[r][col]) begin
              a[r] = a[r] ^ a[pivot_row];
            end
          end

          rank      = rank + 1;
          pivot_row = pivot_row + 1;
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
  enum logic [1:0] {S_IDLE, S_COMPUTE, S_DONE} state, next_state;

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

  int unsigned m;
  int unsigned rk;
  always_comb begin
    rfull_d   = 32'd0;
    rfullm1_d = 32'd0;

    for (m = 0; m < NUM_MATRICES; m = m + 1) begin
      rk = matrix_rank(m);
      if (rk == Q)        rfull_d++;
      else if (rk == Q-1) rfullm1_d++;
    end

    if (state == S_DONE) begin
      done = 1'b1; pass = 1'b1;
    end else begin
      done = 1'b0; pass = 1'b0;
    end
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
