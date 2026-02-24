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

  // Threshold is conceptually unsigned positive in your TB
  logic [31:0] cth_u;
  logic signed [31:0] cth_s;
  assign cth_u = cth;
  assign cth_s = $signed(cth);

  // MSB-first across whole vector:
  // idx=0 uses trng[N-1], idx=N-1 uses trng[0]
  logic bit_cur;
  always_comb bit_cur = trng[N-1-idx];

  function automatic logic [31:0] abs32(input logic signed [31:0] v);
    logic signed [31:0] mag_s;
    begin
      mag_s = (v < 0) ? -v : v;     // still signed, but non-negative now
      abs32 = $unsigned(mag_s);     // export magnitude as unsigned 32-bit
    end
  endfunction

  // predeclared temps (tool-friendly)
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
      done <= 1'b0; // pulse only

      // default temps
      step_s   = 32'sd0;
      sum_next = sum_s;

      unique case (state)

        IDLE: begin
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
          // one step of the walk
          step_s   = bit_cur ? 32'sd1 : -32'sd1;
          sum_next = sum_s + step_s;

          // extrema include the NEW sum
          if (sum_next > max_s) max_s <= sum_next;
          if (sum_next < min_s) min_s <= sum_next;

          sum_s <= sum_next;

          if (idx == N-1) begin
            state <= PUBLISH;
          end else begin
            idx <= idx + 1'b1;
          end
        end

        PUBLISH: begin
          // CHI is max (>=0), CLO is magnitude of min (>=0)
          chi_q <= $unsigned(max_s);
          clo_q <= abs32(min_s);

          // Pass if BOTH peaks are within threshold magnitude
          // max_s is signed (>=0), compare to signed threshold
          // abs(min_s) is unsigned magnitude, compare to unsigned threshold
          pass_q <= (($unsigned(max_s) <= cth_u) && (abs32(min_s) <= cth_u));

          state <= DONE;
        end

        DONE: begin
          done  <= 1'b1;   // 1-cycle pulse AFTER outputs are stable
          state <= IDLE;
        end

        default: state <= IDLE;

      endcase
    end
  end

endmodule
