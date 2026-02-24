`default_nettype none

module t7_template_hits #(
  parameter int unsigned N = 2048,
  parameter int unsigned M = 9
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,
  input  logic [31:0]  hits_th,
  input  logic [M-1:0] template_bits,
  output logic         done,
  output logic         pass,
  output logic [31:0]  hits [0:15]
);
  integer i;
  assign done = 1'b1;
  assign pass = 1'b0;
  always_comb begin
    for (i = 0; i < 16; i++) hits[i] = 32'h0;
  end
endmodule

module t8_template_hits #(
  parameter int unsigned N = 2048,
  parameter int unsigned M = 9
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,
  input  logic [31:0]  hits_th,
  input  logic [M-1:0] template_bits,
  output logic         done,
  output logic         pass,
  output logic [31:0]  hits [0:15]
);
  integer i;
  assign done = 1'b1;
  assign pass = 1'b0;
  always_comb begin
    for (i = 0; i < 16; i++) hits[i] = 32'h0;
  end
endmodule

module t10_taps #(parameter int unsigned N = 2048, parameter int unsigned L = 9) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,
  output logic         done,
  output logic         pass,
  output logic [31:0]  taps,      // only [L-1:0] used later
  output logic [31:0]  blockid
);
  assign done    = 1'b1;
  assign pass    = 1'b0;
  assign taps    = 32'h0;
  assign blockid = 32'h0;
endmodule

module t13_chi2 #(parameter int unsigned N = 2048) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [N-1:0] trng,
  input  logic [31:0]  cth,
  output logic         done,
  output logic         pass,
  output logic [31:0]  chi,
  output logic [31:0]  clo
);
  assign done = 1'b1;
  assign pass = 1'b0;
  assign chi  = 32'h0;
  assign clo  = 32'h0;
endmodule