module tb_t7 ();
localparam BUSW = 32;
localparam SMALLN = 2048;
localparam BIGM = 128;
localparam BIGN = 16;
localparam K = 5;
localparam Q = 16;
localparam SMALLM = 9;
localparam LFSRL = 9;

reg clk;
reg rst_n; // active low, asynchronous reset
wire [SMALLN-1:0] trng;
reg [BUSW-1:0] addr;
reg [BUSW-1:0] data;
wire [BUSW-1:0] data_to_cpu;
reg re; // active high
reg we; // active high
reg[31:0] err_count;

task write(input [15:0] mask, input [15:0] a, input [BUSW-1:0] d);
begin
	re = 0;
	we = 1;
	addr = {mask,a};
	data = d;
	@(negedge clk);
	we = 0;
end
endtask

task read(input [15:0] mask, input [15:0] a, output [BUSW-1:0] d );
begin
	re = 1;
	we = 0;
	addr = {mask, a};
	@(negedge clk); // this clock edge might not be necessary because some
	// implementations might return the data in the same clock cycle
	re = 0;
	d = data_to_cpu;
end
endtask

task check_for_ready(input [15:0] mask, input [15:0] a);
reg [BUSW-1:0] ready;
begin
	re = 1;
	we = 0;
	addr = {mask, a};
	@(negedge clk);
	ready = data_to_cpu;
	while (ready != 32'hFFFF_FFFF) begin
		@(negedge clk);
		ready = data_to_cpu;
	end
	$display("trng_wrapper reports it is ready at clock %d time %t", clocks, $time());
end

endtask

assert property (@(posedge clk) !(re && we));
assert property (@(posedge clk) !$isunknown(data_to_cpu)) else begin
	err_count +=1;
	$fatal(1, "X in data_from_cpu at <%t>", $time());
end

// offsets encoded as 16 bits, to be used with a mask
localparam SR_BASE_ADDR	 	= 32'h0000_0000;
localparam SR_START_READY 	= 16'h0001;
localparam SR_RESULT	 	= 16'h0002;

localparam SR_T1_DIFF_TH 	= 16'h0007;
localparam SR_T2_C1HI_TH 	= 16'h000B;
localparam SR_T2_C1LO_TH 	= 16'h000C;
localparam SR_T3_LR_TH		= 16'h0012;
localparam SR_T4_CHI_TH 	= 16'h001A;

localparam SR_T7_B00HITS	= 16'h001F;
localparam SR_T7_B01HITS	= 16'h0020;
localparam SR_T7_B02HITS	= 16'h0021;
localparam SR_T7_B03HITS	= 16'h0022;
localparam SR_T7_B04HITS	= 16'h0023;
localparam SR_T7_B05HITS	= 16'h0024;
localparam SR_T7_B06HITS	= 16'h0025;
localparam SR_T7_B07HITS	= 16'h0026;
localparam SR_T7_B08HITS	= 16'h0027;
localparam SR_T7_B09HITS	= 16'h0028;
localparam SR_T7_B10HITS	= 16'h0029;
localparam SR_T7_B11HITS	= 16'h002A;
localparam SR_T7_B12HITS	= 16'h002B;
localparam SR_T7_B13HITS	= 16'h002C;
localparam SR_T7_B14HITS	= 16'h002D;
localparam SR_T7_B15HITS	= 16'h002E;
localparam SR_T7_HITS_TH	= 16'h0030;
localparam SR_T78_TEMPLATE	= 16'h0045;

reg [BIGM-1:0] trngblock0 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock1 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock2 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock3 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock4 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock5 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock6 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock7 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock8 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock9 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock10 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock11 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock12 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock13 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock14 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock15 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

assign trng = {trngblock0,trngblock1,trngblock2,trngblock3,trngblock4,trngblock5,trngblock6,trngblock7,trngblock8,trngblock9,trngblock10,trngblock11,trngblock12,trngblock13,trngblock14,trngblock15};

trng_wrapper trng_wrapper (
	.clk (clk),
	.rst_n (rst_n),
	.trng (trng),
	.addr (addr),
	.data_from_cpu (data),
	.data_to_cpu (data_to_cpu),
	.re (re),
	.we (we)
);

reg [15:0] MASK; // stores the offset to be written in SR_BASE_ADDR
reg [BUSW-1:0] result = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result00 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result01 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result02 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result03 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result04 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result05 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result06 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result07 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result08 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result09 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result10 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result11 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result12 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result13 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result14 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result15 = 32'hFFFF_FFFF; // used with the read function to get data from CPU

initial begin
	//trng is assined from block variables, see code above
	clk = 0;
	rst_n = 0;
	addr = 0;
	data = 0;
	we = 0;
	re = 0;
	err_count = 0;

	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	// CPU configures base address
	MASK = 16'hDDDD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_DDDD);
	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low. the goal is to bypass T2
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);
	// sets the threshold to T3 to super high value to force a pass
	write(MASK, SR_T3_LR_TH, 32'hFFFF_FFFF);
	// sets the threshold to T4 to super high value to force a pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);

	// test 7 begins here. hits threshold is set very high to make sure test passes
	write(MASK, SR_T7_HITS_TH, 32'd999);
	write(MASK, SR_T78_TEMPLATE, 32'h0000_FFFF); // pattern is all 1s, trng data is all 1s too
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T7_B00HITS, result00);
	read(MASK, SR_T7_B01HITS, result01);
	read(MASK, SR_T7_B02HITS, result02);
	read(MASK, SR_T7_B03HITS, result03);
	read(MASK, SR_T7_B04HITS, result04);
	read(MASK, SR_T7_B05HITS, result05);
	read(MASK, SR_T7_B06HITS, result06);
	read(MASK, SR_T7_B07HITS, result07);
	read(MASK, SR_T7_B08HITS, result08);
	read(MASK, SR_T7_B09HITS, result09);
	read(MASK, SR_T7_B10HITS, result10);
	read(MASK, SR_T7_B11HITS, result11);
	read(MASK, SR_T7_B12HITS, result12);
	read(MASK, SR_T7_B13HITS, result13);
	read(MASK, SR_T7_B14HITS, result14);
	read(MASK, SR_T7_B15HITS, result15);

	if (result[7] != 1'b1) begin
		$error("**T7_ERROR1**: trng_wrapper returned wrong result (%b). Test 7 should have passed", result);
		err_count += 1;
	end

	if (result00 != 14) begin
		$error("**T7_ERROR2**: trng_wrapper made a matching mistake: %d", result00);
		err_count += 1;
	end

	if (result01 != 14) begin
		$error("**T7_ERROR3**: trng_wrapper made a matching mistake: %d", result01);
		err_count += 1;
	end

	if (result02 != 14) begin
		$error("**T7_ERROR4**: trng_wrapper made a matching mistake: %d", result02);
		err_count += 1;
	end

	if (result03 != 14) begin
		$error("**T7_ERROR5**: trng_wrapper made a matching mistake: %d", result03);
		err_count += 1;
	end

	if (result04 != 14) begin
		$error("**T7_ERROR6**: trng_wrapper made a matching mistake: %d", result04);
		err_count += 1;
	end

	if (result05 != 14) begin
		$error("**T7_ERROR7**: trng_wrapper made a matching mistake: %d", result05);
		err_count += 1;
	end

	if (result06 != 14) begin
		$error("**T7_ERROR8**: trng_wrapper made a matching mistake: %d", result06);
		err_count += 1;
	end

	if (result07 != 14) begin
		$error("**T7_ERROR9**: trng_wrapper made a matching mistake: %d", result07);
		err_count += 1;
	end

	if (result08 != 14) begin
		$error("**T7_ERROR10**: trng_wrapper made a matching mistake: %d", result08);
		err_count += 1;
	end

	if (result09 != 14) begin
		$error("**T7_ERROR11**: trng_wrapper made a matching mistake: %d", result09);
		err_count += 1;
	end

	if (result10 != 14) begin
		$error("**T7_ERROR12**: trng_wrapper made a matching mistake: %d", result10);
		err_count += 1;
	end

	if (result11 != 14) begin
		$error("**T7_ERROR13**: trng_wrapper made a matching mistake: %d", result11);
		err_count += 1;
	end

	if (result12 != 14) begin
		$error("**T7_ERROR14**: trng_wrapper made a matching mistake: %d", result12);
		err_count += 1;
	end

	if (result13 != 14) begin
		$error("**T7_ERROR15**: trng_wrapper made a matching mistake: %d", result13);
		err_count += 1;
	end

	if (result14 != 14) begin
		$error("**T7_ERROR16**: trng_wrapper made a matching mistake: %d", result14);
		err_count += 1;
	end

	if (result15 != 14) begin
		$error("**T7_ERROR17**: trng_wrapper made a matching mistake: %d", result15);
		err_count += 1;
	end

	// without resetting the design, we ask the wrapper to run again. this
	// checks if counters are being managed correctly across runs
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T7_B00HITS, result00);
	read(MASK, SR_T7_B01HITS, result01);
	read(MASK, SR_T7_B02HITS, result02);
	read(MASK, SR_T7_B03HITS, result03);
	read(MASK, SR_T7_B04HITS, result04);
	read(MASK, SR_T7_B05HITS, result05);
	read(MASK, SR_T7_B06HITS, result06);
	read(MASK, SR_T7_B07HITS, result07);
	read(MASK, SR_T7_B08HITS, result08);
	read(MASK, SR_T7_B09HITS, result09);
	read(MASK, SR_T7_B10HITS, result10);
	read(MASK, SR_T7_B11HITS, result11);
	read(MASK, SR_T7_B12HITS, result12);
	read(MASK, SR_T7_B13HITS, result13);
	read(MASK, SR_T7_B14HITS, result14);
	read(MASK, SR_T7_B15HITS, result15);

	if (result[7] != 1'b1) begin
		$error("**T7_ERROR18**: trng_wrapper returned wrong result (%b). Test 7 should have passed", result);
		err_count += 1;
	end

	if (result00 != 14) begin
		$error("**T7_ERROR19**: trng_wrapper made a matching mistake: %d", result00);
		err_count += 1;
	end

	if (result01 != 14) begin
		$error("**T7_ERROR20**: trng_wrapper made a matching mistake: %d", result01);
		err_count += 1;
	end

	if (result02 != 14) begin
		$error("**T7_ERROR21**: trng_wrapper made a matching mistake: %d", result02);
		err_count += 1;
	end

	if (result03 != 14) begin
		$error("**T7_ERROR22**: trng_wrapper made a matching mistake: %d", result03);
		err_count += 1;
	end

	if (result04 != 14) begin
		$error("**T7_ERROR23**: trng_wrapper made a matching mistake: %d", result04);
		err_count += 1;
	end

	if (result05 != 14) begin
		$error("**T7_ERROR24**: trng_wrapper made a matching mistake: %d", result05);
		err_count += 1;
	end

	if (result06 != 14) begin
		$error("**T7_ERROR25**: trng_wrapper made a matching mistake: %d", result06);
		err_count += 1;
	end

	if (result07 != 14) begin
		$error("**T7_ERROR26**: trng_wrapper made a matching mistake: %d", result07);
		err_count += 1;
	end

	if (result08 != 14) begin
		$error("**T7_ERROR27**: trng_wrapper made a matching mistake: %d", result08);
		err_count += 1;
	end

	if (result09 != 14) begin
		$error("**T7_ERROR28**: trng_wrapper made a matching mistake: %d", result09);
		err_count += 1;
	end

	if (result10 != 14) begin
		$error("**T7_ERROR29**: trng_wrapper made a matching mistake: %d", result10);
		err_count += 1;
	end

	if (result11 != 14) begin
		$error("**T7_ERROR30**: trng_wrapper made a matching mistake: %d", result11);
		err_count += 1;
	end

	if (result12 != 14) begin
		$error("**T7_ERROR31**: trng_wrapper made a matching mistake: %d", result12);
		err_count += 1;
	end

	if (result13 != 14) begin
		$error("**T7_ERROR32**: trng_wrapper made a matching mistake: %d", result13);
		err_count += 1;
	end

	if (result14 != 14) begin
		$error("**T7_ERROR33**: trng_wrapper made a matching mistake: %d", result14);
		err_count += 1;
	end

	if (result15 != 14) begin
		$error("**T7_ERROR34**: trng_wrapper made a matching mistake: %d", result15);
		err_count += 1;
	end

	// here we do a full reset before changing inputs
	rst_n = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	trngblock0 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock1 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock2 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock3 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock4 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock5 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock6 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	//trngblock7 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock8 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock9 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock10 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock11 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock12 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock13 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock14 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock15 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;

	write(16'h0000, SR_BASE_ADDR, 32'h0000_DDDD);
	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low. the goal is to bypass T2
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);
	// sets the threshold to T3 to super high value to force a pass
	write(MASK, SR_T3_LR_TH, 32'hFFFF_FFFF);
	// sets the threshold to T4 to super high value to force a pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);

	// test 7 begins here. hits threshold is set to 13 to make sure test fails. block 7 remains all FFFF
	// this test also checks for what the block order is.
	write(MASK, SR_T7_HITS_TH, 32'd13);
	write(MASK, SR_T78_TEMPLATE, 32'h0000_FFFF); // pattern is all 1s
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T7_B00HITS, result00);
	read(MASK, SR_T7_B01HITS, result01);
	read(MASK, SR_T7_B02HITS, result02);
	read(MASK, SR_T7_B03HITS, result03);
	read(MASK, SR_T7_B04HITS, result04);
	read(MASK, SR_T7_B05HITS, result05);
	read(MASK, SR_T7_B06HITS, result06);
	read(MASK, SR_T7_B07HITS, result07);
	read(MASK, SR_T7_B08HITS, result08);
	read(MASK, SR_T7_B09HITS, result09);
	read(MASK, SR_T7_B10HITS, result10);
	read(MASK, SR_T7_B11HITS, result11);
	read(MASK, SR_T7_B12HITS, result12);
	read(MASK, SR_T7_B13HITS, result13);
	read(MASK, SR_T7_B14HITS, result14);
	read(MASK, SR_T7_B15HITS, result15);

	if (result[7] != 1'b0) begin
		$display("**T7_ERROR35**: trng_wrapper returned wrong result (%b). Test 7 should have failed", result);
		err_count += 1;
	end

	if (result00 != 0) begin
		$error("**T7_ERROR36**: trng_wrapper made a matching mistake: %d", result00);
		err_count += 1;
	end

	if (result01 != 0) begin
		$error("**T7_ERROR37**: trng_wrapper made a matching mistake: %d", result01);
		err_count += 1;
	end
	if (result02 != 0) begin
		$error("**T7_ERROR38**: trng_wrapper made a matching mistake: %d", result02);
		err_count += 1;
	end
	if (result03 != 0) begin
		$error("**T7_ERROR39**: trng_wrapper made a matching mistake: %d", result03);
		err_count += 1;
	end
	if (result04 != 0) begin
		$error("**T7_ERROR40**: trng_wrapper made a matching mistake: %d", result04);
		err_count += 1;
	end
	if (result05 != 0) begin
		$error("**T7_ERROR41**: trng_wrapper made a matching mistake: %d", result05);
		err_count += 1;
	end
	if (result06 != 0) begin
		$error("**T7_ERROR42**: trng_wrapper made a matching mistake: %d", result06);
		err_count += 1;
	end
	if (result07 != 14) begin
		$error("**T7_ERROR43**: trng_wrapper made a matching mistake: %d", result07);
		err_count += 1;
	end
	if (result08 != 0) begin
		$error("**T7_ERROR44**: trng_wrapper made a matching mistake: %d", result08);
		err_count += 1;
	end
	if (result09 != 0) begin
		$error("**T7_ERROR45**: trng_wrapper made a matching mistake: %d", result09);
		err_count += 1;
	end
	if (result10 != 0) begin
		$error("**T7_ERROR46**: trng_wrapper made a matching mistake: %d", result10);
		err_count += 1;
	end
	if (result11 != 0) begin
		$error("**T7_ERROR47**: trng_wrapper made a matching mistake: %d", result11);
		err_count += 1;
	end
	if (result12 != 0) begin
		$error("**T7_ERROR48**: trng_wrapper made a matching mistake: %d", result12);
		err_count += 1;
	end
	if (result13 != 0) begin
		$error("**T7_ERROR49**: trng_wrapper made a matching mistake: %d", result13);
		err_count += 1;
	end
	if (result14 != 0) begin
		$error("**T7_ERROR50**: trng_wrapper made a matching mistake: %d", result14);
		err_count += 1;
	end
	if (result15 != 0) begin
		$error("**T7_ERROR51**: trng_wrapper made a matching mistake: %d", result15);
		err_count += 1;
	end

	$display("**T7_OK**: T7 testbench did not hang**");
	$finish(1);

end

integer clocks = 0;
always begin
	#10;
	clk = ~clk;
	#10;
	clk = ~clk;
	clocks = clocks + 1;
end

always @(clocks) begin
	if (clocks == 20000) begin
		$error("**T7_HANG**: T7 testbench did not finish?");
		err_count += 1;
		$finish(1);
	end
end

final begin

	if (err_count == 0)
		$display("**T7_PASS**: All T7 tests passed without errors");

	else
		$display("**T7_FAIL**: There were <%d> errors detected in T7 testbench", err_count);

end

endmodule
