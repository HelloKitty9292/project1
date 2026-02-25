`default_nettype none

module t10_taps #(
  parameter SMALLN = 2048,
  parameter LSFRL = 9,
  parameter BIGM = 128,
  parameter BIGN = 16
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,

  output logic              done,
  output logic              pass,
  output logic [31:0]       taps,
  output logic [31:0]       blockid
);

  // Four tap masks (must match TB)
  localparam logic [LSFRL-1:0] MASK01 = 9'b0_0001_0000; // x^9 + x^4 + 1
  localparam logic [LSFRL-1:0] MASK04 = 9'b0_0010_1100; // x^9 + x^5 + x^3 + x^2 + 1
  localparam logic [LSFRL-1:0] MASK06 = 9'b0_0101_1000; // x^9 + x^6 + x^4 + x^3 + 1
  localparam logic [LSFRL-1:0] MASK10 = 9'b0_0111_0110; // x^9 + x^6 + x^5 + x^4 + x^2 + x^1 + 1

  function automatic logic [LSFRL-1:0] tap_sel(input logic [1:0] idx);
    unique case (idx)
      2'd0: tap_sel = MASK01;
      2'd1: tap_sel = MASK04;
      2'd2: tap_sel = MASK06;
      default: tap_sel = MASK10;
    endcase
  endfunction

  function automatic logic [LSFRL-1:0] lfsr_step(
    input logic [LSFRL-1:0] st,
    input logic [LSFRL-1:0] mask
  );
    logic l0;
    l0 = st[0];
    lfsr_step = {
      st[0],
      st[8] ^ (mask[8] & l0),
      st[7] ^ (mask[7] & l0),
      st[6] ^ (mask[6] & l0),
      st[5] ^ (mask[5] & l0),
      st[4] ^ (mask[4] & l0),
      st[3] ^ (mask[3] & l0),
      st[2] ^ (mask[2] & l0),
      st[1] ^ (mask[1] & l0)
    };
  endfunction

  // Extract block k
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    int unsigned base;
    begin
      base = (BIGN-1-k) * BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  typedef enum logic [3:0] {
    S_IDLE,
    S_INIT,
    S_NEW_SEED,
    S_COMPARE,
    S_NEXT_SEED,
    S_NEXT_TAP,
    S_NEXT_BLOCK,
    S_DONE_PULSE
  } state_t;

  state_t state;

  // search indices
  logic [3:0]      blk_idx;   
  logic [1:0]      tap_idx;   
  logic [8:0]      seed;    
  logic [6:0]      bit_idx;   
  logic [LSFRL-1:0]    lfsr;
  logic [LSFRL-1:0]    cur_taps;
  logic [BIGM-1:0] blk;

  // outputs regs
  logic pass_q;
  logic [31:0] taps_q, blockid_q;

  assign pass    = pass_q;
  assign taps    = taps_q;
  assign blockid = blockid_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      done      <= 1'b0;

      blk_idx   <= '0;
      tap_idx   <= '0;
      seed      <= 9'd1;
      bit_idx   <= '0;
      lfsr      <= '0;

      pass_q    <= 1'b1;
      taps_q    <= 32'h0;
      blockid_q <= 32'h0;
    end else begin
      done <= 1'b0; // default

      if (!en) begin
        state <= S_IDLE;
      end else begin
        unique case (state)

          S_IDLE: begin
            if (start) begin
              // clear outputs at start
              pass_q    <= 1'b1;
              taps_q    <= 32'h0;
              blockid_q <= 32'h0;

              blk_idx   <= 4'd0;
              tap_idx   <= 2'd0;
              seed      <= 9'd1;
              bit_idx   <= 7'd0;

              state     <= S_INIT;
            end
          end

          S_INIT: begin
            // load first block and taps
            blk      <= get_block(blk_idx);
            cur_taps <= tap_sel(tap_idx);
            state    <= S_NEW_SEED;
          end

          S_NEW_SEED: begin
            // initialize for this (block, taps, seed)
            lfsr    <= seed;
            bit_idx <= 7'd0;
            state   <= S_COMPARE;
          end

          S_COMPARE: begin
            // compare current bit
            if (blk[bit_idx] !== lfsr[0]) begin
              state <= S_NEXT_SEED;
            end else if (bit_idx == BIGM-1) begin
              // FULL 128-bit match => FAIL
              pass_q    <= 1'b0;
              taps_q    <= {23'b0, cur_taps};
              blockid_q <= (blk_idx + 1);
              state     <= S_DONE_PULSE;
            end else begin
              // match so far
              lfsr    <= lfsr_step(lfsr, cur_taps);
              bit_idx <= bit_idx + 1;
            end
          end

          S_NEXT_SEED: begin
            if (seed == 9'd511) begin
              state <= S_NEXT_TAP;
            end else begin
              seed  <= seed + 1;
              state <= S_NEW_SEED;
            end
          end

          S_NEXT_TAP: begin
            seed <= 9'd1;
            if (tap_idx == 2'd3) begin
              state <= S_NEXT_BLOCK;
            end else begin
              tap_idx <= tap_idx + 1;
              cur_taps <= tap_sel(tap_idx + 1);
              state <= S_NEW_SEED;
            end
          end

          S_NEXT_BLOCK: begin
            tap_idx <= 2'd0;
            seed    <= 9'd1;
            if (blk_idx == BIGN-1) begin
              // no match => PASS
              pass_q    <= 1'b1;
              taps_q    <= 32'h0;
              blockid_q <= 32'h0;
              state     <= S_DONE_PULSE;
            end else begin
              blk_idx <= blk_idx + 1;
              blk     <= get_block(blk_idx + 1);
              cur_taps <= tap_sel(2'd0);
              state   <= S_NEW_SEED;
            end
          end

          S_DONE_PULSE: begin
            done  <= 1'b1; 
            state <= S_IDLE;
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

endmodule
