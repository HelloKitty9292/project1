`default_nettype none

module t1_frequency #(parameter int unsigned N = 2048) (
  input  logic         clk,
  input  logic         rst_n,

  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,
  input  logic [31:0]  diff_th,

  output logic         done,
  output logic         pass,

  output logic [31:0]  c1,
  output logic [31:0]  c0,
  output logic [31:0]  diff
);

  enum logic [1:0] {START, COUNT, DONE} state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= START;
    else        state <= next_state;
  end

  // instantiate counter and shift register
  logic bit_q;
  logic sh_ld, sh_en;

  logic c0_en, c1_en;
  logic c_ld;
  logic [31:0] sum_q;

  assign sum_q = c0 + c1;
  assign diff = (c0 > c1) ? (c0 - c1) : (c1 - c0);

  p2s_shiftreg #(.WIDTH(N)) trng_reg (.clock(clk), .reset_n(rst_n), .D(trng),
              .ld(sh_ld), .en(sh_en), .Q(bit_q));

  counter #(.WIDTH(32)) c0_cnt (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en(c0_en), .ld(c_ld), .Q(c0));

  counter #(.WIDTH(32)) c1_cnt (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en(c1_en), .ld(c_ld), .Q(c1));

  // output logic
  always_comb begin
    unique case (state)
      START: begin
        sh_ld = start && en;
        sh_en = 1'b0;
        c_ld  = start && en;
        c0_en = 1'b0;
        c1_en = 1'b0;
        done = 1'b0;
        pass = 1'b0;
      end

      COUNT: begin
        sh_ld = 1'b0;
        sh_en = en;
        c_ld  = 1'b0;
        c0_en = (en && (bit_q == 1'b0));
        c1_en = (en && (bit_q == 1'b1));
        done = 1'b0;
        pass = 1'b0;
      end

      DONE: begin
        sh_ld = 1'b0;
        sh_en = 1'b0;
        c_ld  = 1'b0;
        c0_en = 1'b0;
        c1_en = 1'b0;
        done = 1'b1;
        pass = (diff <= diff_th);
      end

      default: begin
        sh_ld = 1'b0;
        sh_en = 1'b0;
        c_ld  = 1'b0;
        c0_en = 1'b0;
        c1_en = 1'b0;
        done = 1'b0;
        pass = 1'b0;
      end
    endcase
  end

  // next state logic
  always_comb begin
    unique case (state)
      START: next_state = (en && start) ? COUNT : START;
      COUNT: next_state = (sum_q == N[31:0]) ? DONE : COUNT;
      DONE: next_state = en ? DONE : START;
      default: next_state = START;
    endcase
  end

endmodule