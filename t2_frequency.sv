`default_nettype none

module t2_frequency #(parameter SMALLN = 2048, parameter BIGM = 128, parameter BIGN = 16) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]  c1hi_th,
  input  logic [31:0]  c1lo_th,
  output logic         done,
  output logic         pass,
  output logic [31:0]  c1hi,
  output logic [31:0]  c1lo
);
  logic [31:0] low_d, high_d, new_low, new_high, one_q, all_q;
  logic        bit_q;
  logic        reghi_en, reglo_en, one_en, one_ld, all_en, all_ld, 
               sh_ld, sh_en;
  p2s_shiftreg #(.WIDTH(SMALLN)) trng_reg2 (.clock(clk), .reset_n(rst_n), .D(trng),
              .ld(sh_ld), .en(sh_en), .Q(bit_q));

  counter #(.WIDTH(32)) one_cnt (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en(one_en), .ld(one_ld), .Q(one_q));

  counter #(.WIDTH(32)) all_cnt (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en(all_en), .ld(all_ld), .Q(all_q));

  register #(.WIDTH(32)) high_reg (.clock(clk), .reset_n(rst_n), .D(high_d),
          .en(reghi_en), .Q(c1hi));

  register #(.WIDTH(32)) low_reg (.clock(clk), .reset_n(rst_n), .D(low_d),
          .en(reglo_en), .Q(c1lo));

  assign new_high = (one_q > c1hi) ? one_q : c1hi;
  assign new_low  = (one_q < c1lo) ? one_q : c1lo;
  assign one_ld   = ((all_q != 0) && ((all_q & (BIGM-1)) == 0));

  enum logic [1:0] {START, COUNT, DONE} state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= START;
    else        state <= next_state;
  end
  
  // output logic
  always_comb begin
    unique case (state)
      START: begin
        sh_ld = start && en;
        sh_en = 1'b0;
        one_en = 1'b0;
        all_ld = start && en;
        all_en = 1'b0;
        high_d = (start && en) ? 32'h0 : new_high;
        low_d = (start && en) ? BIGM[31:0] : new_low;
        reghi_en = start && en;
        reglo_en = start && en;
        done = 1'b0;
        pass = 1'b0;
      end

      COUNT: begin
        sh_ld = 1'b0;
        sh_en = en;
        one_en = (en && (bit_q == 1'b1));
        all_ld = 1'b0;
        all_en = en;
        high_d = en ? new_high : 32'h0;
        low_d = en ? new_low : BIGM[31:0];
        reghi_en = en ? ((all_q != 0) && ((all_q & (BIGM-1)) == 0)) : 1'b0;
        reglo_en = en ? ((all_q != 0) && ((all_q & (BIGM-1)) == 0)) : 1'b0;
        done = 1'b0;
        pass = 1'b0;
      end

      DONE: begin
        sh_ld = 1'b0;
        sh_en = 1'b0;
        one_en = 1'b0;
        all_ld = 1'b0;
        all_en = 1'b0;
        high_d = 32'h0;
        low_d = BIGM[31:0];
        reghi_en = 1'b0;
        reglo_en = 1'b0;
        done = 1'b1;
        pass = (c1hi <= c1hi_th) && (c1lo >= c1lo_th);
      end

      default: begin
        sh_ld = 1'b0;
        sh_en = 1'b0;
        one_en = 1'b0;
        all_ld = 1'b0;
        all_en = 1'b0;
        high_d = 32'h0;
        low_d = BIGM[31:0];
        reghi_en = 1'b0;
        reglo_en = 1'b0;
        done = 1'b0;
        pass = 1'b0;
      end
    endcase
  end

  // next state logic
  always_comb begin
    unique case (state)
      START: next_state = (en && start) ? COUNT : START;
      COUNT: next_state = (all_q == SMALLN[31:0]) ? DONE : COUNT;
      DONE: next_state = en ? DONE : START;
      default: next_state = START;
    endcase
  end

  // always_comb begin
  //   if (state == DONE) $display("done state reached for T2");
  // end

endmodule