`default_nettype none

module t13_chi2 #(
  parameter int unsigned N = 2048
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             en,
  input  logic             start,
  input  logic [N-1:0]      trng,
  input  logic [31:0]       cth,

  output logic             done,
  output logic             pass,
  output logic [31:0]      chi,
  output logic [31:0]      clo
);

  typedef enum logic [1:0] { IDLE, RUN, FINISH } state_t;
  state_t state;

  // We need signed math for min/max tracking
  logic signed [31:0] sum_s;
  logic signed [31:0] max_s;
  logic signed [31:0] min_s;

  logic [$clog2(N)-1:0] idx;

  // Output regs
  logic pass_q;
  logic [31:0] chi_q, clo_q;

  assign pass = pass_q;
  assign chi  = chi_q;
  assign clo  = clo_q;

  // helper: signed threshold
  logic signed [31:0] cth_s;
  assign cth_s = $signed(cth);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      done   <= 1'b0;

      idx    <= '0;
      sum_s  <= '0;
      max_s  <= '0;
      min_s  <= '0;

      pass_q <= 1'b0;
      chi_q  <= 32'h0;
      clo_q  <= 32'h0;
    end else begin
      done <= 1'b0; // default: pulse only

      if (!en) begin
        state <= IDLE;
      end else begin
        unique case (state)

          IDLE: begin
            if (start) begin
              // initialize walk
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
            // next sum = sum + (bit?+1:-1)
            logic signed [31:0] sum_next;
            sum_next = sum_s + (trng[idx] ? 32'sd1 : -32'sd1);

            // update max/min with sum_next (important: include the new step)
            if (sum_next > max_s) max_s <= sum_next;
            if (sum_next < min_s) min_s <= sum_next;

            sum_s <= sum_next;

            if (idx == N-1) begin
              state <= FINISH;
            end else begin
              idx <= idx + 1'b1;
            end
          end

          FINISH: begin
            // Pass if within +/-CTH
            // i.e., max <= cth AND min >= -cth
            logic signed [31:0] neg_cth;
            neg_cth = -cth_s;

            pass_q <= ((max_s <= cth_s) && (min_s >= neg_cth));

            // Export CHI/CLO as raw two's-complement signed values in 32-bit regs
            chi_q <= $unsigned(max_s);
            clo_q <= $unsigned(min_s);

            done  <= 1'b1; // one-cycle done pulse
            state <= IDLE;
          end

          default: state <= IDLE;

        endcase
      end
    end
  end

endmodule