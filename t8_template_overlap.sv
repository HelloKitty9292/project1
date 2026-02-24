`default_nettype none

module t8_template_hits #(
  parameter int unsigned N    = 2048,
  parameter int unsigned BIGM = 128,
  parameter int unsigned M    = 9
)(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   en,
  input  logic                   start,
  input  logic [N-1:0]           trng,
  input  logic [31:0]            hits_th,
  input  logic [M-1:0]           template_bits,

  output logic                   done,
  output logic                   pass,
  output logic [31:0]            hits [0:(N/BIGM)-1]
);

  localparam int unsigned NBLOCKS = N / BIGM;
  localparam int unsigned POS_W   = $clog2(BIGM+1);

  logic [POS_W-1:0] pos;
  logic [M-1:0]     win  [0:NBLOCKS-1];
  logic [$clog2(M+1)-1:0] fill [0:NBLOCKS-1];

  // bit order: block0 is MSB chunk; within block scan MSB->LSB
  function automatic logic trng_bit(input int unsigned blk, input int unsigned p);
    int unsigned base_msb;
    begin
      base_msb = (N-1) - blk*BIGM;
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
          logic [M-1:0] win_next;
          logic [$clog2(M+1)-1:0] fill_next;

          bit_in   = trng_bit(b, pos);
          win_next = {win[b][M-2:0], bit_in};

          // compute next fill (saturate at M)
          if (fill[b] == M[$clog2(M+1)-1:0]) fill_next = fill[b];
          else                               fill_next = fill[b] + 1'b1;

          win[b]  <= win_next;
          fill[b] <= fill_next;

          // KEY FIX:
          // count matches as soon as the window becomes valid (fill_next == M)
          if (fill_next == M[$clog2(M+1)-1:0]) begin
            if (win_next == template_bits) hits[b] <= hits[b] + 32'd1;
          end
        end

        pos <= pos + 1'b1;
      end
    end
  end

endmodule
