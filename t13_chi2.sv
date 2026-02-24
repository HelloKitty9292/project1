`default_nettype none

module t13_chi2 #(
  parameter int unsigned N = 2048
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             en,
  input  logic             start,
  input  logic [N-1:0]     trng,
  input  logic [31:0]      cth,

  output logic             done,
  output logic             pass,
  output logic [31:0]      chi,
  output logic [31:0]      clo
);

  typedef enum logic [1:0] { IDLE, RUN, PUBLISH, DONE } state_t;
  state_t state;

  // signed walk state
  logic signed [31:0] sum_s, max_s, min_s;
  logic [$clog2(N)-1:0] idx;

  // registered outputs
  logic        pass_q;
  logic [31:0] chi_q, clo_q;

  assign pass = pass_q;
  assign chi  = chi_q;
  assign clo  = clo_q;

  logic signed [31:0] cth_s;
  assign cth_s = $signed(cth);

  // IMPORTANT: bit order
  // Use MSB-first across the entire 2048-bit vector:
  // i=0 => trng[N-1], i=N-1 => trng[0]
  logic bit_cur;
  always_comb bit_cur = trng[N-1-idx];

  function automatic logic [31:0] abs32(input logic signed [31:0] v);
    logic signed [31:0] negv;
    begin
      negv  = -v;
      abs32 = (v < 0) ? logic'(negv) : logic'(v);
    end
  endfunction

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
      done <= 1'b0; // default (pulse only)

      unique case (state)

        IDLE: begin
          // only allow starting when en=1
          if (en && start) begin
            idx   <= '0;
            sum_s <= 32'sd0;
            max_s <= 32'sd0;
            min_s <= 32'sd0;

            // clear outputs for this run
            pass_q <= 1'b0;
            chi_q  <= 32'h0;
            clo_q  <= 32'h0;

            state <= RUN;
          end
        end

        RUN: begin
          // ignore en while running
          logic signed [31:0] step_s;
          logic signed [31:0] sum_next;

          step_s   = bit_cur ? 32'sd1 : -32'sd1;
          sum_next = sum_s + step_s;

          // update extrema using the new sum
          if (sum_next > max_s) max_s <= sum_next;
          if (sum_next < min_s) min_s <= sum_next;

          sum_s <= sum_next;

          if (idx == N-1) begin
            // all bits processed; extrema are now final (registered)
            state <= PUBLISH;
          end else begin
            idx <= idx + 1'b1;
          end
        end

        PUBLISH: begin
          // Update outputs NOW (one full cycle before done pulses)
          // CHI is max (>=0), CLO is magnitude of min (>=0)
          chi_q  <= $unsigned(max_s);
          clo_q  <= abs32(min_s);

          pass_q <= (max_s <= cth_s) && (abs32(min_s) <= $unsigned(cth_s));

          state <= DONE;
        end

        DONE: begin
          // done pulse AFTER pass/chi/clo are already stable
          done  <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;

      endcase
    end
  end

endmodule

`default_nettype wire
