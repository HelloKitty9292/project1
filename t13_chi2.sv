`default_nettype none

module t13_chi2 #(
  parameter SMALLN = 2048
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]       cth,
 
  output logic              done,
  output logic              pass,
  output logic [31:0]       chi,
  output logic [31:0]       clo
);

  enum logic [1:0] { IDLE, RUN, PUBLISH, DONE } state;

  logic signed [31:0] sum_s, max_s, min_s;
  logic [myclog2(SMALLN)-1:0] idx;

  logic        pass_q;
  logic [31:0] chi_q, clo_q;

  assign pass = pass_q;
  assign chi  = chi_q;
  assign clo  = clo_q;

  logic        [31:0] cth_u;
  logic signed [31:0] cth_s;
  assign cth_u = cth;
  assign cth_s = $signed(cth);

  logic bit_cur;
  assign bit_cur = trng[SMALLN-1-idx];

  function automatic logic [31:0] abs32(input logic signed [31:0] v);
    logic signed [31:0] mag_s;
    begin
      mag_s = (v < 0) ? -v : v;
      abs32 = $unsigned(mag_s);
    end
  endfunction

  logic signed [31:0] step_s;
  logic signed [31:0] sum_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      done   <= 1'b0;

      idx    <= '0;
      sum_s  <= 32'sd0;
      max_s  <= 32'sd0;
      min_s  <= 32'sd0;

      pass_q <= 1'b0;
      chi_q  <= 32'h0;
      clo_q  <= 32'h0;

    end else begin
      done <= 1'b0;

      step_s   = 32'sd0;
      sum_next = sum_s;

      unique case (state)

        IDLE: begin
          if (en && start) begin
            idx   <= '0;
            sum_s <= 32'sd0;
            max_s <= 32'sd0;
            min_s <= 32'sd0;

            pass_q <= 1'b0;
            chi_q  <= 32'h0;
            clo_q  <= 32'h0;

            state <= RUN;
          end
        end

        RUN: begin
          step_s   = bit_cur ? 32'sd1 : -32'sd1;
          sum_next = sum_s + step_s;

          if (sum_next > max_s) max_s <= sum_next;
          if (sum_next < min_s) min_s <= sum_next;

          sum_s <= sum_next;

          if (idx == SMALLN-1) begin
            state <= PUBLISH;
          end else begin
            idx <= idx + 1'b1;
          end
        end

        PUBLISH: begin
          chi_q <= $unsigned(max_s);
          clo_q <= abs32(min_s);

          pass_q <= (($unsigned(max_s) <= cth_u) && (abs32(min_s) <= cth_u));

          state <= DONE;
        end

        DONE: begin
          done  <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;

      endcase
    end
  end

endmodule
