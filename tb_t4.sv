module tb_t4();
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
localparam SR_T4_RLTE4		= 16'h0014;
localparam SR_T4_ROF5		= 16'h0015;
localparam SR_T4_ROF6		= 16'h0016;
localparam SR_T4_ROF7		= 16'h0017;
localparam SR_T4_ROF8		= 16'h0018;
localparam SR_T4_RGTE9		= 16'h0019;
localparam SR_T4_CHI_TH 	= 16'h001A;

reg [BIGM-1:0] trngblock0 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock1 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock2 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock3 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock4 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock5 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock6 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock7 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock8 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock9 =  128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock10 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock11 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock12 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock13 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock14 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
reg [BIGM-1:0] trngblock15 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;

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
reg [BUSW-1:0] resultrlte4 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultrof5 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultrof6 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultrof7 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultrof8 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultrgte9 = 32'hFFFF_FFFF; // used with the read function to get data from CPU

initial begin
	//trng is already assined from block variables, see code above
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

	// test 4 begins here. treshold is set very high, it should pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T4_RLTE4, resultrlte4);
	read(MASK, SR_T4_ROF5, resultrof5);
	read(MASK, SR_T4_ROF6, resultrof6);
	read(MASK, SR_T4_ROF7, resultrof7);
	read(MASK, SR_T4_ROF8, resultrof8);
	read(MASK, SR_T4_RGTE9, resultrgte9);

	if (result[4] != 1'b1) begin
		$error("**T4_ERROR1**: trng_wrapper returned wrong result (%b). Test 4 should have passed", result);
		err_count += 1;
	end
	if (resultrlte4 != 16) begin
		$error("**T4_ERROR2*: Test 4 should have returned 16, it returned %d instead", resultrlte4);
		err_count += 1;
	end
	if (resultrof5 != 0) begin
		$error("**T4_ERROR3*: Test 4 should have returned 0, it returned %d instead", resultrof5);
		err_count += 1;
	end
	if (resultrof6 != 0) begin
		$error("**T4_ERROR4*: Test 4 should have returned 0, it returned %d instead", resultrof6);
		err_count += 1;
	end
	if (resultrof7 != 0) begin
		$error("**T4_ERROR5*: Test 4 should have returned 0, it returned %d instead", resultrof7);
		err_count += 1;
	end
	if (resultrof8 != 0) begin
		$error("**T4_ERROR6*: Test 4 should have returned 0, it returned %d instead", resultrof8);
		err_count += 1;
	end
	// if (resultrof8 != 0) begin
	// 	$display("**T4_ERROR7*: Test 4 should have returned 0, it returned %d instead", resultrgte9);
	// 	$stop();
	// end

	// here we do a full reset before changing inputs of the trng to almost all zeros
	// implementations that misinterpret what to count will struggle with this pattern
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
	trngblock7 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock8 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock9 =  128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock10 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock11 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock12 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock13 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock14 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
	trngblock15 = 128'h0000_0000_0000_0000_0000_0000_0000_0001;

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

	// test 4 begins here. threshold is set to 1023 (VERY SMALL), should fail
	write(MASK, SR_T4_CHI_TH, 32'd1023);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T4_RLTE4, resultrlte4);
	read(MASK, SR_T4_ROF5, resultrof5);
	read(MASK, SR_T4_ROF6, resultrof6);
	read(MASK, SR_T4_ROF7, resultrof7);
	read(MASK, SR_T4_ROF8, resultrof8);
	read(MASK, SR_T4_RGTE9, resultrgte9);

	if (result[4] != 1'b0) begin
		$error("**T4_ERROR8**: trng_wrapper returned wrong result (%b). Test 4 should have failed", result);
		err_count += 1;
	end
	if ((resultrlte4 + resultrof5 + resultrof6 + resultrof7 + resultrof8 + resultrgte9) != 16 ) begin  // impossible!
		$error("**T4_ERROR9**: trng_wrapper returned wrong results. Sum is not 16!");
		err_count += 1;
	end

	// here we do a full reset before changing inputs of the trng to a single FFFF and a lot of zeros
	rst_n = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	trngblock0 =  128'h0000_0000_0000_0000_0000_0000_0000_FFFF;
	trngblock1 =  128'h0000_0000_0000_0000_0000_0000_FFFF_0000;
	trngblock2 =  128'h0000_0000_0000_0000_0000_FFFF_0000_0000;
	trngblock3 =  128'h0000_0000_0000_0000_FFFF_0000_0000_0000;
	trngblock4 =  128'h0000_0000_0000_FFFF_0000_0000_0000_0000;
	trngblock5 =  128'h0000_0000_FFFF_0000_0000_0000_0000_0000;
	trngblock6 =  128'h0000_FFFF_0000_0000_0000_0000_0000_0000;
	trngblock7 =  128'hFFFF_0000_0000_0000_0000_0000_0000_0000;
	trngblock8 =  128'h0000_0000_0000_0000_0000_0000_0000_FFFF;
	trngblock9 =  128'h0000_0000_0000_0000_0000_0000_FFFF_0000;
	trngblock10 = 128'h0000_0000_0000_0000_0000_FFFF_0000_0000;
	trngblock11 = 128'h0000_0000_0000_0000_FFFF_0000_0000_0000;
	trngblock12 = 128'h0000_0000_0000_FFFF_0000_0000_0000_0000;
	trngblock13 = 128'h0000_0000_FFFF_0000_0000_0000_0000_0000;
	trngblock14 = 128'h0000_FFFF_0000_0000_0000_0000_0000_0000;
	trngblock15 = 128'hFFFF_0000_0000_0000_0000_0000_0000_0000;
	// because all blocks have runs of 1s of length 16, RGTE9 should be 16

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

	// test 4 begins here. threshold is set to almost correct value, should fail by 1
	write(MASK, SR_T4_CHI_TH, 32'd2480639);

	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T4_RLTE4, resultrlte4);
	read(MASK, SR_T4_ROF5, resultrof5);
	read(MASK, SR_T4_ROF6, resultrof6);
	read(MASK, SR_T4_ROF7, resultrof7);
	read(MASK, SR_T4_ROF8, resultrof8);
	read(MASK, SR_T4_RGTE9, resultrgte9);

	if (result[4] != 1'b0) begin
		$error("**T4_ERROR10**: trng_wrapper returned wrong result (%b). Test 4 should have failed", result);
		err_count += 1;
	end
	if ((resultrlte4 + resultrof5 + resultrof6 + resultrof7 + resultrof8 + resultrgte9) != 16 ) begin  // impossible value
		$error("**T4_ERROR11**: trng_wrapper returned wrong results. Sum is not 16!");
		err_count += 1;
	end

	// this test starts the same computation without a reset. it checks
	// whether registers are being assigned correctly during multiple runs
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T4_RLTE4, resultrlte4);
	read(MASK, SR_T4_ROF5, resultrof5);
	read(MASK, SR_T4_ROF6, resultrof6);
	read(MASK, SR_T4_ROF7, resultrof7);
	read(MASK, SR_T4_ROF8, resultrof8);
	read(MASK, SR_T4_RGTE9, resultrgte9);

	if (result[4] != 1'b0) begin
		$display("**T4_ERROR12**: trng_wrapper returned wrong result (%b). Test 4 should have failed", result);
		$error("**T4_ERROR12**: trng_wrapper returned wrong result (%b). Test 4 should have failed", result);
		err_count += 1;
	end
	if ((resultrlte4 + resultrof5 + resultrof6 + resultrof7 + resultrof8 + resultrgte9) != 16) begin  // impossible value
		$error("**T4_ERROR13**: trng_wrapper returned wrong results. Sum is not 16!");
		err_count += 1;
	end

	$display("**T4_OK**: T4 testbench did not hang**");
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
		$display("**T4_HANG**: T4 testbench did not finish?");
		err_count += 1;
		$finish(1);
	end
end

final begin

	if (err_count == 0)
		$display("**T4_PASS**: All T4 tests passed without errors");

	else
		$display("**T4_FAIL**: There were <%d> errors detected in T4 testbench", err_count);

end

endmodule
