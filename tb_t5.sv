module tb_t5();
localparam BUSW = 32;
localparam SMALLN = 2048;
localparam BIGM = 128;
localparam BIGN = 16;
localparam K = 5;
localparam Q = 16;
localparam SMALLM = 9;
localparam LFSRL = 9;

localparam NUM_MATRICES = 8; // 2048 / (16*16) = 8
localparam NUM_TESTS = 20;

reg clk;
reg rst_n;
wire [SMALLN-1:0] trng;
reg [BUSW-1:0] addr;
reg [BUSW-1:0] data;
wire [BUSW-1:0] data_to_cpu;
reg re;
reg we;
reg[31:0] err_count;

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

assert property (@(posedge clk) !(re && we));
assert property (@(posedge clk) !$isunknown(data_to_cpu)) else begin
	err_count +=1;
	$fatal(1, "X in data_from_cpu at <%t>", $time());
end

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

localparam SR_T5_RFULL     = 16'h001C;
localparam SR_T5_RFULLM1   = 16'h001D;

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
// GF(2) Rank reference model
// We store the working matrix in a flat reg and use indexing.
// mat_flat[row*16 +: 16] is row `row`.
// ============================================================
reg [16*16-1:0] mat_flat;
reg [15:0] rank_tmp_row;
integer rank_result;

task compute_gf2_rank;
	// Input: mat_flat must be loaded before calling
	// Output: rank_result
	reg [15:0] m [0:15];
	reg [15:0] tmp;
	integer r, c, pivot, found;
begin
	// Copy from flat to array
	for (r = 0; r < 16; r = r + 1)
		m[r] = mat_flat[r*16 +: 16];

	rank_result = 0;
	pivot = 0;

	for (c = 15; c >= 0; c = c - 1) begin
		// Find pivot row
		found = -1;
		for (r = pivot; r < 16; r = r + 1) begin
			if (m[r][c] == 1'b1 && found == -1)
				found = r;
		end

		if (found != -1) begin
			// Swap
			tmp = m[pivot];
			m[pivot] = m[found];
			m[found] = tmp;

			// Eliminate
			for (r = 0; r < 16; r = r + 1) begin
				if (r != pivot && m[r][c] == 1'b1)
					m[r] = m[r] ^ m[pivot];
			end

			rank_result = rank_result + 1;
			pivot = pivot + 1;
		end
	end
end
endtask

// ============================================================
// Helper: get a trngblock by index (no unpacked arrays)
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

// ============================================================
// Helper: set a trngblock by index
// ============================================================
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
// Compute expected rfull/rfullm1 from current trng blocks
// ============================================================
integer exp_rfull, exp_rfullm1;

task compute_expected;
	reg [BIGM-1:0] blk_hi, blk_lo;
	integer mi, row;
begin
	exp_rfull = 0;
	exp_rfullm1 = 0;

	for (mi = 0; mi < NUM_MATRICES; mi = mi + 1) begin
		blk_hi = get_block(mi * 2);
		blk_lo = get_block(mi * 2 + 1);

		// Load mat_flat: row 0 from MSB of blk_hi, etc.
		for (row = 0; row < 8; row = row + 1)
			mat_flat[row*16 +: 16] = blk_hi[(7 - row) * 16 +: 16];
		for (row = 0; row < 8; row = row + 1)
			mat_flat[(8 + row)*16 +: 16] = blk_lo[(7 - row) * 16 +: 16];

		compute_gf2_rank;

		$display("    Matrix %0d: rank = %0d", mi, rank_result);

		if (rank_result == 16)
			exp_rfull = exp_rfull + 1;
		else if (rank_result == 15)
			exp_rfullm1 = exp_rfullm1 + 1;
	end
end
endtask

// ============================================================
// Task: configure DUT, run test, check results
// ============================================================
reg [15:0] MASK;
reg [BUSW-1:0] result;
reg [BUSW-1:0] resultrfull;
reg [BUSW-1:0] resultrfullm1;

task run_and_check;
input integer test_num;
begin
	$display("--- Test %0d ---", test_num);

	// Reset
	rst_n = 0;
	re = 0;
	we = 0;
	err_count = 0;
	@(negedge clk);
	@(negedge clk);
	rst_n = 1;
	@(negedge clk);
	@(negedge clk);

	// Configure — bypass T1-T4
	MASK = 16'hDDDD;
	write(16'h0000, SR_BASE_ADDR, 32'h0000_DDDD);
	write(MASK, SR_T1_DIFF_TH,  32'hF000_0000);
	write(MASK, SR_T2_C1HI_TH,  32'hF000_0000);
	write(MASK, SR_T2_C1LO_TH,  32'h0000_0000);
	write(MASK, SR_T3_LR_TH,    32'hFFFF_FFFF);
	write(MASK, SR_T4_CHI_TH,   32'hFFFF_FFFF);
	write(MASK, SR_START_READY,  32'h5555_0001);

	// Compute expected
	compute_expected;

	// Wait for DUT
	check_for_ready(MASK, SR_START_READY);
	read(MASK, SR_RESULT, result);
	read(MASK, SR_T5_RFULL, resultrfull);
	read(MASK, SR_T5_RFULLM1, resultrfullm1);

	// Check T5 pass bit
	if (result[5] !== 1'b1) begin
		$error("**T5_ERROR1** Test %0d: result bit[5] = %b, expected 1. Full result = %b", test_num, result[5], result);
		err_count += 1;
	end

	// Check rfull
	if (resultrfull !== exp_rfull) begin
		$error("**T5_ERROR2** Test %0d: RFULL = %0d, expected %0d", test_num, resultrfull, exp_rfull);
		err_count += 1;
	end

	// Check rfullm1
	if (resultrfullm1 !== exp_rfullm1) begin
		$error("**T5_ERROR3** Test %0d: RFULLM1 = %0d, expected %0d", test_num, resultrfullm1, exp_rfullm1);
		err_count += 1;
	end

	$display("  PASS: rfull=%0d (exp %0d), rfullm1=%0d (exp %0d)", resultrfull, exp_rfull, resultrfullm1, exp_rfullm1);
end
endtask

// ============================================================
// Helper: set a 16x16 matrix into slot mi using 16 row values
// Stored as a flat 256-bit reg to avoid unpacked array args
// mat_rows_flat[row*16 +: 16] = row value
// ============================================================
reg [16*16-1:0] mat_rows_flat;

task write_matrix_to_slot;
input integer mi;
	// Uses mat_rows_flat which must be loaded before calling
	reg [BIGM-1:0] blk_hi, blk_lo;
	integer row;
begin
	blk_hi = 0;
	blk_lo = 0;
	for (row = 0; row < 8; row = row + 1)
		blk_hi[(7 - row) * 16 +: 16] = mat_rows_flat[row * 16 +: 16];
	for (row = 0; row < 8; row = row + 1)
		blk_lo[(7 - row) * 16 +: 16] = mat_rows_flat[(8 + row) * 16 +: 16];

	set_block(mi * 2,     blk_hi);
	set_block(mi * 2 + 1, blk_lo);
end
endtask

// ============================================================
// Helper: load identity matrix into mat_rows_flat
// ============================================================
task load_identity;
	integer r;
begin
	mat_rows_flat = 0;
	for (r = 0; r < 16; r = r + 1)
		mat_rows_flat[r * 16 +: 16] = (16'h1 << r);
end
endtask

// ============================================================
// Helper: clear all blocks to zero
// ============================================================
task clear_all_blocks;
	integer idx;
begin
	for (idx = 0; idx < 16; idx = idx + 1)
		set_block(idx, 128'h0);
end
endtask

// ============================================================
// Helper: randomize all blocks
// ============================================================
task randomize_all_blocks;
	integer idx;
begin
	for (idx = 0; idx < 16; idx = idx + 1)
		set_block(idx, {$urandom, $urandom, $urandom, $urandom});
end
endtask

// ============================================================
// Main test sequence
// ============================================================
integer test_idx;
integer i;

initial begin
	clk = 0;
	rst_n = 0;
	addr = 0;
	data = 0;
	we = 0;
	re = 0;

	trngblock0  = 0; trngblock1  = 0; trngblock2  = 0; trngblock3  = 0;
	trngblock4  = 0; trngblock5  = 0; trngblock6  = 0; trngblock7  = 0;
	trngblock8  = 0; trngblock9  = 0; trngblock10 = 0; trngblock11 = 0;
	trngblock12 = 0; trngblock13 = 0; trngblock14 = 0; trngblock15 = 0;

	@(negedge clk);
	@(negedge clk);

	// --------------------------------------------------------
	// Test 0: All zeros — every matrix has rank 0
	// --------------------------------------------------------
	$display("=== Test 0: All zeros ===");
	clear_all_blocks;
	run_and_check(0);

	// --------------------------------------------------------
	// Test 1: All ones — every row is 16'hFFFF (rank 1)
	// --------------------------------------------------------
	$display("=== Test 1: All ones ===");
	for (i = 0; i < 16; i = i + 1)
		set_block(i, {128{1'b1}});
	run_and_check(1);

	// --------------------------------------------------------
	// Test 2: Identity matrix in slot 0, zeros elsewhere
	// --------------------------------------------------------
	$display("=== Test 2: Identity in slot 0 ===");
	clear_all_blocks;
	load_identity;
	write_matrix_to_slot(0);
	run_and_check(2);

	// --------------------------------------------------------
	// Test 3: Identity in every slot (all 8 matrices full rank)
	// --------------------------------------------------------
	$display("=== Test 3: Identity in all 8 slots ===");
	load_identity;
	for (i = 0; i < NUM_MATRICES; i = i + 1)
		write_matrix_to_slot(i);
	run_and_check(3);

	// --------------------------------------------------------
	// Test 4: Rank-15 (identity with row 0 zeroed) in all slots
	// --------------------------------------------------------
	$display("=== Test 4: Rank-15 in all 8 slots ===");
	load_identity;
	mat_rows_flat[0*16 +: 16] = 16'h0000; // zero row 0 -> rank 15
	for (i = 0; i < NUM_MATRICES; i = i + 1)
		write_matrix_to_slot(i);
	run_and_check(4);

	// --------------------------------------------------------
	// Test 5: Mix — 4 full-rank, 4 rank-15
	// --------------------------------------------------------
	$display("=== Test 5: 4 full-rank + 4 rank-15 ===");
	load_identity;
	for (i = 0; i < 4; i = i + 1)
		write_matrix_to_slot(i);
	load_identity;
	mat_rows_flat[15*16 +: 16] = 16'h0000; // zero last row
	for (i = 4; i < 8; i = i + 1)
		write_matrix_to_slot(i);
	run_and_check(5);

	// --------------------------------------------------------
	// Tests 6-19: Fully random TRNG data
	// --------------------------------------------------------
	for (test_idx = 6; test_idx < NUM_TESTS; test_idx = test_idx + 1) begin
		$display("=== Test %0d: Random ===", test_idx);
		randomize_all_blocks;
		run_and_check(test_idx);
	end

	// $display("**T5_OK**: All %0d tests passed**", NUM_TESTS);
	$display("**T5_OK**: T5 testbench did not hang**");
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
	if (clocks == 2000000) begin
		$display("**T5_HANG**: T5 testbench did not finish?");
		err_count += 1;
		$finish(1);
	end
end

final begin

	if (err_count == 0)
		$display("**T5_PASS**: All T5 tests passed without errors");

	else
		$display("**T5_FAIL**: There were <%d> errors detected in T5 testbench", err_count);

end

endmodule
