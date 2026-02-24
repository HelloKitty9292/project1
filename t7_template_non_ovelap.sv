`default_nettype none

module t7_nonoverlap_template #(
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned BIGN   = 16,
  parameter int unsigned SMALLM = 9
) (
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 en,
  input  logic                 start,

  input  logic [SMALLN-1:0]    trng,
  input  logic [SMALLM-1:0]    template,
  input  logic [31:0]          hits_th,

  output logic                 done,
  output logic                 pass,

  // hits_flat[(i*32)+:32] is block i hits
  output logic [BIGN*32-1:0]   hits_flat
);

  // -----------------------------
  // Sanity checks (elaboration)
  // -----------------------------
  initial begin
    if (SMALLN != BIGN*BIGM) $fatal(1, "T7: require SMALLN==BIGN*BIGM (%0d != %0d*%0d)", SMALLN, BIGN, BIGM);
    if (SMALLM == 0 || SMALLM > BIGM) $fatal(1, "T7: bad SMALLM (%0d) vs BIGM (%0d)", SMALLM, BIGM);
  end

  // ----------------------------------------------------------
  // Access TRNG blocks: trng = {block0, block1, ... block(BIGN-1)}
  // block0 is the MSB BIGM bits (same as your TB concatenation).
  // ----------------------------------------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned idx);
    int unsigned base;
    begin
      base = SMALLN - (idx+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // ----------------------------------------------------------
  // Count non-overlapping template hits in one BIGM-bit block
  // Non-overlap: on hit, advance by SMALLM; else advance by 1
  // We interpret "window" on consecutive bits in the block vector.
  // This uses LSB-based indexing block[pos +: SMALLM].
  // If your professor expects MSB-based scanning, flip pos indexing.
  // ----------------------------------------------------------
  function automatic logic [31:0] count_hits_block(
    input logic [BIGM-1:0] blk,
    input logic [SMALLM-1:0] templ
  );
    int unsigned pos;
    logic [31:0] hits;
    begin
      hits = 32'd0;
      pos  = 0;

      // last valid start = BIGM - SMALLM
      while (pos + SMALLM <= BIGM) begin
        if (blk[pos +: SMALLM] == templ) begin
          hits = hits + 32'd1;
          pos  = pos + SMALLM;   // non-overlapping jump
        end else begin
          pos  = pos + 1;
        end
      end

      count_hits_block = hits;
    end
  endfunction

  // ----------------------------
  // FSM
  // ----------------------------
  typedef enum logic [1:0] {S_IDLE, S_COMPUTE, S_DONE} state_t;
  state_t state, next_state;

  logic [BIGN*32-1:0] hits_d_flat;
  logic [31:0]        max_hits_d;

  // combinational compute for all blocks
  always_comb begin
    hits_d_flat = '0;
    max_hits_d  = 32'd0;

    for (int unsigned i = 0; i < BIGN; i++) begin
      logic [BIGM-1:0] blk;
      logic [31:0]     h;

      blk = get_block(i);
      h   = count_hits_block(blk, template);

      hits_d_flat[i*32 +: 32] = h;
      if (h > max_hits_d) max_hits_d = h;
    end
  end

  // state register + result registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      hits_flat <= '0;
    end else begin
      state <= next_state;

      if (state == S_COMPUTE) begin
        hits_flat <= hits_d_flat;     // latch per-block hit counts
      end
    end
  end

  // outputs and next-state
  always_comb begin
    done = 1'b0;
    pass = 1'b0;

    unique case (state)
      S_IDLE: begin
        done = 1'b0;
        pass = 1'b0;
      end

      S_COMPUTE: begin
        done = 1'b0;
        pass = 1'b0;
      end

      S_DONE: begin
        done = 1'b1;
        // pass/fail by ceiling on highest block hits
        pass = (max_hits_d <= hits_th);
      end

      default: begin
        done = 1'b0;
        pass = 1'b0;
      end
    endcase
  end

  always_comb begin
    unique case (state)
      S_IDLE:    next_state = (en && start) ? S_COMPUTE : S_IDLE;
      S_COMPUTE: next_state = S_DONE;
      S_DONE:    next_state = en ? S_DONE : S_IDLE;
      default:   next_state = S_IDLE;
    endcase
  end

endmodule