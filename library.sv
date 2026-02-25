`default_nettype none

module register #(parameter WIDTH = 32) (
  input  logic             clock, reset_n,
  input  logic [WIDTH-1:0] D,
  input  logic             en,
  output logic [WIDTH-1:0] Q
);
  always_ff @(posedge clock, negedge reset_n)
    if (~reset_n) Q <= '0;
    else if (en) Q <= D;
endmodule

module p2s_shiftreg #(parameter WIDTH = 32) (
  input  logic             clock, reset_n,
  input  logic [WIDTH-1:0] D,
  input  logic             ld, en,
  output logic             Q);

  logic [WIDTH-1:0] Dstore;
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      Dstore <= '0;
    end else if (ld) begin
      Dstore <= D;
    end else if (en) begin
      Dstore <= {1'b0, Dstore[WIDTH-1:1]};
    end
  end
  assign Q = Dstore[0];
endmodule

module counter #(parameter WIDTH = 32) (
  input  logic             clock, reset_n,
  input  logic [WIDTH-1:0] D,
  input  logic             en, ld,
  output logic [WIDTH-1:0] Q
);
  always_ff @(posedge clock, negedge reset_n)
    if (~reset_n) Q <= '0;
    else if (ld) Q <= D;
    else if (en) Q <= Q+ 1'b1;
endmodule

function automatic int unsigned myclog2 (input int unsigned value);
  int unsigned v;
  int unsigned r;
  begin
    if (value <= 1) return 0;
    v = value - 1;
    r = 0;
    while (v > 0) begin
      v >>= 1;
      r++;
    end
    return r;
  end
endfunction

function automatic logic [63:0] almost_chi_t4 (
  input logic [31:0] v0, v1, v2, v3, v4, v5,
  input logic [31:0] N_blocks
);

  logic signed [31:0] d0, d1, d2, d3, d4, d5;
  logic signed [63:0] s0, s1, s2, s3, s4, s5;

  begin
    d0 = $signed(100 * v0) - $signed(N_blocks * 12);
    d1 = $signed(100 * v1) - $signed(N_blocks * 24);
    d2 = $signed(100 * v2) - $signed(N_blocks * 25);
    d3 = $signed(100 * v3) - $signed(N_blocks * 18);
    d4 = $signed(100 * v4) - $signed(N_blocks * 10);
    d5 = $signed(100 * v5) - $signed(N_blocks * 11);

    s0 = d0 * d0;
    s1 = d1 * d1;
    s2 = d2 * d2;
    s3 = d3 * d3;
    s4 = d4 * d4;
    s5 = d5 * d5;

    almost_chi_t4 = s0 + s1 + s2 + s3 + s4 + s5;
  end
endfunction
