module tb_cpu ();
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

reg [BIGM-1:0] trngblock0 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock1 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock2 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock3 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock4 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock5 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock6 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock7 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock8 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
reg [BIGM-1:0] trngblock9 =  128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
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
reg [15:0] i; // used to iterate over addresses
reg [BUSW-1:0] result = 32'hFFFF_FFFF; // used with the read function to get data from CPU

initial begin
	clk = 0;
	rst_n = 0;
	//trng is assined from block variables
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

	// CPU configures base address but gives some additional 1 that should be ignored
	write(16'h0000, SR_BASE_ADDR, 32'h0010_ABCD);
	read(16'h0000, 16'h0000, result);

	if (result != 32'h0000_ABCD) begin
		$error("**CPU_ERROR1**: trng_wrapper misinterpreted the use of SR_BASE_ADDR");
		err_count += 1;
	end

	// CPU configures base address again, this time a normal input is provided
	write(16'h0000, SR_BASE_ADDR, 32'h0000_EEEE);
	read(16'h0000, 16'h0000, result);

	if (result != 32'h0000_EEEE) begin
		$error("**CPU_ERROR2**: trng_wrapper misinterpreted the use of SR_BASE_ADDR");
		err_count += 1;
	end

	// next_ the CPU goes on a duck hunt and tries to write to every address it can think of.
	// it write with the right mask and with another mask.
	// some Ws should be accepted, most shouldn't
	MASK = 16'hEEEE;
	for (i = 16'h0002; i < 16'h00FF; i = i + 1) begin
		write(MASK, i, 32'h1234_5678);
	end
	MASK = 16'hAAAA;
	for (i = 16'h0002; i < 16'h00FF; i = i + 1) begin
		write(MASK, i, 32'h5678_1234);
	end
	MASK = 16'hEEEE;
	for (i = 16'h0002; i < 16'h00FF; i = i + 1) begin
		read(MASK, i, result);
		if (result != 32'h0000_0000) begin
			$error("**CPU_ERROR3**: trng_wrapper misinterpreted the access pattern for address %h. expected: 0000_0000, got %h", i, result);
			err_count += 1;
		end
	end

	write(MASK, SR_START_READY, 32'h0000_0000); // since this is all zeros, no tests should start.
	read(MASK, SR_RESULT, result);
	if (result != 32'h0000_0000) begin
		$error("**CPU_ERROR4**: trng_wrapper appears to have finished, but no start was issued");
		err_count += 1;
	end

	i = 99;
	while (i>0) begin
		i = i -1;
		@(negedge clk); // advance time by 100 clock cycles
	end
	read(MASK, SR_RESULT, result);
	if (result != 32'h0000_0000) begin
		$error("**CPU_ERROR5**: trng_wrapper appears to have finished, but no start was issued");
		err_count += 1;
	end

	write(MASK, SR_START_READY, 32'hFFFF_FFFF); // since this is all ones, no tests should start. however, the write should be accepted
	check_for_ready(MASK, SR_START_READY); // this only returns if SR_START_READY == 32'hFFFF_FFFF;

	$display("**CPU_OK**: CPU testbench did not hang**");
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
	if (clocks == 10000) begin
		$display("**CPU_HANG**: CPU testbench did not finish?");
		$stop();
	end
end


endmodule


