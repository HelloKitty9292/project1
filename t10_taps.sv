`default_nettype none

module t10_taps #(
  parameter int unsigned N = 2048,  // total bits
  parameter int unsigned L = 9      // LFSR length
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  en,
  input  logic                  start,
  input  logic [N-1:0]          trng,

  output logic                  done,
  output logic                  pass,
  output logic [31:0]           taps,
  output logic [31:0]           blockid
);

  // ------------------------------------------------------------
  // LFSR tap masks to test (given)
  // NOTE: masks exclude the implicit "+1" term; we include state[0]
  // in the feedback as: feedback = state[0] ^ ^(state & mask)
  // ------------------------------------------------------------
  localparam logic [L-1:0] MASK01 = 9'b0_0001_0000; // x^9 + x^4 + 1
  localparam logic [L-1:0] MASK04 = 9'b0_0010_1100; // x^9 + x^5 + x^3 + x^2 + 1
  localparam logic [L-1:0] MASK06 = 9'b0_0101_1000; // x^9 + x^6 + x^4 + x^3 + 1
  localparam logic [L-1:0] MASK10 = 9'b0_0111_0110; // x^9 + x^6 + x^5 + x^4 + x^2 + x^1 + 1

  localparam int unsigned BIGM        = 128;
  localparam int unsigned NUM_BLOCKS  = (N / BIGM);  // 16 for N=2048
  localparam int unsigned NUM_SEEDS   = (1 << L);    // 512 for L=9

  // One-step Fibonacci LFSR (output bit is state[0])
  function automatic logic [L-1:0] lfsr_step(input logic [L-1:0] s, input logic [L-1:0] mask);
    logic fb;
    begin
      fb = s[0] ^ ^(s & mask);          // include the "+1" term via s[0]
      lfsr_step = {fb, s[L-1:1]};       // shift right, insert fb at MSB
    end
  endfunction

  // Extract block i in TB order:
  // trng = {block0, block1, ... block15} so block0 is MSB slice.
  function automatic logic [BIGM-1:0] get_block(input int unsigned bi);
    int unsigned msb;
    begin
      msb       = (N - 1) - (bi * BIGM);
      get_block = trng[msb -: BIGM];
    end
  endfunction

  // ------------------------------------------------------------
  // Brute force search:
  // for each block, for each of 4 masks, for each nonzero seed,
  // generate 128 bits and compare bitwise.
  //
  // We do the full search "in one cycle" at start (simulation-friendly).
  // done pulses for 1 cycle when results are latched.
  // ------------------------------------------------------------
  logic        found;
  logic [31:0] found_blockid;
  logic [31:0] found_taps;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done    <= 1'b0;
      pass    <= 1'b1;
      taps    <= 32'd0;
      blockid <= 32'd0;
    end else begin
      done <= 1'b0; // default: pulse only when we finish a run

      if (en && start) begin
        found         = 1'b0;
        found_blockid = 32'd0;
        found_taps    = 32'd0;

        // Search blocks in order; stop at first match
        for (int unsigned b = 0; b < NUM_BLOCKS; b++) begin
          if (found) break;

          logic [BIGM-1:0] blk;
          blk = get_block(b);

          // Try each mask in fixed order
          for (int unsigned msel = 0; msel < 4; msel++) begin
            if (found) break;

            logic [L-1:0] mask;
            unique case (msel)
              0: mask = MASK01;
              1: mask = MASK04;
              2: mask = MASK06;
              default: mask = MASK10;
            endcase

            // Try all nonzero seeds
            for (int unsigned seed = 1; seed < NUM_SEEDS; seed++) begin
              if (found) break;

              logic match;
              logic [L-1:0] s;
              match = 1'b1;
              s     = logic'(seed[L-1:0]);

              // Compare 128 bits, MSB-first: blk[127] is index 0
              for (int unsigned k = 0; k < BIGM; k++) begin
                logic blk_bit;
                blk_bit = blk[BIGM-1-k];
                if (blk_bit != s[0]) begin
                  match = 1'b0;
                  break;
                end
                s = lfsr_step(s, mask);
              end

              if (match) begin
                found         = 1'b1;
                found_blockid = b[31:0];
                found_taps    = { {(32-L){1'b0}}, mask };
              end
            end
          end
        end

        // Latch outputs
        if (found) begin
          pass    <= 1'b0;
          taps    <= found_taps;
          blockid <= found_blockid;
        end else begin
          pass    <= 1'b1;
          taps    <= 32'd0;
          blockid <= 32'd0;
        end

        done <= 1'b1; // pulse
      end
    end
  end

endmodule