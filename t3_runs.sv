`default_nettype none

module t3_runs #(parameter SMALLN = 2048) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]       lr_th,
  output logic              done,
  output logic              pass,
  output logic [31:0]       lr1,
  output logic [31:0]       lr0,
  output logic [31:0]       nr1,
  output logic [31:0]       nr0
);

  logic bit_q;
  logic sh_ld, sh_en;

  p2s_shiftreg #(.WIDTH(SMALLN)) trng_sr (.clock (clk), .reset_n (rst_n),
               .D (trng), .ld (sh_ld), .en (sh_en), .Q (bit_q));

  enum logic [1:0] {START_S, COUNT_S, DONE_S} state, next_state;

  logic [31:0] idx;
  logic        prev_valid, prev_bit;
  logic [31:0] curr_len;

  logic do_start, do_count, last_bit;

  assign do_start = (state == START_S) && en && start;
  assign do_count = (state == COUNT_S) && en;
  assign last_bit = (idx == (SMALLN-1));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= START_S;
    else        state <= next_state;
  end

  //nextstate logic
  always_comb begin
    unique case (state)
      START_S: next_state = (en && start) ? COUNT_S : START_S;
      COUNT_S: next_state = (do_count && last_bit) ? DONE_S : COUNT_S;
      DONE_S:  next_state = en ? DONE_S : START_S;
      default: next_state = START_S;
    endcase
  end

  //output logic
  always_comb begin
    sh_ld = do_start;
    sh_en = (state == COUNT_S) && en;
    done = (state == DONE_S);
    pass = (state == DONE_S) && (lr1 <= lr_th) && (lr0 <= lr_th);
  end

  // datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx        <= 32'd0;
      prev_valid <= 1'b0;
      prev_bit   <= 1'b0;
      curr_len   <= 32'd0;

      lr1 <= 32'd0;
      lr0 <= 32'd0;
      nr1 <= 32'd0;
      nr0 <= 32'd0;

    end else begin
      if (do_start) begin
        idx        <= 32'd0;
        prev_valid <= 1'b0;
        prev_bit   <= 1'b0;
        curr_len   <= 32'd0;

        lr1 <= 32'd0;
        lr0 <= 32'd0;
        nr1 <= 32'd0;
        nr0 <= 32'd0;

      end else if (do_count) begin
        if (!prev_valid) begin
          prev_valid <= 1'b1;
          prev_bit   <= bit_q;
          curr_len   <= 32'd1;

          if (bit_q) nr1 <= nr1 + 32'd1;
          else       nr0 <= nr0 + 32'd1;

        end else if (bit_q == prev_bit) begin
          curr_len <= curr_len + 32'd1;

        end else begin
          if (prev_bit) begin
            if (curr_len > lr1) lr1 <= curr_len;
          end else begin
            if (curr_len > lr0) lr0 <= curr_len;
          end
          prev_bit <= bit_q;
          curr_len <= 32'd1;

          if (bit_q) nr1 <= nr1 + 32'd1;
          else       nr0 <= nr0 + 32'd1;
        end

        // last bit
        if (last_bit) begin
          if (!prev_valid) begin
            if (bit_q) begin
              if (32'd1 > lr1) lr1 <= 32'd1;
            end else begin
              if (32'd1 > lr0) lr0 <= 32'd1;
            end

          end else if (bit_q == prev_bit) begin
            if (prev_bit) begin
              if ((curr_len + 32'd1) > lr1) lr1 <= (curr_len + 32'd1);
            end else begin
              if ((curr_len + 32'd1) > lr0) lr0 <= (curr_len + 32'd1);
            end

          end else begin
            if (bit_q) begin
              if (32'd1 > lr1) lr1 <= 32'd1;
            end else begin
              if (32'd1 > lr0) lr0 <= 32'd1;
            end
          end
        end

        idx <= idx + 32'd1;
      end
    end
  end

endmodule
