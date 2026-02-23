module tb_t13();
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
localparam SR_T7_HITS_TH	= 16'h0030;
localparam SR_T8_HITS_TH	= 16'h0043;
localparam SR_T78_TEMPLATE	= 16'h0045;
localparam SR_T13_CHI 		= 16'h004A;
localparam SR_T13_CLO 		= 16'h004B;
localparam SR_T13_CTH		= 16'h004C;

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
reg [BUSW-1:0] resulthi = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resultlo = 32'hFFFF_FFFF; // used with the read function to get data from CPU

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
	MASK = 16'hABCD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_ABCD);
	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low. the goal is to bypass T2
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);
	// sets the threshold to T3 to super high value to force a pass
	write(MASK, SR_T3_LR_TH, 32'hFFFF_FFFF);
	// sets the threshold to T4 to super high value to force a pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);
	// sets the threshold to T7/T8 to super high value to force a pass
	write(MASK, SR_T7_HITS_TH, 32'd999);
	write(MASK, SR_T8_HITS_TH, 32'd999);

	// test 13 begins here. threhsold is super high on purpose to get a pass
	write(MASK, SR_T13_CTH, 32'd9999);
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T13_CHI,resulthi);
	read(MASK, SR_T13_CLO, resultlo);

	if (result[13] != 1'b1) begin
		$error("**T13_ERROR1**: trng_wrapper returned wrong result (%b). Test 13 should have passed", result);
		err_count += 1;
	end

	if (resulthi != 2048) begin
		$error("**T13_ERROR2**: trng_wrapper made a mistake: %d", resulthi);
		err_count += 1;
	end
	if (resultlo != 0) begin
		$error("**T13_ERROR3**: trng_wrapper made a mistake: %d", resultlo);
		err_count += 1;
	end

	// without resetting the design, we ask the wrapper to run again. this
	// checks if counters are being managed correctly across runs
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T13_CHI,resulthi);
	read(MASK, SR_T13_CLO, resultlo);

	if (result[13] != 1'b1) begin
		$error("**T13_ERROR4**: trng_wrapper returned wrong result (%b). Test 13 should have passed", result);
		err_count += 1;
	end
	if (resulthi != 2048) begin
		$error("**T13_ERROR5**: trng_wrapper made a mistake: %d", resulthi);
		err_count += 1;
	end
	if (resultlo != 0) begin
		$error("**T13_ERROR6**: trng_wrapper likely made a mistake: %d", resultlo);
		err_count += 1;
	end

	// here we do a full reset before changing inputs
	rst_n = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	trngblock0 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock1 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock2 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock3 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock4 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock5 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock6 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock7 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock8 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock9 =  128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock10 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock11 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock12 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock13 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock14 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
	trngblock15 = 128'h0000_0000_0000_0000_0000_0000_0000_0000;

	// CPU configures base address
	MASK = 16'hABCD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_ABCD);
	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low. the goal is to bypass T2
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);
	// sets the threshold to T3 to super high value to force a pass
	write(MASK, SR_T3_LR_TH, 32'hFFFF_FFFF);
	// sets the threshold to T4 to super high value to force a pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);
	// sets the threshold to T7/T8 to super high value to force a pass
	write(MASK, SR_T7_HITS_TH, 32'd999);
	write(MASK, SR_T8_HITS_TH, 32'd999);

	// test 13 begins here. threhsold is super high on purpose to get a pass
	write(MASK, SR_T13_CTH, 32'd9999);
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T13_CHI,resulthi);
	read(MASK, SR_T13_CLO, resultlo);

	if (result[13] != 1'b1) begin
		$error("**T13_ERROR7**: trng_wrapper returned wrong result (%b). Test 13 should have passed", result);
		err_count += 1;
	end
	if (resulthi != 0) begin
		$error("**T13_ERROR8**: trng_wrapper made a mistake: %d", resulthi);
		err_count += 1;
	end
	if (resultlo != 2048) begin // LOOKATME! you can change this line depending on the assumption you have made about how to represent CLO
		// maybe you are returning the sign as well as the value, and that is allowed
	    //    $display("**T13_ERROR9**: trng_wrapper *MAYBE* made a mistake: %b %d", resultlo[12:0], resultlo[12:0]);
	       $display("**T13_ERROR9**: trng_wrapper *MAYBE* made a mistake: %b %d %d", resultlo[12:0], resultlo[12:0], $signed(resultlo));
	    //    $stop();
	end

	// here we do a full reset again before changing inputs
	rst_n = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	trngblock0 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock1 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock2 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock3 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock4 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock5 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock6 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock7 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock8 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock9 =  128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock10 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock11 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock12 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock13 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock14 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;
	trngblock15 = 128'h0000_FFFF_0000_FFFF_0000_FFFF_0000_FFFF;

	// CPU configures base address
	MASK = 16'hABCD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_ABCD);
	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low. the goal is to bypass T2
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);
	// sets the threshold to T3 to super high value to force a pass
	write(MASK, SR_T3_LR_TH, 32'hFFFF_FFFF);
	// sets the threshold to T4 to super high value to force a pass
	write(MASK, SR_T4_CHI_TH, 32'hFFFF_FFFF);
	// sets the threshold to T7/T8 to super high value to force a pass
	write(MASK, SR_T7_HITS_TH, 32'd999);
	write(MASK, SR_T8_HITS_TH, 32'd999);

	// test 13 begins here. threhsold is low on purpose to get a pass by a small margin that matches the threshold
	write(MASK, SR_T13_CTH, 32'd16);
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T13_CHI,resulthi);
	read(MASK, SR_T13_CLO, resultlo);

	if (result[13] != 1'b1) begin
		$error("**T13_ERROR10**: trng_wrapper returned wrong result (%b). Test 13 should have passed", result);
		err_count += 1;
	end
	if (resulthi != 0) begin
		$error("**T13_ERROR11**: trng_wrapper made a mistake: %d", resulthi);
		err_count += 1;
	end
	if (resultlo != 16) begin // LOOKATME! you can change this line depending on the assumption you have made about how to represent CLO
	    //    $display("**T13_ERROR12**: trng_wrapper *MAYBE* made a mistake: %d", resultlo);
	       $display("**T13_ERROR12**: trng_wrapper *MAYBE* made a mistake: %d %d", resultlo, $signed(resultlo));
	    //    $stop();
       end

       	// test 13 begins here. threhsold is low on purpose to get a fail by a small margin, one below threshold
	write(MASK, SR_T13_CTH, 32'd15);
	write(MASK, SR_START_READY, 32'h5555_0001);
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T13_CHI,resulthi);
	read(MASK, SR_T13_CLO, resultlo);

	if (result[13] != 1'b0) begin
		$error("**T13_ERROR13**: trng_wrapper returned wrong result (%b). Test 13 should have failed", result);
		err_count += 1;
	end
	if (resulthi != 0) begin
		$error("**T13_ERROR14**: trng_wrapper made a mistake: %d", resulthi);
		err_count += 1;
	end
	if (resultlo != 16) begin // LOOKATME! you can change this line depending on the assumption you have made about how to represent CLO
	    //    $display("**T13_ERROR15**: trng_wrapper *MAYBE* made a mistake: %d", resultlo);
	       $display("**T13_ERROR15**: trng_wrapper *MAYBE* made a mistake: %d %d", resultlo, $signed(resultlo));
	    //    $stop();
       end

	$display("**T13_OK**: T13 testbench did not hang**");
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
	if (clocks == 40000) begin
		$display("**T13_HANG**: T13 testbench did not finish?");
		err_count += 1;
		$stop();
	end
end

final begin

	if (err_count == 0)
		$display("**T13_PASS**: All T13 tests passed without errors");

	else
		$display("**T13_FAIL**: There were <%d> errors detected in T13 testbench", err_count);

end

endmodule
