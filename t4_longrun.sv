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
  assign done = (cnt == BIGM);
  counter #(.WIDTH(32)) cnt_block (.clock(clk), .reset_n(rst_n), .D(32'd0),
          .en((!start) && en && (!done)), .ld((start && en) || done), .Q(cnt));

  logic [BIGN-1:0] bit_q;
  logic [BIGN-1:0] block_lte4, block_of5, block_of6, block_of7, block_of8, block_gte9;

  genvar i;
  generate
  for (i = 0; i < BIGN ; i = i + 1) begin: t4gen
    p2s_shiftreg #(.WIDTH(BIGM)) trng_sr (.clock(clk), .reset_n(rst_n),
                .D(trng[((i+1)*BIGM-1):(i*BIGM)]), 
                .ld((!start) && en && (!done)), .en((!start) && en), .Q(bit_q[i]));
    runs456789 runs (.clk(clk), .rst_n(rst_n), 
                  .start(start), .en(en), .done(done),
                  .bit_q(bit_q[i]), 
                  .rlte4(block_lte4[i]), .rof5(block_of5[i]),
                  .rof6(block_of6[i]), .rof7(block_of7[i]),
                  .rof8(block_of8[i]), .rofgte9(block_gte9[i]));
  end
  endgenerate : t4_blockrun
  
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
    pass      = pass = done && (chi_value <= {32'd0, chi_th});
  end
endmodule : t4_blockrun

module runs456789 #(parameter BIGM = 128) (
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

  logic       curr_bit;
  logic [3:0] curr_run, max_run;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rlte4   <= 1'b0;
      rof5    <= 1'b0;
      rof6    <= 1'b0;
      rof7    <= 1'b0;
      rof8    <= 1'b0;
      rofgte9 <= 1'b0;

      curr_bit <= 1'b0;
      curr_run <= 4'd0;
      max_run  <= 4'd0;
    end else begin
      if (start && en) begin
        curr_bit <= bit_q;
        curr_run <= 4'd1;
        max_run  <= 4'd1;
      end else if (en) begin
        if (!(bit_q ^ curr_bit)) begin
          if (curr_run != 4'd9) curr_run <= curr_run + 4'd1;
          if ((maxrun != 4'd9) && ((curr_run + 4'd1) > max_run)) max_run <= (curr_run + 4'd1);
        end else begin
          curr_bit <= bit_q;
          curr_run <= 4'd1;
          if (4'd1 > max_run) max_run <= 4'd1;
        end
      end

      if (done) begin
        unique case (max_run)
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

function automatic logic [63:0] almost_chi_t4 (
  input logic [31:0] v0, v1, v2, v3, v4, v5,
  input logic [31:0] N_blocks
);

  logic signed [31:0] d0, d1, d2, d3, d4, d5;
  logic signed [63:0] s0, s1, s2, s3, s4, s5;

  begin
    d0 = $signed(100 * v0) - $signed(N_blocks * 12);
    d1 = $signed(100 * v1) - $signed(N_blocks * 24);
    d2 = $signed(100 * v2) - $signed(N_blocks * 25);
    d3 = $signed(100 * v3) - $signed(N_blocks * 18);
    d4 = $signed(100 * v4) - $signed(N_blocks * 10);
    d5 = $signed(100 * v5) - $signed(N_blocks * 11);

    s0 = d0 * d0;
    s1 = d1 * d1;
    s2 = d2 * d2;
    s3 = d3 * d3;
    s4 = d4 * d4;
    s5 = d5 * d5;

    almost_chi_t4 = s0 + s1 + s2 + s3 + s4 + s5;
  end
endfunction

// module runs456789(input  logic clk, rst_n,
//                   input  logic start, en, done,
//                   input  logic bit_q, 
//                   output logic rlte4, rof5, rof6, rof7, rof8, rofgte9);
//   logic [3:0] currRun;
//   logic       currBit;
//   always_ff @(posedge clk, negedge rst_n) begin
//     if (~rst_n || (start && en)) begin
//       rlte4   = 1'b0;
//       rof5    = 1'b0;
//       rof6    = 1'b0;
//       rof7    = 1'b0;
//       rof8    = 1'b0;
//       rofgte9 = 1'b0;
//       currRun = 4'd0;
//       currBit = 1'b0;
//     end else if (done) begin
//       currBit <= 1'b0;
//       currRun <= 4'd0;
//       rlte4   <= rlte4  ;
//       rof5    <= rof5   ;
//       rof6    <= rof6   ;
//       rof7    <= rof7   ;
//       rof8    <= rof8   ;
//       rofgte9 <= rofgte9;
//     end else if (en) begin
//       if (bit_q ^ currBit) begin
//         currBit <= bit_q;
//         currRun <= 4'd1;
//         unique case (currRun)
//           1,2,3,4: rlte4   <= 1'b1;
//           5:       rof5    <= 1'b1;
//           6:       rof6    <= 1'b1;
//           7:       rof7    <= 1'b1;
//           8:       rof8    <= 1'b1;
//           default: rofgte9 <= 1'b1;
//         endcase
//       end else begin
//         currRun <= ((currRun + 1) > 4'd9) ? 4'd9 : (currRun + 1);
//       end
//     end
//   end
// endmodule : runs456789