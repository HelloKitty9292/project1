module tb_t10();
localparam BUSW = 32;
localparam SMALLN = 2048;
localparam BIGM = 128;
localparam BIGN = 16;
localparam K = 5;
localparam Q = 16;
localparam SMALLM = 9;
localparam LFSRL = 9;

localparam NUM_TESTS = 20;

// The four LFSR tap masks (Galois form)
localparam [8:0] MASK01 = 9'b0_0001_0000; // x^9 + x^4 + 1
localparam [8:0] MASK04 = 9'b0_0010_1100; // x^9 + x^5 + x^3 + x^2 + 1
localparam [8:0] MASK06 = 9'b0_0101_1000; // x^9 + x^6 + x^4 + x^3 + 1
localparam [8:0] MASK10 = 9'b0_0111_0110; // x^9 + x^6 + x^5 + x^4 + x^2 + x^1 + 1

reg clk;
reg rst_n;
wire [SMALLN-1:0] trng;
reg [BUSW-1:0] addr;
reg [BUSW-1:0] data;
wire [BUSW-1:0] data_to_cpu;
reg re;
reg we;

// ============================================================
// Tasks: write, read, check_for_ready
// ============================================================
task write;
input [15:0] mask;
input [15:0] a;
input [BUSW-1:0] d;
begin
	re = 0;
	we = 1;
	addr = {mask, a};
	data = d;
	@(negedge clk);
	we = 0;
end
endtask

task read;
input [15:0] mask;
input [15:0] a;
output [BUSW-1:0] d;
begin
	re = 1;
	we = 0;
	addr = {mask, a};
	@(negedge clk);
	re = 0;
	d = data_to_cpu;
end
endtask

task check_for_ready;
input [15:0] mask;
input [15:0] a;
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
	$display("  trng_wrapper reports ready at clock %0d, time %0t", clocks, $time());
end
endtask

// ============================================================
// Register map
// ============================================================
localparam SR_BASE_ADDR    = 32'h0000_0000;
localparam SR_START_READY  = 16'h0001;
localparam SR_RESULT       = 16'h0002;

localparam SR_T1_DIFF_TH   = 16'h0007;
localparam SR_T2_C1HI_TH   = 16'h000B;
localparam SR_T2_C1LO_TH   = 16'h000C;
localparam SR_T3_LR_TH     = 16'h0012;
localparam SR_T4_CHI_TH    = 16'h001A;

localparam SR_T10_TAPS     = 16'h0047;
localparam SR_T10_BLOCKID  = 16'h0048;

// ============================================================
// TRNG block storage (16 blocks x 128 bits = 2048 bits)
// ============================================================
reg [BIGM-1:0] trngblock0;
reg [BIGM-1:0] trngblock1;
reg [BIGM-1:0] trngblock2;
reg [BIGM-1:0] trngblock3;
reg [BIGM-1:0] trngblock4;
reg [BIGM-1:0] trngblock5;
reg [BIGM-1:0] trngblock6;
reg [BIGM-1:0] trngblock7;
reg [BIGM-1:0] trngblock8;
reg [BIGM-1:0] trngblock9;
reg [BIGM-1:0] trngblock10;
reg [BIGM-1:0] trngblock11;
reg [BIGM-1:0] trngblock12;
reg [BIGM-1:0] trngblock13;
reg [BIGM-1:0] trngblock14;
reg [BIGM-1:0] trngblock15;

assign trng = {trngblock0, trngblock1, trngblock2, trngblock3,
               trngblock4, trngblock5, trngblock6, trngblock7,
               trngblock8, trngblock9, trngblock10, trngblock11,
               trngblock12, trngblock13, trngblock14, trngblock15};

// ============================================================
// DUT
// ============================================================
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

// ============================================================
// Block accessors
// ============================================================
function [BIGM-1:0] get_block;
input integer idx;
begin
	case (idx)
		0:  get_block = trngblock0;
		1:  get_block = trngblock1;
		2:  get_block = trngblock2;
		3:  get_block = trngblock3;
		4:  get_block = trngblock4;
		5:  get_block = trngblock5;
		6:  get_block = trngblock6;
		7:  get_block = trngblock7;
		8:  get_block = trngblock8;
		9:  get_block = trngblock9;
		10: get_block = trngblock10;
		11: get_block = trngblock11;
		12: get_block = trngblock12;
		13: get_block = trngblock13;
		14: get_block = trngblock14;
		15: get_block = trngblock15;
		default: get_block = 0;
	endcase
end
endfunction

task set_block;
input integer idx;
input [BIGM-1:0] val;
begin
	case (idx)
		0:  trngblock0  = val;
		1:  trngblock1  = val;
		2:  trngblock2  = val;
		3:  trngblock3  = val;
		4:  trngblock4  = val;
		5:  trngblock5  = val;
		6:  trngblock6  = val;
		7:  trngblock7  = val;
		8:  trngblock8  = val;
		9:  trngblock9  = val;
		10: trngblock10 = val;
		11: trngblock11 = val;
		12: trngblock12 = val;
		13: trngblock13 = val;
		14: trngblock14 = val;
		15: trngblock15 = val;
	endcase
end
endtask

// ============================================================
// LFSR step — matches RTL exactly:
//
//   temp[i] = mask[i] ? flops[0] : 0;
//   flops <= {flops[0],
//             flops[8]^temp[8], flops[7]^temp[7], flops[6]^temp[6],
//             flops[5]^temp[5], flops[4]^temp[4], flops[3]^temp[3],
//             flops[2]^temp[2], flops[1]^temp[1]};
//
// Used by both generate_lfsr_sequence and check_block_against_lfsrs.
// ============================================================
reg [BIGM-1:0] lfsr_sequence;

task generate_lfsr_sequence;
input [8:0] taps;
input [8:0] seed;
	reg [8:0] lfsr;
	reg [8:0] temp;
	integer bit_idx;
begin
	lfsr = seed;
	for (bit_idx = 0; bit_idx < BIGM; bit_idx = bit_idx + 1) begin
		lfsr_sequence[bit_idx] = lfsr[0];
		temp[0] = taps[0] ? lfsr[0] : 1'b0;
		temp[1] = taps[1] ? lfsr[0] : 1'b0;
		temp[2] = taps[2] ? lfsr[0] : 1'b0;
		temp[3] = taps[3] ? lfsr[0] : 1'b0;
		temp[4] = taps[4] ? lfsr[0] : 1'b0;
		temp[5] = taps[5] ? lfsr[0] : 1'b0;
		temp[6] = taps[6] ? lfsr[0] : 1'b0;
		temp[7] = taps[7] ? lfsr[0] : 1'b0;
		temp[8] = taps[8] ? lfsr[0] : 1'b0;
		lfsr = {lfsr[0],
		        lfsr[8] ^ temp[8],
		        lfsr[7] ^ temp[7],
		        lfsr[6] ^ temp[6],
		        lfsr[5] ^ temp[5],
		        lfsr[4] ^ temp[4],
		        lfsr[3] ^ temp[3],
		        lfsr[2] ^ temp[2],
		        lfsr[1] ^ temp[1]};
	end
end
endtask

// ============================================================
// Reference: check if a block matches ANY lfsr/seed combo
// Uses the same RTL-matching LFSR step as generate_lfsr_sequence
// ============================================================
reg        ref_match;
reg [8:0]  ref_taps;
reg [8:0]  ref_seed;

task check_block_against_lfsrs;
input [BIGM-1:0] block;
	reg [8:0] taps;
	reg [8:0] seed;
	reg [8:0] lfsr;
	reg [8:0] temp;
	integer t, s, b;
	reg mismatch;
begin
	ref_match = 0;
	ref_taps = 0;
	ref_seed = 0;

	for (t = 0; t < 4 && !ref_match; t = t + 1) begin
		case (t)
			0: taps = MASK01;
			1: taps = MASK04;
			2: taps = MASK06;
			3: taps = MASK10;
		endcase

		for (s = 1; s < 512 && !ref_match; s = s + 1) begin
			seed = s[8:0];
			lfsr = seed;
			mismatch = 0;

			for (b = 0; b < BIGM && !mismatch; b = b + 1) begin
				if (block[b] !== lfsr[0])
					mismatch = 1;
				else begin
					// Advance LFSR — same logic as RTL
					temp[0] = taps[0] ? lfsr[0] : 1'b0;
					temp[1] = taps[1] ? lfsr[0] : 1'b0;
					temp[2] = taps[2] ? lfsr[0] : 1'b0;
					temp[3] = taps[3] ? lfsr[0] : 1'b0;
					temp[4] = taps[4] ? lfsr[0] : 1'b0;
					temp[5] = taps[5] ? lfsr[0] : 1'b0;
					temp[6] = taps[6] ? lfsr[0] : 1'b0;
					temp[7] = taps[7] ? lfsr[0] : 1'b0;
					temp[8] = taps[8] ? lfsr[0] : 1'b0;
					lfsr = {lfsr[0],
					        lfsr[8] ^ temp[8],
					        lfsr[7] ^ temp[7],
					        lfsr[6] ^ temp[6],
					        lfsr[5] ^ temp[5],
					        lfsr[4] ^ temp[4],
					        lfsr[3] ^ temp[3],
					        lfsr[2] ^ temp[2],
					        lfsr[1] ^ temp[1]};
				end
			end

			if (!mismatch) begin
				ref_match = 1;
				ref_taps = taps;
				ref_seed = seed;
			end
		end
	end
end
endtask

// ============================================================
// Reference: check all 16 blocks, find first matching block
// ============================================================
reg        exp_pass;
reg [31:0] exp_taps;
reg [31:0] exp_blockid;

task compute_expected_t10;
	integer blk;
	reg [BIGM-1:0] block_data;
begin
	exp_pass = 1;
	exp_taps = 0;
	exp_blockid = 0;

	for (blk = 0; blk < BIGN && exp_pass; blk = blk + 1) begin
		block_data = get_block(blk);
		check_block_against_lfsrs(block_data);
		if (ref_match) begin
			exp_pass = 0;
			exp_taps = {23'b0, ref_taps};
			exp_blockid = blk;
			$display("    Block %0d MATCHES LFSR taps=0x%03h seed=0x%03h", blk + 1, ref_taps, ref_seed);
		end
	end

	if (exp_pass)
		$display("    No LFSR match found -> T10 should PASS");
	else
		$display("    T10 should FAIL: block=%0d taps=0x%03h", exp_blockid + 1, exp_taps);
end
endtask

// ============================================================
// Configure DUT, run, check
// ============================================================
reg [15:0] MASK;
reg [BUSW-1:0] result;
reg [BUSW-1:0] result_taps;
reg [BUSW-1:0] result_blockid;
integer test_err_count;
integer total_err_count;

task run_and_check;
input integer test_num;
begin
	$display("--- Test %0d ---", test_num);
	test_err_count = 0;

	// Reset
	rst_n = 0;
	re = 0;
	we = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	// Configure — bypass T1-T8
	MASK = 16'hDDDD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_DDDD);
	write(MASK, SR_T1_DIFF_TH,  32'hF000_0000);
	write(MASK, SR_T2_C1HI_TH,  32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH,  32'h0000_0000);
	write(MASK, SR_T3_LR_TH,    32'hFFFF_FFFF);
	write(MASK, SR_T4_CHI_TH,   32'hFFFF_FFFF);
	write(MASK, 16'h0030,        32'hFFFF_FFFF); // SR_T7_HITS_TH
	write(MASK, 16'h0043,        32'hFFFF_FFFF); // SR_T8_HITS_TH
	write(MASK, 16'h0045,        32'h0000_01FF); // SR_T78_TEMPLATE

	// Start
	write(MASK, SR_START_READY, 32'h5555_0001);

	// Compute expected
	compute_expected_t10;

	// Wait for DUT
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T10_TAPS, result_taps);
	read(MASK, SR_T10_BLOCKID, result_blockid);

	if (exp_pass) begin
		if (result[10] !== 1'b1) begin
			$error("**T10_ERROR1** Test %0d: T10 should PASS but result[10]=%b (result=0x%08h)", test_num, result[10], result);
			test_err_count = test_err_count + 1;
		end
		if (result_taps !== 32'h0) begin
			$error("**T10_ERROR2** Test %0d: T10 passed but TAPS=0x%08h, expected 0", test_num, result_taps);
			test_err_count = test_err_count + 1;
		end
		if (result_blockid !== 32'h0) begin
			$error("**T10_ERROR3** Test %0d: T10 passed but BLOCKID=%0d, expected 0", test_num, result_blockid);
			test_err_count = test_err_count + 1;
		end
	end
	else begin
		if (result[10] !== 1'b0) begin
			$error("**T10_ERROR4** Test %0d: T10 should FAIL but result[10]=%b (result=0x%08h)", test_num, result[10], result);
			test_err_count = test_err_count + 1;
		end
		if (result_taps !== exp_taps) begin
			$error("**T10_ERROR5** Test %0d: TAPS=0x%08h, expected 0x%08h", test_num, result_taps, exp_taps);
			test_err_count = test_err_count + 1;
		end
		if (result_blockid !== exp_blockid +1  ) begin
			$error("**T10_ERROR6** Test %0d: BLOCKID=%0d, expected %0d", test_num, result_blockid, exp_blockid + 1 );
			test_err_count = test_err_count + 1;
		end
	end

	if (test_err_count == 0)
		$display("  PASS");
	else begin
		$display("  FAILED with %0d errors", test_err_count);
		total_err_count = total_err_count + test_err_count;
	end
end
endtask

// ============================================================
// Helper tasks
// ============================================================
task clear_all_blocks;
	integer idx;
begin
	for (idx = 0; idx < 16; idx = idx + 1)
		set_block(idx, 128'h0);
end
endtask

task randomize_all_blocks;
	integer idx;
begin
	for (idx = 0; idx < 16; idx = idx + 1)
		set_block(idx, {$urandom, $urandom, $urandom, $urandom});
end
endtask

task place_lfsr_block;
input [8:0] taps;
input [8:0] seed;
input integer block_idx;
begin
	generate_lfsr_sequence(taps, seed);
	set_block(block_idx, lfsr_sequence);
	$display("  Placed LFSR block: taps=0x%03h seed=0x%03h -> block %0d (seq=0x%032h)", taps, seed, block_idx, lfsr_sequence);
end
endtask

// ============================================================
// Main test sequence
// ============================================================
integer test_idx;
integer i;
reg [8:0] rand_seed;
reg [8:0] rand_taps;

initial begin
	clk = 0;
	rst_n = 0;
	addr = 0;
	data = 0;
	we = 0;
	re = 0;
	total_err_count = 0;

	trngblock0  = 0; trngblock1  = 0; trngblock2  = 0; trngblock3  = 0;
	trngblock4  = 0; trngblock5  = 0; trngblock6  = 0; trngblock7  = 0;
	trngblock8  = 0; trngblock9  = 0; trngblock10 = 0; trngblock11 = 0;
	trngblock12 = 0; trngblock13 = 0; trngblock14 = 0; trngblock15 = 0;

	@(negedge clk);
	@(negedge clk);

	// --------------------------------------------------------
	// Test 0: All random data — should almost certainly PASS
	// --------------------------------------------------------
	$display("=== Test 0: All random (expect PASS) ===");
	randomize_all_blocks;
	run_and_check(0);

	// --------------------------------------------------------
	// Test 1: LFSR MASK01 in block 0
	// --------------------------------------------------------
	$display("=== Test 1: MASK01 seed=0x001 in block 0 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK01, 9'h001, 0);
	run_and_check(1);

	// --------------------------------------------------------
	// Test 2: LFSR MASK04 in block 7
	// --------------------------------------------------------
	$display("=== Test 2: MASK04 seed=0x0AB in block 7 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK04, 9'h0AB, 7);
	run_and_check(2);

	// --------------------------------------------------------
	// Test 3: LFSR MASK06 in block 15
	// --------------------------------------------------------
	$display("=== Test 3: MASK06 seed=0x1FF in block 15 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK06, 9'h1FF, 15);
	run_and_check(3);

	// --------------------------------------------------------
	// Test 4: LFSR MASK10 in block 0
	// --------------------------------------------------------
	$display("=== Test 4: MASK10 seed=0x055 in block 0 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK10, 9'h055, 0);
	run_and_check(4);

	// --------------------------------------------------------
	// Test 5: Two LFSR blocks — should report the FIRST one
	// --------------------------------------------------------
	$display("=== Test 5: Two LFSR blocks (first = block 3) ===");
	randomize_all_blocks;
	place_lfsr_block(MASK01, 9'h123, 3);
	place_lfsr_block(MASK06, 9'h077, 10);
	run_and_check(5);

	// --------------------------------------------------------
	// Test 6: All blocks are LFSR — should report block 0
	// --------------------------------------------------------
	$display("=== Test 6: All 16 blocks LFSR MASK01 ===");
	for (i = 0; i < 16; i = i + 1) begin
		generate_lfsr_sequence(MASK01, i[8:0] + 9'h001);
		set_block(i, lfsr_sequence);
	end
	run_and_check(6);

	// --------------------------------------------------------
	// Test 7: MASK01 with max seed
	// --------------------------------------------------------
	$display("=== Test 7: MASK01 seed=0x1FF in block 0 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK01, 9'h1FF, 0);
	run_and_check(7);

	// --------------------------------------------------------
	// Test 8: MASK10 in last block
	// --------------------------------------------------------
	$display("=== Test 8: MASK10 seed=0x100 in block 15 ===");
	randomize_all_blocks;
	place_lfsr_block(MASK10, 9'h100, 15);
	run_and_check(8);

	// --------------------------------------------------------
	// Test 9: Near-miss — 1 bit flipped, should PASS
	// --------------------------------------------------------
	$display("=== Test 9: Near-miss (1 bit flipped, expect PASS) ===");
	randomize_all_blocks;
	generate_lfsr_sequence(MASK04, 9'h0AA);
	lfsr_sequence[64] = ~lfsr_sequence[64];
	set_block(5, lfsr_sequence);
	run_and_check(9);

	// --------------------------------------------------------
	// Test 10: All zeros — should PASS
	// --------------------------------------------------------
	$display("=== Test 10: All zeros (expect PASS) ===");
	clear_all_blocks;
	run_and_check(10);

	// --------------------------------------------------------
	// Test 11: All ones
	// --------------------------------------------------------
	$display("=== Test 11: All ones ===");
	for (i = 0; i < 16; i = i + 1)
		set_block(i, {128{1'b1}});
	run_and_check(11);

	// --------------------------------------------------------
	// Tests 12-19: Random +/- LFSR injection
	// --------------------------------------------------------
	for (test_idx = 12; test_idx < NUM_TESTS; test_idx = test_idx + 1) begin
		$display("=== Test %0d: Random +/- LFSR injection ===", test_idx);
		randomize_all_blocks;

		if ($urandom % 2 == 0) begin
			case ($urandom % 4)
				0: rand_taps = MASK01;
				1: rand_taps = MASK04;
				2: rand_taps = MASK06;
				3: rand_taps = MASK10;
			endcase
			rand_seed = ($urandom % 511) + 1;
			i = $urandom % 16;
			place_lfsr_block(rand_taps, rand_seed, i);
		end
		else begin
			$display("  No LFSR injected (expect PASS)");
		end

		run_and_check(test_idx);
	end

	$display("**T10_OK**: T10 testbench did not hang**");
	$finish(1);

end

// ============================================================
// Clock and timeout
// ============================================================
integer clocks = 0;
always begin
	#10;
	clk = ~clk;
	#10;
	clk = ~clk;
	clocks = clocks + 1;
end

always @(clocks) begin
	if (clocks == 20000000) begin
		$display("**T10_HANG**: T10 testbench did not finish?");
		total_err_count = total_err_count + 1;
		$finish(1);
	end
end

final begin

	if (total_err_count == 0)
		$display("**T10_PASS**: All T10 tests passed without errors");

	else
		$display("**T10_FAIL**: There were <%d> errors detected in T10 testbench", total_err_count);

end

endmodule
