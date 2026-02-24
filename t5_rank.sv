`default_nettype none

module t5_rank #(parameter SMALLN = 2048, parameter BIGM = 128) (
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

  // 32x32 matrices
  localparam int unsigned ROWS        = 32;
  localparam int unsigned COLS        = 32;
  localparam int unsigned MATRIX_BITS = ROWS * COLS; // 1024
  localparam int unsigned MAT_COUNT   = (SMALLN / MATRIX_BITS);

  function automatic int unsigned gf2_rank32(input logic [31:0] rows_in [0:31]);
    logic [31:0] a [0:31];
    int unsigned rank;
    int pivot_row;
    int col;

    begin
      for (int r = 0; r < 32; r++) a[r] = rows_in[r];

      rank = 0;
      pivot_row = 0;

      // Iterate columns MSB->LSB
      for (col = 31; col >= 0; col--) begin
        int sel;
        sel = -1;

        // find a row with a 1 in this column under pivot_row
        for (int r = pivot_row; r < 32; r++) begin
          if (a[r][col]) begin
            sel = r;
            break;
          end
        end

        if (sel != -1) begin
          // swap selected row into pivot_row
          if (sel != pivot_row) begin
            logic [31:0] tmp;
            tmp         = a[pivot_row];
            a[pivot_row]= a[sel];
            a[sel]      = tmp;
          end

          // eliminate this column from all other rows
          for (int r = 0; r < 32; r++) begin
            if ((r != pivot_row) && a[r][col]) begin
              a[r] = a[r] ^ a[pivot_row];
            end
          end

          rank++;
          pivot_row++;
          if (pivot_row == 32) break;
        end
      end

      gf2_rank32 = rank;
    end
  endfunction

  // Build matrix rows
  function automatic int unsigned matrix_rank(input int unsigned m);
    logic [31:0] rows [0:31];
    int unsigned base;
    begin
      base = m * MATRIX_BITS;
      for (int r = 0; r < 32; r++) begin
        rows[r] = trng[base + (r*32) +: 32];
      end
      matrix_rank = gf2_rank32(rows);
    end
  endfunction

  // fsm
  typedef enum logic [1:0] {S_IDLE, S_COMPUTE, S_DONE} state_t;
  state_t state, next_state;

  logic [31:0] rfull_d, rfullm1_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      rfull    <= 32'd0;
      rfullm1  <= 32'd0;
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

    for (int unsigned m = 0; m < MAT_COUNT; m++) begin
      int unsigned rk;
      rk = matrix_rank(m);
      if (rk == 32) rfull_d++;
      else if (rk == 31) rfullm1_d++;
    end

    if (state == S_DONE) begin
      done = 1'b1;
      pass = 1'b1;
    end else begin
      done = 1'b0;
      pass = 1'b0;
    end
  end

  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:    next_state = (en && start) ? S_COMPUTE : S_IDLE;
      S_COMPUTE: next_state = S_DONE;
      S_DONE:    next_state = en ? S_DONE : S_IDLE;
    endcase
  end

endmodule