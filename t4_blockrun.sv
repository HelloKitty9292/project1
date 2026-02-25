`default_nettype none

module t4_blockrun #(parameter SMALLN = 2048, parameter BIGM = 128, parameter BIGN = 16) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         en,
  input  logic         start,
  input  logic [SMALLN-1:0] trng,
  input  logic [31:0]  chi_th,
  output logic         done,
  output logic         pass,
  output logic [31:0]  rlte4,
  output logic [31:0]  rof5,
  output logic [31:0]  rof6,
  output logic [31:0]  rof7,
  output logic [31:0]  rof8,
  output logic [31:0]  rgte9
);
  logic [31:0] cnt;
  logic        done_int;
  logic        done_q;

  counter #(.WIDTH(32)) cnt_block (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en((!start) && en && !done_int), .ld(start && en), .Q(cnt));

  assign done_int = ((!start) && en && (cnt == (BIGM-1)));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) done_q <= 1'b0;
    else        done_q <= done_int;
  end

  assign done = done_q;

  logic [BIGN-1:0] bit_q;
  logic [BIGN-1:0] block_lte4, block_of5, block_of6, block_of7, block_of8, block_gte9;

  genvar i;
  generate
  for (i = 0; i < BIGN ; i = i + 1) begin: t4gen
    p2s_shiftreg #(.WIDTH(BIGM)) trng_sr (.clock(clk), .reset_n(rst_n),
                .D(trng[((i+1)*BIGM-1):(i*BIGM)]), 
                .ld(start && en), .en((!start) && en && (!done_int)), .Q(bit_q[i]));
    runs456789 runs (.clk(clk), .rst_n(rst_n), 
                  .start(start), .en(en), .done(done_int),
                  .bit_q(bit_q[i]), 
                  .rlte4(block_lte4[i]), .rof5(block_of5[i]),
                  .rof6(block_of6[i]), .rof7(block_of7[i]),
                  .rof8(block_of8[i]), .rofgte9(block_gte9[i]));
  end
  endgenerate
  
  always_comb begin
    rlte4 = 32'd0;
    rof5  = 32'd0;
    rof6  = 32'd0;
    rof7  = 32'd0;
    rof8  = 32'd0;
    rgte9 = 32'd0;
    for (int j = 0; j < BIGN; j = j + 1) begin
      rlte4 = rlte4 + block_lte4[j];
      rof5  = rof5  + block_of5[j];
      rof6  = rof6  + block_of6[j];
      rof7  = rof7  + block_of7[j];
      rof8  = rof8  + block_of8[j];
      rgte9 = rgte9 + block_gte9[j];
    end
  end

  logic [63:0] chi_value;
  always_comb begin
    chi_value = almost_chi_t4(rlte4, rof5, rof6, rof7, rof8, rgte9, BIGN);
    pass = done && (chi_value <= {32'd0, chi_th});
  end
endmodule : t4_blockrun
`default_nettype none

module runs456789 (
  input  logic clk,
  input  logic rst_n,
  input  logic en,
  input  logic start,
  input  logic done,
  input  logic bit_q,

  output logic rlte4,
  output logic rof5,
  output logic rof6,
  output logic rof7,
  output logic rof8,
  output logic rofgte9
);

  logic [3:0] ones_run;
  logic [3:0] max_ones_run;

  function automatic logic [3:0] sat_inc9(input logic [3:0] x);
    if (x >= 4'd9) sat_inc9 = 4'd9;
    else           sat_inc9 = x + 4'd1;
  endfunction

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      ones_run     <= 4'd0;
      max_ones_run <= 4'd0;

      rlte4        <= 1'b0;
      rof5         <= 1'b0;
      rof6         <= 1'b0;
      rof7         <= 1'b0;
      rof8         <= 1'b0;
      rofgte9      <= 1'b0;

    end else begin
      if (start && en) begin
        ones_run     <= 4'd0;
        max_ones_run <= 4'd0;

        rlte4        <= 1'b0;
        rof5         <= 1'b0;
        rof6         <= 1'b0;
        rof7         <= 1'b0;
        rof8         <= 1'b0;
        rofgte9      <= 1'b0;
      end
      else if (en) begin
        if (bit_q) begin
          ones_run <= sat_inc9(ones_run);
          if (sat_inc9(ones_run) > max_ones_run)
            max_ones_run <= sat_inc9(ones_run);
        end else begin
          ones_run <= 4'd0;
        end
      end

      if (done) begin
        unique case (max_ones_run)
          4'd0, 4'd1, 4'd2, 4'd3, 4'd4: begin
            rlte4   <= 1'b1;
            rof5    <= 1'b0;
            rof6    <= 1'b0;
            rof7    <= 1'b0;
            rof8    <= 1'b0;
            rofgte9 <= 1'b0;
          end
          4'd5: begin
            rlte4   <= 1'b0;
            rof5    <= 1'b1;
            rof6    <= 1'b0;
            rof7    <= 1'b0;
            rof8    <= 1'b0;
            rofgte9 <= 1'b0;
          end
          4'd6: begin
            rlte4   <= 1'b0;
            rof5    <= 1'b0;
            rof6    <= 1'b1;
            rof7    <= 1'b0;
            rof8    <= 1'b0;
            rofgte9 <= 1'b0;
          end
          4'd7: begin
            rlte4   <= 1'b0;
            rof5    <= 1'b0;
            rof6    <= 1'b0;
            rof7    <= 1'b1;
            rof8    <= 1'b0;
            rofgte9 <= 1'b0;
          end
          4'd8: begin
            rlte4   <= 1'b0;
            rof5    <= 1'b0;
            rof6    <= 1'b0;
            rof7    <= 1'b0;
            rof8    <= 1'b1;
            rofgte9 <= 1'b0;
          end
          default: begin
            rlte4   <= 1'b0;
            rof5    <= 1'b0;
            rof6    <= 1'b0;
            rof7    <= 1'b0;
            rof8    <= 1'b0;
            rofgte9 <= 1'b1;
          end
        endcase
      end
    end
  end
endmodule
