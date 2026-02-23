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
    if (!reset_n) begin
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