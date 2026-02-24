`default_nettype none

module t3_runs #(parameter SMALLN = 2048) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]       lr_th,
  output logic              done,
  output logic              pass,
  output logic [31:0]       lr1,
  output logic [31:0]       lr0,
  output logic [31:0]       nr1,
  output logic [31:0]       nr0
);

  // ---- serial source ----
  logic bit_q;
  logic sh_ld, sh_en;

  p2s_shiftreg #(.WIDTH(SMALLN)) trng_sr (
    .clock   (clk),
    .reset_n (rst_n),
    .D       (trng),
    .ld      (sh_ld),
    .en      (sh_en),
    .Q       (bit_q)
  );

  // ---- state ----
  enum logic [1:0] {START_S, COUNT_S, DONE_S} state, next_state;

  // ---- counters / trackers ----
  logic [31:0] idx;          // how many bits processed so far (0..SMALLN-1)
  logic        prev_valid;
  logic        prev_bit;
  logic [31:0] curr_len;

  // convenience
  logic do_start;
  logic do_count;
  logic last_bit;

  assign do_start = (state == START_S) && en && start;
  assign do_count = (state == COUNT_S) && en;
  assign last_bit = (idx == (SMALLN-1));

  // ---- state FF ----
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= START_S;
    else        state <= next_state;
  end

  // ---- next state ----
  always_comb begin
    unique case (state)
      START_S: next_state = (en && start) ? COUNT_S : START_S;

      // go DONE right after processing the last bit
      COUNT_S: next_state = (do_count && last_bit) ? DONE_S : COUNT_S;

      // hold DONE until wrapper deasserts en
      DONE_S:  next_state = en ? DONE_S : START_S;

      default: next_state = START_S;
    endcase
  end

  // ---- outputs ----
  always_comb begin
    // shift control
    sh_ld = do_start;
    sh_en = (state == COUNT_S) && en;

    // done/pass
    done = (state == DONE_S);
    pass = (state == DONE_S) && (lr1 <= lr_th) && (lr0 <= lr_th);
  end

  // ---- main datapath ----
  // We update:
  // - nr1/nr0 when a new run starts (first bit or bit flips)
  // - lr1/lr0 when a run ends (bit flips) and at the very end (last bit)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx        <= 32'd0;
      prev_valid <= 1'b0;
      prev_bit   <= 1'b0;
      curr_len   <= 32'd0;

      lr1 <= 32'd0;
      lr0 <= 32'd0;
      nr1 <= 32'd0;
      nr0 <= 32'd0;

    end else begin
      if (do_start) begin
        idx        <= 32'd0;
        prev_valid <= 1'b0;
        prev_bit   <= 1'b0;
        curr_len   <= 32'd0;

        lr1 <= 32'd0;
        lr0 <= 32'd0;
        nr1 <= 32'd0;
        nr0 <= 32'd0;

      end else if (do_count) begin
        // ---- process current bit ----
        if (!prev_valid) begin
          // first bit starts a new run
          prev_valid <= 1'b1;
          prev_bit   <= bit_q;
          curr_len   <= 32'd1;

          if (bit_q) nr1 <= nr1 + 32'd1;
          else       nr0 <= nr0 + 32'd1;

        end else if (bit_q == prev_bit) begin
          // continue the current run
          curr_len <= curr_len + 32'd1;

        end else begin
          // run ended -> update longest for prev_bit
          if (prev_bit) begin
            if (curr_len > lr1) lr1 <= curr_len;
          end else begin
            if (curr_len > lr0) lr0 <= curr_len;
          end

          // start new run
          prev_bit <= bit_q;
          curr_len <= 32'd1;

          if (bit_q) nr1 <= nr1 + 32'd1;
          else       nr0 <= nr0 + 32'd1;
        end

        // ---- if this is the last bit, finalize longest run too ----
        if (last_bit) begin
          // Note: curr_len might have just been updated above, but in FF logic
          // we must use "next" info carefully. The safe approach is to update
          // longest using the value *as of this cycle*:
          //
          // - if bit continues run: (curr_len + 1) is the true final length
          // - if bit flips: we already wrote longest for the ended run, and
          //   the new run length is 1
          //
          // We handle both cases explicitly:
          if (!prev_valid) begin
            // single-bit stream (shouldn't happen for SMALLN>=1), but safe:
            if (bit_q) begin
              if (32'd1 > lr1) lr1 <= 32'd1;
            end else begin
              if (32'd1 > lr0) lr0 <= 32'd1;
            end

          end else if (bit_q == prev_bit) begin
            // final run length is curr_len + 1
            if (prev_bit) begin
              if ((curr_len + 32'd1) > lr1) lr1 <= (curr_len + 32'd1);
            end else begin
              if ((curr_len + 32'd1) > lr0) lr0 <= (curr_len + 32'd1);
            end

          end else begin
            // bit flipped on last bit: new run length is 1
            if (bit_q) begin
              if (32'd1 > lr1) lr1 <= 32'd1;
            end else begin
              if (32'd1 > lr0) lr0 <= 32'd1;
            end
          end
        end

        // advance index
        idx <= idx + 32'd1;
      end
    end
  end

endmodule