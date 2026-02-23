`default_nettype none

module trng_wrapper #(
  parameter int unsigned BUSW   = 32,
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned BIGN   = 16,
  parameter int unsigned K      = 5,
  parameter int unsigned Q      = 16,
  parameter int unsigned SMALLM = 9,
  parameter int unsigned LFSRL  = 9
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [SMALLN-1:0]     trng,
  input  logic [BUSW-1:0]       addr,
  input  logic [BUSW-1:0]       data_from_cpu,
  output logic [BUSW-1:0]       data_to_cpu,
  input  logic                  re,
  input  logic                  we
);

  // address
  logic [15:0] base_addr;
  logic        addr_is_base_reg;
  logic        addr_hit;
  logic [15:0] addr_offset;

  assign addr_is_base_reg = (addr == 32'h0000_0000);
  assign addr_hit = (!addr_is_base_reg) && (addr[31:16] == base_addr);
  assign addr_offset = addr[15:0];

  // SR
  // special address
  logic [31:0] sr_result;
  logic        sr_done;
  logic        start_pulse;
  
  // thresholds
  logic [31:0] sr_t1_diff_th;
  logic [31:0] sr_t2_c1hi_th;
  logic [31:0] sr_t2_c1lo_th;
  logic [31:0] sr_t3_lr_th;
  logic [31:0] sr_t4_chi_th;
  logic [31:0] sr_t7_hits_th;
  logic [31:0] sr_t8_hits_th;
  logic [31:0] sr_t78_template;
  logic [31:0] sr_t13_cth;
  
  // read
  logic [31:0] sr_t1_c1;
  logic [31:0] sr_t1_c0;
  logic [31:0] sr_t1_diff;
  
  logic [31:0] sr_t2_c1hi;
  logic [31:0] sr_t2_c1lo;
  
  logic [31:0] sr_t3_lr1;
  logic [31:0] sr_t3_lr0;
  logic [31:0] sr_t3_nr1;
  logic [31:0] sr_t3_nr0;
  
  logic [31:0] sr_t4_rlte4;
  logic [31:0] sr_t4_rof5;
  logic [31:0] sr_t4_rof6;
  logic [31:0] sr_t4_rof7;
  logic [31:0] sr_t4_rof8;
  logic [31:0] sr_t4_rgte9;
  
  logic [31:0] sr_t5_rfull;
  logic [31:0] sr_t5_rfullm1;
  
  logic [31:0] sr_t7_hits [0:15];
  
  logic [31:0] sr_t8_hits [0:15];
  
  logic [31:0] sr_t10_taps;
  logic [31:0] sr_t10_blockid;
  
  logic [31:0] sr_t13_chi;
  logic [31:0] sr_t13_clo;

  // fsm handshake
  logic t1_en,  t1_start,  t1_done,  t1_pass;
  logic t2_en,  t2_start,  t2_done,  t2_pass;
  logic t3_en,  t3_start,  t3_done,  t3_pass;
  logic t4_en,  t4_start,  t4_done,  t4_pass;
  logic t5_en,  t5_start,  t5_done,  t5_pass;
  logic t7_en,  t7_start,  t7_done,  t7_pass;
  logic t8_en,  t8_start,  t8_done,  t8_pass;
  logic t10_en, t10_start, t10_done, t10_pass;
  logic t13_en, t13_start, t13_done, t13_pass;

  // test case output
  logic [31:0] t1_c1_w, t1_c0_w, t1_diff_w;
  logic [31:0] t2_c1hi_w, t2_c1lo_w;
  logic [31:0] t3_lr1_w, t3_lr0_w, t3_nr1_w, t3_nr0_w;
  logic [31:0] t4_rlte4_w, t4_rof5_w, t4_rof6_w, t4_rof7_w, t4_rof8_w, t4_rgte9_w;
  logic [31:0] t5_rfull_w, t5_rfullm1_w;
  logic [31:0] t7_hits_w [0:15];
  logic [31:0] t8_hits_w [0:15];
  logic [31:0] t10_taps_w, t10_blockid_w;
  logic [31:0] t13_chi_w, t13_clo_w;

  // start: detect CPU write to START_READY with valid value
  localparam logic [15:0] OFF_START_READY = 16'h0001;
  always_comb begin
    start_pulse = 1'b0;
    if (we) begin
      if (addr_hit && (addr_offset == OFF_START_READY)) begin
        if ((data_from_cpu != 32'h0000_0000) && (data_from_cpu != 32'hFFFF_FFFF))
          start_pulse = 1'b1;      
      end
    end
  end

  // write SR
  // W thresholds/config
  localparam logic [15:0] OFF_T1_DIFF_TH    = 16'h0007;
  localparam logic [15:0] OFF_T2_C1HI_TH    = 16'h000B;
  localparam logic [15:0] OFF_T2_C1LO_TH    = 16'h000C;
  localparam logic [15:0] OFF_T3_LR_TH      = 16'h0012;
  localparam logic [15:0] OFF_T4_CHI_TH     = 16'h001A;
  localparam logic [15:0] OFF_T7_HITS_TH    = 16'h0030;
  localparam logic [15:0] OFF_T8_HITS_TH    = 16'h0043;
  localparam logic [15:0] OFF_T78_TEMPLATE  = 16'h0045;
  localparam logic [15:0] OFF_T13_CTH       = 16'h004C;

  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      base_addr        <= 16'h0000;

      // thresholds/config
      sr_t1_diff_th    <= 32'h0;
      sr_t2_c1hi_th    <= 32'h0;
      sr_t2_c1lo_th    <= 32'h0;
      sr_t3_lr_th      <= 32'h0;
      sr_t4_chi_th     <= 32'h0;
      sr_t7_hits_th    <= 32'h0;
      sr_t8_hits_th    <= 32'h0;
      sr_t78_template  <= 32'h0;
      sr_t13_cth       <= 32'h0;

      // read-only counters/results
      sr_t1_c1         <= 32'h0;
      sr_t1_c0         <= 32'h0;
      sr_t1_diff       <= 32'h0;

      sr_t2_c1hi        <= 32'h0;
      sr_t2_c1lo        <= 32'h0;

      sr_t3_lr1         <= 32'h0;
      sr_t3_lr0         <= 32'h0;
      sr_t3_nr1         <= 32'h0;
      sr_t3_nr0         <= 32'h0;

      sr_t4_rlte4       <= 32'h0;
      sr_t4_rof5        <= 32'h0;
      sr_t4_rof6        <= 32'h0;
      sr_t4_rof7        <= 32'h0;
      sr_t4_rof8        <= 32'h0;
      sr_t4_rgte9       <= 32'h0;

      sr_t5_rfull       <= 32'h0;
      sr_t5_rfullm1     <= 32'h0;

      for (i = 0; i < 16; i++) begin
        sr_t7_hits[i]   <= 32'h0;
        sr_t8_hits[i]   <= 32'h0;
      end

      sr_t10_taps       <= 32'h0;
      sr_t10_blockid    <= 32'h0;

      sr_t13_chi        <= 32'h0;
      sr_t13_clo        <= 32'h0;

    end else begin
      // write base address
      if (we && addr_is_base_reg) begin
        base_addr <= data_from_cpu[15:0];
      end

      // write SR
      if (we && addr_hit) begin
        unique case (addr_offset)
          // write threshold/config
          OFF_T1_DIFF_TH:   sr_t1_diff_th   <= data_from_cpu;
          OFF_T2_C1HI_TH:   sr_t2_c1hi_th   <= data_from_cpu;
          OFF_T2_C1LO_TH:   sr_t2_c1lo_th   <= data_from_cpu;
          OFF_T3_LR_TH:     sr_t3_lr_th     <= data_from_cpu;
          OFF_T4_CHI_TH:    sr_t4_chi_th    <= data_from_cpu;
          OFF_T7_HITS_TH:   sr_t7_hits_th   <= data_from_cpu;
          OFF_T8_HITS_TH:   sr_t8_hits_th   <= data_from_cpu;
          OFF_T78_TEMPLATE: sr_t78_template <= {{(32-SMALLM){1'b0}}, data_from_cpu[SMALLM-1:0]};
          OFF_T13_CTH:      sr_t13_cth      <= data_from_cpu;

          default: begin
            // ignore write to unused or read-only addresses
          end
        endcase
      end

      if (t1_done) begin
        sr_t1_c1   <= t1_c1_w;
        sr_t1_c0   <= t1_c0_w;
        sr_t1_diff <= t1_diff_w;
      end
      
      if (t2_done) begin
        sr_t2_c1hi <= t2_c1hi_w;
        sr_t2_c1lo <= t2_c1lo_w;
      end
      
      if (t3_done) begin
        sr_t3_lr1 <= t3_lr1_w;
        sr_t3_lr0 <= t3_lr0_w;
        sr_t3_nr1 <= t3_nr1_w;
        sr_t3_nr0 <= t3_nr0_w;
      end
      
      if (t4_done) begin
        sr_t4_rlte4 <= t4_rlte4_w;
        sr_t4_rof5  <= t4_rof5_w;
        sr_t4_rof6  <= t4_rof6_w;
        sr_t4_rof7  <= t4_rof7_w;
        sr_t4_rof8  <= t4_rof8_w;
        sr_t4_rgte9 <= t4_rgte9_w;
      end
      
      if (t5_done) begin
        sr_t5_rfull   <= t5_rfull_w;
        sr_t5_rfullm1 <= t5_rfullm1_w;
      end
      
      if (t7_done) begin
        for (i = 0; i < 16; i++) sr_t7_hits[i] <= t7_hits_w[i];
      end
      
      if (t8_done) begin
        for (i = 0; i < 16; i++) sr_t8_hits[i] <= t8_hits_w[i];
      end
      
      if (t10_done) begin
        sr_t10_taps    <= t10_taps_w;
        sr_t10_blockid <= t10_blockid_w;
      end
      
      if (t13_done) begin
        sr_t13_chi <= t13_chi_w;
        sr_t13_clo <= t13_clo_w;
      end
    end
  end

  // read: write only reg read 0
  always_comb begin
    data_to_cpu = 32'h0;

    if (re) begin
      // SR_BASE_ADDR is always at absolute address 0x0000_0000
      if (addr_is_base_reg) begin
        data_to_cpu = {16'h0, base_addr};

      end else if (addr_hit) begin
        unique case (addr_offset)

          // Special regs
          OFF_START_READY: data_to_cpu = (sr_done ? 32'hFFFF_FFFF : 32'h0);
          16'h0002:        data_to_cpu = sr_result;

          // T1
          16'h0004:        data_to_cpu = sr_t1_c1;
          16'h0005:        data_to_cpu = sr_t1_c0;
          16'h0006:        data_to_cpu = sr_t1_diff;

          // T2
          16'h0009:        data_to_cpu = sr_t2_c1hi;
          16'h000A:        data_to_cpu = sr_t2_c1lo;

          // T3
          16'h000E:        data_to_cpu = sr_t3_lr1;
          16'h000F:        data_to_cpu = sr_t3_lr0;
          16'h0010:        data_to_cpu = sr_t3_nr1;
          16'h0011:        data_to_cpu = sr_t3_nr0;

          // T4
          16'h0014:        data_to_cpu = sr_t4_rlte4;
          16'h0015:        data_to_cpu = sr_t4_rof5;
          16'h0016:        data_to_cpu = sr_t4_rof6;
          16'h0017:        data_to_cpu = sr_t4_rof7;
          16'h0018:        data_to_cpu = sr_t4_rof8;
          16'h0019:        data_to_cpu = sr_t4_rgte9;

          // T5
          16'h001C:        data_to_cpu = sr_t5_rfull;
          16'h001D:        data_to_cpu = sr_t5_rfullm1;

          // T7
          16'h001F:        data_to_cpu = sr_t7_hits[0];
          16'h0020:        data_to_cpu = sr_t7_hits[1];
          16'h0021:        data_to_cpu = sr_t7_hits[2];
          16'h0022:        data_to_cpu = sr_t7_hits[3];
          16'h0023:        data_to_cpu = sr_t7_hits[4];
          16'h0024:        data_to_cpu = sr_t7_hits[5];
          16'h0025:        data_to_cpu = sr_t7_hits[6];
          16'h0026:        data_to_cpu = sr_t7_hits[7];
          16'h0027:        data_to_cpu = sr_t7_hits[8];
          16'h0028:        data_to_cpu = sr_t7_hits[9];
          16'h0029:        data_to_cpu = sr_t7_hits[10];
          16'h002A:        data_to_cpu = sr_t7_hits[11];
          16'h002B:        data_to_cpu = sr_t7_hits[12];
          16'h002C:        data_to_cpu = sr_t7_hits[13];
          16'h002D:        data_to_cpu = sr_t7_hits[14];
          16'h002E:        data_to_cpu = sr_t7_hits[15];

          // T8
          16'h0032:        data_to_cpu = sr_t8_hits[0];
          16'h0033:        data_to_cpu = sr_t8_hits[1];
          16'h0034:        data_to_cpu = sr_t8_hits[2];
          16'h0035:        data_to_cpu = sr_t8_hits[3];
          16'h0036:        data_to_cpu = sr_t8_hits[4];
          16'h0037:        data_to_cpu = sr_t8_hits[5];
          16'h0038:        data_to_cpu = sr_t8_hits[6];
          16'h0039:        data_to_cpu = sr_t8_hits[7];
          16'h003A:        data_to_cpu = sr_t8_hits[8];
          16'h003B:        data_to_cpu = sr_t8_hits[9];
          16'h003C:        data_to_cpu = sr_t8_hits[10];
          16'h003D:        data_to_cpu = sr_t8_hits[11];
          16'h003E:        data_to_cpu = sr_t8_hits[12];
          16'h003F:        data_to_cpu = sr_t8_hits[13];
          16'h0040:        data_to_cpu = sr_t8_hits[14];
          16'h0041:        data_to_cpu = sr_t8_hits[15];

          // T10
          16'h0047:        data_to_cpu = sr_t10_taps;
          16'h0048:        data_to_cpu = sr_t10_blockid;

          // T13
          16'h004A:        data_to_cpu = sr_t13_chi;
          16'h004B:        data_to_cpu = sr_t13_clo;

          default: data_to_cpu = 32'h0;
        endcase
      end
    end
  end

  // test FSM
  enum logic [5:0] {
    IDLE,
    T1_ENTRY,  T1_RUN,
    T2_ENTRY,  T2_RUN,
    T3_ENTRY,  T3_RUN,
    T4_ENTRY,  T4_RUN,
    T5_ENTRY,  T5_RUN,
    T7_ENTRY,  T7_RUN,
    T8_ENTRY,  T8_RUN,
    T10_ENTRY, T10_RUN,
    T13_ENTRY, T13_RUN,
    DONE
  } state, next_state;

  // test cases
  t1_frequency #(.N(SMALLN)) u_t1 (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (t1_en),
    .start   (t1_start),
    .trng    (trng),
    .diff_th (sr_t1_diff_th),
    .done    (t1_done),
    .pass    (t1_pass),
    .c1      (t1_c1_w),
    .c0      (t1_c0_w),
    .diff    (t1_diff_w)
  );

  t2_frequency #(.N(SMALLN)) u_t2 (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (t2_en),
    .start   (t2_start),
    .trng    (trng),
    .c1hi_th (sr_t2_c1hi_th),
    .c1lo_th (sr_t2_c1lo_th),
    .done    (t2_done),
    .pass    (t2_pass),
    .c1hi    (t2_c1hi_w),
    .c1lo    (t2_c1lo_w)
  );

  t3_runs #(.N(SMALLN)) u_t3 (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t3_en),
    .start (t3_start),
    .trng  (trng),
    .lr_th (sr_t3_lr_th),
    .done  (t3_done),
    .pass  (t3_pass),
    .lr1   (t3_lr1_w),
    .lr0   (t3_lr0_w),
    .nr1   (t3_nr1_w),
    .nr0   (t3_nr0_w)
  );

  t4_longrun #(.N(SMALLN)) u_t4 (
    .clk    (clk),
    .rst_n  (rst_n),
    .en     (t4_en),
    .start  (t4_start),
    .trng   (trng),
    .chi_th (sr_t4_chi_th),
    .done   (t4_done),
    .pass   (t4_pass),
    .rlte4  (t4_rlte4_w),
    .rof5   (t4_rof5_w),
    .rof6   (t4_rof6_w),
    .rof7   (t4_rof7_w),
    .rof8   (t4_rof8_w),
    .rgte9  (t4_rgte9_w)
  );

  t5_rank #(.N(SMALLN), .M(BIGM)) u_t5 (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (t5_en),
    .start   (t5_start),
    .trng    (trng),
    .done    (t5_done),
    .pass    (t5_pass),
    .rfull   (t5_rfull_w),
    .rfullm1 (t5_rfullm1_w)
  );

  t7_template_hits #(.N(SMALLN), .M(SMALLM)) u_t7 (
    .clk           (clk),
    .rst_n         (rst_n),
    .en            (t7_en),
    .start         (t7_start),
    .trng          (trng),
    .hits_th       (sr_t7_hits_th),
    .template_bits (sr_t78_template[SMALLM-1:0]),
    .done          (t7_done),
    .pass          (t7_pass),
    .hits          (t7_hits_w)
  );

  t8_template_hits #(.N(SMALLN), .M(SMALLM)) u_t8 (
    .clk           (clk),
    .rst_n         (rst_n),
    .en            (t8_en),
    .start         (t8_start),
    .trng          (trng),
    .hits_th       (sr_t8_hits_th),
    .template_bits (sr_t78_template[SMALLM-1:0]),
    .done          (t8_done),
    .pass          (t8_pass),
    .hits          (t8_hits_w)
  );

  t10_taps #(.N(SMALLN), .L(LFSRL)) u_t10 (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (t10_en),
    .start   (t10_start),
    .trng    (trng),
    .done    (t10_done),
    .pass    (t10_pass),
    .taps    (t10_taps_w),
    .blockid (t10_blockid_w)
  );

  t13_chi2 #(.N(SMALLN)) u_t13 (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (t13_en),
    .start (t13_start),
    .trng  (trng),
    .cth   (sr_t13_cth),
    .done  (t13_done),
    .pass  (t13_pass),
    .chi   (t13_chi_w),
    .clo   (t13_clo_w)
  );

  // state register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // output logic
  always_comb begin
    // defaults (IMPORTANT to avoid inferred latches)
    t1_en=0;  t1_start=0;
    t2_en=0;  t2_start=0;
    t3_en=0;  t3_start=0;
    t4_en=0;  t4_start=0;
    t5_en=0;  t5_start=0;
    t7_en=0;  t7_start=0;
    t8_en=0;  t8_start=0;
    t10_en=0; t10_start=0;
    t13_en=0; t13_start=0;
  
    unique case (state)
      // IDLE/DONE: nothing enabled
      IDLE: begin end
      DONE: begin end
  
      // Each test is enabled during ENTRY + RUN, and start pulses only in ENTRY
      T1_ENTRY:  begin t1_en=1;  t1_start=1;  end
      T1_RUN:    begin t1_en=1;               end
  
      T2_ENTRY:  begin t2_en=1;  t2_start=1;  end
      T2_RUN:    begin t2_en=1;               end
  
      T3_ENTRY:  begin t3_en=1;  t3_start=1;  end
      T3_RUN:    begin t3_en=1;               end
  
      T4_ENTRY:  begin t4_en=1;  t4_start=1;  end
      T4_RUN:    begin t4_en=1;               end
  
      T5_ENTRY:  begin t5_en=1;  t5_start=1;  end
      T5_RUN:    begin t5_en=1;               end
  
      T7_ENTRY:  begin t7_en=1;  t7_start=1;  end
      T7_RUN:    begin t7_en=1;               end
  
      T8_ENTRY:  begin t8_en=1;  t8_start=1;  end
      T8_RUN:    begin t8_en=1;               end
  
      T10_ENTRY: begin t10_en=1; t10_start=1; end
      T10_RUN:   begin t10_en=1;              end
  
      T13_ENTRY: begin t13_en=1; t13_start=1; end
      T13_RUN:   begin t13_en=1;              end
  
      default: begin end
    endcase
  end

  // next state logic
  always_comb begin
    next_state = state;

    unique case (state)
      IDLE: begin
        if (start_pulse) next_state = T1_ENTRY;
      end

      // ENTRY states are always 1-cycle
      T1_ENTRY:  next_state = T1_RUN;
      T2_ENTRY:  next_state = T2_RUN;
      T3_ENTRY:  next_state = T3_RUN;
      T4_ENTRY:  next_state = T4_RUN;
      T5_ENTRY:  next_state = T5_RUN;
      T7_ENTRY:  next_state = T7_RUN;
      T8_ENTRY:  next_state = T8_RUN;
      T10_ENTRY: next_state = T10_RUN;
      T13_ENTRY: next_state = T13_RUN;

      // RUN states wait for done, then branch on pass/fail
      T1_RUN: begin
        if (t1_done) next_state = (t1_pass ? T2_ENTRY : DONE);
      end

      T2_RUN: begin
        if (t2_done) next_state = (t2_pass ? T3_ENTRY : DONE);
      end

      T3_RUN: begin
        if (t3_done) next_state = (t3_pass ? T4_ENTRY : DONE);
      end

      T4_RUN: begin
        if (t4_done) next_state = (t4_pass ? T5_ENTRY : DONE);
      end

      // Spec notes T5 always PASS (rank test returns counts); you can hardwire t5_pass=1
      // but keeping the branch makes the FSM uniform.
      T5_RUN: begin
        if (t5_done) next_state = (t5_pass ? T7_ENTRY : DONE);
      end

      T7_RUN: begin
        if (t7_done) next_state = (t7_pass ? T8_ENTRY : DONE);
      end

      T8_RUN: begin
        if (t8_done) next_state = (t8_pass ? T10_ENTRY : DONE);
      end

      T10_RUN: begin
        if (t10_done) next_state = (t10_pass ? T13_ENTRY : DONE);
      end

      T13_RUN: begin
        if (t13_done) next_state = DONE; // last test
      end

      DONE: begin
        // Stay done until a new start request
        if (start_pulse) next_state = T1_ENTRY;
      end

      default: next_state = IDLE;
    endcase
  end

  // sr_done
  logic sr_done_d, sr_done_q, sr_done_we;
  assign sr_done = sr_done_q;
  register #(1) SR_done_reg (.clock(clk), .reset_n(rst_n), .D(sr_done_d), 
            .en(sr_done_we), .Q(sr_done_q));
  always_comb begin
    if (start_pulse) begin
      sr_done_d  = 1'b0;
      sr_done_we = 1'b1;
    end else if (state == DONE) begin
      sr_done_d  = 1'b1;
      sr_done_we = 1'b1;
    end else begin
      sr_done_d  = sr_done_q;
      sr_done_we = 1'b0;
    end
  end

  // sr_result
  logic [31:0] sr_result_d, sr_result_q;
  logic        sr_result_we;
  assign sr_result = sr_result_q;
  register #(32) SR_result_reg (.clock(clk), .reset_n(rst_n), .D(sr_result_d),
            .en(sr_result_we), .Q(sr_result_q));
  always_comb begin
    logic [31:0] set_mask;
    set_mask =
        ((t1_done  && t1_pass)  ? (32'h1 << 1)  : 32'h0) |
        ((t2_done  && t2_pass)  ? (32'h1 << 2)  : 32'h0) |
        ((t3_done  && t3_pass)  ? (32'h1 << 3)  : 32'h0) |
        ((t4_done  && t4_pass)  ? (32'h1 << 4)  : 32'h0) |
        ((t5_done  && t5_pass)  ? (32'h1 << 5)  : 32'h0) |
        ((t7_done  && t7_pass)  ? (32'h1 << 7)  : 32'h0) |
        ((t8_done  && t8_pass)  ? (32'h1 << 8)  : 32'h0) |
        ((t10_done && t10_pass) ? (32'h1 << 10) : 32'h0) |
        ((t13_done && t13_pass) ? (32'h1 << 13) : 32'h0);

    if (start_pulse) begin
      sr_result_d  = 32'h0;
      sr_result_we = 1'b1;
    end else if (set_mask != 32'h0) begin
      sr_result_d  = sr_result_q | set_mask;
      sr_result_we = 1'b1;
    end else begin
      sr_result_d  = sr_result_q;
      sr_result_we = 1'b0;
    end
  end
endmodule