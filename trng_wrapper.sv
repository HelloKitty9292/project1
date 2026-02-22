module trng_wrapper (clk, rst_n, trng, addr, data_from_cpu, data_to_cpu, re, we);
localparam BUSW = 32;
localparam SMALLN = 2048;
localparam BIGM = 128;
localparam BIGN = 16;
localparam K = 5;
localparam Q = 16;
localparam SMALLM = 9;
localparam LFSRL = 9;
input clk;
input rst_n; // active low, asynchronous reset
input [SMALLN-1:0] trng;
input [BUSW-1:0] addr;
1In the NIST standard, the matrices are QxM. We will not worry about that and only consider a square matrix that is 16x16.
input [BUSW-1:0] data_from_cpu;
output reg [BUSW-1:0] data_to_cpu;
input re; // active high
input we; // active high
endmodule
