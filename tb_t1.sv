module tb_t1 ();
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

localparam SR_T1_C1	 	= 16'h0004;
localparam SR_T1_C0	 	= 16'h0005;
localparam SR_T1_DIFF	 	= 16'h0006;
localparam SR_T1_DIFF_TH 	= 16'h0007;

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
reg [BIGM-1:0] trngblock15 = 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAA1; // there are 1025 zeros, 1023 ones

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
reg [BUSW-1:0] result0 = 32'hFFFF_FFFF; // used with the read function to get data from CPU
reg [BUSW-1:0] result1 = 32'hFFFF_FFFF; // used with the read function to get data from CPU

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
	MASK = 16'hBBBB;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_BBBB);

	// CPU sets the threshold for T1 diff as 3. it should pass
	write(MASK, SR_T1_DIFF_TH, 32'h0000_0003);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b1) begin
		$error("**T1_ERROR1**: trng_wrapper returned wrong result (%b). Test 1 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR2**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// CPU sets the threshold for T1 diff as 2. it should still pass. this
	// check might fail for implementations that misinterpret the meaning of threshold
	write(MASK, SR_T1_DIFF_TH, 32'h0000_0002);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b1) begin
		$error("**T1_ERROR3**: trng_wrapper returned wrong result (%b). Test 1 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR4**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// CPU sets the threshold for T1 diff as 1. it should fail
	write(MASK, SR_T1_DIFF_TH, 32'h0000_0001);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b0) begin
		$error("**T1_ERROR5**: trng_wrapper returned wrong result (%b). Test 1 should have failed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR6**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// here we do a full reset before changing inputs of the trng to all zeros
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
	MASK = 16'hBBBB;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_BBBB);

	// CPU sets the threshold for T1 diff as very high number. anything should pass
	write(MASK, SR_T1_DIFF_TH, 32'h1000_0000);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b1) begin
		$error("**T1_ERROR7**: trng_wrapper returned wrong result (%b). Test 1 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR8**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// CPU sets the threshold for T1 diff as very small number.
	write(MASK, SR_T1_DIFF_TH, 32'h0000_0001);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b0) begin
		$error("**T1_ERROR9**: trng_wrapper returned wrong result (%b). Test 1 should have failed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR10**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// here we do a full reset before changing inputs of the trng to all ones
	rst_n = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	trngblock0 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock1 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock2 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock3 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock4 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock5 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock6 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock7 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock8 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock9 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock10 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock11 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock12 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock13 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock14 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
	trngblock15 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

	// CPU configures base address
	MASK = 16'hBBBB;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_BBBB);

	// CPU sets the threshold for T1 diff as very high number. anything should pass
	write(MASK, SR_T1_DIFF_TH, 32'h1000_0000);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b1) begin
		$error("**T1_ERROR12**: trng_wrapper returned wrong result (%b). Test 1 should have passed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR13**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	// CPU sets the threshold for T1 diff as very small number.
	write(MASK, SR_T1_DIFF_TH, 32'h0000_0001);
	// CPU says tests should start
	write(MASK, SR_START_READY, 32'h5555_0001);
	// CPU waits for tests to conclude
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	if (result[1] != 1'b0) begin
		$error("**T1_ERROR14**: trng_wrapper returned wrong result (%b). Test 1 should have failed", result);
		err_count += 1;
	end
	read(MASK, SR_T1_C1, result1);
	read(MASK, SR_T1_C0, result0);
	if ((result1+result0) != 2048) begin
		$error("**T1_ERROR15**: trng_wrapper returned wrong counts");
		err_count += 1;
	end

	$display("**T1_OK**: T1 testbench did not hang**");
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
	if (clocks == 20000) begin
		$display("**T1_HANG**: T1 testbench did not finish?");
		$stop();
	end
end

final begin

	if (err_count == 0)
		$display("**T1_PASS**: All T1 tests passed without errors");

	else
		$display("**T1_FAIL**: There were <%d> errors detected in T1 testbench", err_count);
end

endmodule
