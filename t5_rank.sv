`default_nettype none

module t5_rank #(
  parameter int unsigned SMALLN = 2048,
  parameter int unsigned BIGM   = 128,
  parameter int unsigned Q      = 16
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              en,
  input  logic              start,
  input  logic [SMALLN-1:0] trng,

  output logic              done,     // 1-cycle pulse
  output logic              pass,     // 1-cycle pulse (same as done)
  output logic [31:0]       rfull,
  output logic [31:0]       rfullm1
);

  localparam int unsigned MATRIX_BITS       = Q*Q;
  localparam int unsigned NUM_MATRICES      = SMALLN / MATRIX_BITS;     // 8
  localparam int unsigned ROWS_PER_BLOCK    = BIGM / Q;                 // 8
  localparam int unsigned BLOCKS_PER_MATRIX = MATRIX_BITS / BIGM;       // 2

  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);
  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  // --- TRNG block extraction (matches your working comb version + TB)
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base      = SMALLN - (k+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // --- Working matrix (GF2 elimination modifies it)
  logic [Q-1:0] a [0:Q-1];

  // Capture regs for the two 128b blocks of one matrix
  logic [BIGM-1:0] blk_hi, blk_lo;

  // Per-matrix rank engine regs
  logic signed [$clog2(Q+1):0] col;         // signed so we can go <0
  logic [QW:0]                 pivot_row;   // 0..Q
  logic [QW:0]                 scan_row;    // 0..Q
  logic [QW-1:0]               sel_row;     // 0..Q-1
  logic                        found_pivot;
  logic [QW-1:0]               elim_row;    // 0..Q-1
  logic [QW:0]                 rank_reg;    // 0..Q

  // Matrix index + running counters
  logic [MW-1:0] m_idx;
  logic [31:0]   rfull_run, rfullm1_run;

  logic [Q-1:0] tmp_row;

  typedef enum logic [3:0] {
    S_IDLE    = 4'd0,
    S_CAP     = 4'd1,
    S_UNPACK  = 4'd2,

    S_INIT    = 4'd3,
    S_SCAN    = 4'd4,
    S_SWAP    = 4'd5,
    S_ELIM    = 4'd6,
    S_ADV     = 4'd7,

    S_ACCUM   = 4'd8,
    S_PUBLISH = 4'd9,   // <- outputs finalized here
    S_DONE    = 4'd10
  } state_t;

  state_t state, next_state;

  // done/pass pulses (ONE cycle, in S_DONE)
  always_comb begin
    done = (state == S_DONE);
    pass = (state == S_DONE);
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:    next_state = (en && start) ? S_CAP : S_IDLE;

      S_CAP:     next_state = S_UNPACK;
      S_UNPACK:  next_state = S_INIT;

      S_INIT:    next_state = S_SCAN;

      // Scan one row per cycle until scan_row==Q
      S_SCAN: begin
        if (pivot_row == Q || col < 0)
          next_state = S_ACCUM;
        else if (scan_row == Q)
          next_state = found_pivot ? S_SWAP : S_ADV;
        else
          next_state = S_SCAN;
      end

      S_SWAP:    next_state = S_ELIM;
      S_ELIM:    next_state = (elim_row == Q-1) ? S_ADV : S_ELIM;

      S_ADV:     next_state = S_SCAN;

      S_ACCUM:   next_state = (m_idx == (NUM_MATRICES-1)) ? S_PUBLISH : S_CAP;

      // publish stable outputs for wrapper to sample
      S_PUBLISH: next_state = S_DONE;

      // pulse done/pass once, then return idle when en drops
      S_DONE:    next_state = en ? S_DONE : S_IDLE;

      default:   next_state = S_IDLE;
    endcase
  end

  // Sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;

      // outputs
      rfull       <= 32'd0;
      rfullm1     <= 32'd0;

      // running
      rfull_run   <= 32'd0;
      rfullm1_run <= 32'd0;
      m_idx       <= '0;

      blk_hi      <= '0;
      blk_lo      <= '0;

      col         <= '0;
      pivot_row   <= '0;
      scan_row    <= '0;
      sel_row     <= '0;
      found_pivot <= 1'b0;
      elim_row    <= '0;
      rank_reg    <= '0;

      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;

      unique case (state)

        // -------------------- start new run
        S_IDLE: begin
          if (en && start) begin
            rfull_run   <= 32'd0;
            rfullm1_run <= 32'd0;
            m_idx       <= '0;
          end
        end

        // -------------------- capture matrix blocks
        S_CAP: begin
          blk_hi <= get_block(int'(m_idx)*BLOCKS_PER_MATRIX + 0);
          blk_lo <= get_block(int'(m_idx)*BLOCKS_PER_MATRIX + 1);
        end

        // -------------------- unpack into a[]
        S_UNPACK: begin
          for (int r = 0; r < int'(ROWS_PER_BLOCK); r++) begin
            a[r]                  <= blk_hi[(ROWS_PER_BLOCK-1-r)*Q +: Q];
            a[r + ROWS_PER_BLOCK] <= blk_lo[(ROWS_PER_BLOCK-1-r)*Q +: Q];
          end
        end

        // -------------------- init rank engine for this matrix
        S_INIT: begin
          rank_reg    <= '0;
          pivot_row   <= '0;
          col         <= $signed(int'(Q-1));

          // start scanning at pivot_row
          scan_row    <= '0;
          found_pivot <= 1'b0;
          sel_row     <= '0;
          elim_row    <= '0;
        end

        // -------------------- scan pivot (one row per cycle)
        S_SCAN: begin
          // when entering a fresh column scan, ensure scan_row starts at pivot_row
          if (scan_row == '0) begin
            scan_row    <= pivot_row;
            found_pivot <= 1'b0;
            sel_row     <= '0;
          end else if (scan_row < Q) begin
            if (!found_pivot && a[scan_row][int'(col)]) begin
              found_pivot <= 1'b1;
              sel_row     <= scan_row[QW-1:0];
            end
            scan_row <= scan_row + 1'b1;
          end
        end

        // -------------------- optional swap
        S_SWAP: begin
          if (sel_row != pivot_row[QW-1:0]) begin
            tmp_row               = a[pivot_row[QW-1:0]];
            a[pivot_row[QW-1:0]] <= a[sel_row];
            a[sel_row]           <= tmp_row;
          end
          elim_row <= '0;
        end

        // -------------------- eliminate (one row per cycle)
        S_ELIM: begin
          int er;
          er = int'(elim_row);

          if (er != int'(pivot_row)) begin
            if (a[er][int'(col)]) begin
              a[er] <= a[er] ^ a[pivot_row[QW-1:0]];
            end
          end

          if (elim_row != Q-1)
            elim_row <= elim_row + 1'b1;
        end

        // -------------------- advance to next column
        S_ADV: begin
          // if pivot existed in this column, accept it
          if (found_pivot) begin
            rank_reg  <= rank_reg + 1'b1;
            pivot_row <= pivot_row + 1'b1;
          end

          // move to next column
          col <= col - 1'sd1;

          // IMPORTANT: restart scan for next column on next S_SCAN
          scan_row    <= '0;      // sentinel meaning "fresh scan"
          found_pivot <= 1'b0;
          sel_row     <= '0;
        end

        // -------------------- accumulate this matrix’ rank into running counts
        S_ACCUM: begin
          if (rank_reg == Q)        rfull_run   <= rfull_run + 32'd1;
          else if (rank_reg == Q-1) rfullm1_run <= rfullm1_run + 32'd1;

          if (m_idx != (NUM_MATRICES-1))
            m_idx <= m_idx + 1'b1;
        end

        // -------------------- publish stable outputs for wrapper
        // wrapper samples sr_t5_rfull <= t5_rfull_w when t5_done=1.
        // We ensure outputs are ALREADY correct before we pulse done.
        S_PUBLISH: begin
          rfull   <= rfull_run;
          rfullm1 <= rfullm1_run;
        end

        S_DONE: begin
          // hold outputs stable here
        end

        default: ;
      endcase
    end
  end

endmodule