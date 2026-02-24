module tb_t2();
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
localparam SR_T2_C1HI	 	= 16'h0009;
localparam SR_T2_C1LO	 	= 16'h000A;
localparam SR_T2_C1HI_TH 	= 16'h000B;
localparam SR_T2_C1LO_TH 	= 16'h000C;

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
reg [BIGM-1:0] trngblock15 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAA1;

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
reg [BUSW-1:0] resultlo = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] resulthi = 32'hFFFF_FFFF; // used with the read function to get data from CPU

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
	MASK = 16'hCCCC;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_CCCC);

	// CPU sets the threshold for T1 diff as very high. the goal is to bypass T1
	write(MASK, SR_T1_DIFF_TH, 32'hF000_0000);
	// CPU sets the threshold for T2 as very high/very low, T2 should pass
	write(MASK, SR_T2_C1HI_TH, 32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0000);

	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b1) begin
		$error("**T2_ERROR1**: trng_wrapper returned wrong result (%b). Test 2 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63 (64 for most blocks, 63 for block 15)
		$error("**T2_ERROR2**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	// CPU says tests should start again. no data has changed, results from before should hold
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b1) begin
		$error("**T2_ERROR3**: trng_wrapper returned wrong result (%b). Test 2 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63
		$error("**T2_ERROR4**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	// CPU sets the threshold for T2 again. T2 should no longer pass
	// because both thresholds fail
	write(MASK, SR_T2_C1HI_TH, 32'h0000_0001);
	write(MASK, SR_T2_C1LO_TH, 32'h0000_0001);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b0) begin
		$error("**T2_ERROR5**: trng_wrapper returned wrong result (%b). Test 2 should have failed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63
		$error("**T2_ERROR6**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	// CPU sets the threshold for T2 again. T2 should PASS because thresholds are inclusive
	write(MASK, SR_T2_C1HI_TH, 32'd64);
	write(MASK, SR_T2_C1LO_TH, 32'd63);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b1) begin
		$error("**T2_ERROR7**: trng_wrapper returned wrong result (%b). Test 2 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63.
		$error("**T2_ERROR8**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	// CPU sets the threshold for T2 again. T2 should FAIL because one threshold is violated
	write(MASK, SR_T2_C1HI_TH, 32'd63);
	write(MASK, SR_T2_C1LO_TH, 32'd63);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b0) begin
		$error("**T2_ERROR9**: trng_wrapper returned wrong result (%b). Test 2 should not have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63.
		$error("**T2_ERROR10**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	// CPU sets the threshold for T2 again. T2 should FAIL because the other threshold is violated
	write(MASK, SR_T2_C1HI_TH, 32'd64);
	write(MASK, SR_T2_C1LO_TH, 32'd64);
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[2] != 1'b0) begin
		$error("**T2_ERROR11**: trng_wrapper returned wrong result (%b). Test 2 should not have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T2_C1HI, resulthi);
	read(MASK, SR_T2_C1LO, resultlo);
	if ((resulthi+resultlo) != 127) begin // 64 + 63.
		$error("**T2_ERROR12**: trng_wrapper returned wrong counts: %d and %d", resulthi, resultlo);
		err_count += 1;
	end

	$display("**T2_OK**: T2 testbench did not hang**");
	$finish();
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
	// if (clocks == 1000) begin
	if (clocks == 200000) begin
		$error("**T2_HANG**: T2 testbench did not finish?");
		err_count += 1;
		$stop();
	end
end

final begin

	if (err_count == 0)
		$display("**T2_PASS**: All T2 tests passed without errors");

	else
		$display("**T2_FAIL**: There were <%d> errors detected in T2 testbench", err_count);

end

endmodule
