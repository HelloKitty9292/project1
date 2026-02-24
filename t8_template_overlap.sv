`default_nettype none

module t8_template_hits #(
  parameter SMALLN = 2048,
  parameter BIGM = 128,
  parameter SMALLM = 9
)(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]       hits_th,
  input  logic [SMALLM-1:0] template_bits,

  output logic              done,
  output logic              pass,
  output logic [31:0]       hits [0:(SMALLN/BIGM)-1]
);

  localparam int unsigned NBLOCKS = SMALLN / BIGM;
  localparam int unsigned POS_W   = myclog2(BIGM+1);

  logic [POS_W-1:0]             pos;
  logic [SMALLM-1:0]            win  [0:NBLOCKS-1];
  logic [myclog2(SMALLM+1)-1:0] fill [0:NBLOCKS-1];

  function automatic logic trng_bit(input int unsigned blk, input int unsigned p);
    int unsigned base_msb;
    begin
      base_msb = (SMALLN-1) - blk*BIGM;
      trng_bit = trng[base_msb - p];
    end
  endfunction

  logic [31:0] max_hits;
  always_comb begin
    max_hits = 32'd0;
    for (int i = 0; i < NBLOCKS; i++) begin
      if (hits[i] > max_hits) max_hits = hits[i];
    end
  end

  always_comb begin
    done = (pos == BIGM[POS_W-1:0]);
    pass = done && (max_hits <= hits_th);
  end

  // main scan
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pos <= '0;
      for (int b = 0; b < NBLOCKS; b++) begin
        hits[b] <= 32'd0;
        win[b]  <= '0;
        fill[b] <= '0;
      end
    end else begin
      if (start && en) begin
        pos <= '0;
        for (int b = 0; b < NBLOCKS; b++) begin
          hits[b] <= 32'd0;
          win[b]  <= '0;
          fill[b] <= '0;
        end
      end else if (en && (pos != BIGM[POS_W-1:0])) begin
        for (int b = 0; b < NBLOCKS; b++) begin
          logic bit_in;
          logic [SMALLM-1:0] win_next;
          logic [myclog2(SMALLM+1)-1:0] fill_next;

          bit_in   = trng_bit(b, pos);
          win_next = {win[b][SMALLM-2:0], bit_in};

          // compute next fill
          if (fill[b] == SMALLM[myclog2(SMALLM+1)-1:0]) fill_next = fill[b];
          else                               fill_next = fill[b] + 1'b1;

          win[b]  <= win_next;
          fill[b] <= fill_next;

          if (fill_next == SMALLM[myclog2(SMALLM+1)-1:0]) begin
            if (win_next == template_bits) hits[b] <= hits[b] + 32'd1;
          end
        end

        pos <= pos + 1'b1;
      end
    end
  end

endmodule
