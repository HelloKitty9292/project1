`default_nettype none

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