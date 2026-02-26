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

  output logic              done,
  output logic              pass,
  output logic [31:0]       rfull,
  output logic [31:0]       rfullm1
);

  // --------------------------------------------
  // Derived constants (match TB assumptions)
  // --------------------------------------------
  localparam int unsigned MATRIX_BITS       = Q * Q;              // 256
  localparam int unsigned NUM_MATRICES      = SMALLN / MATRIX_BITS; // 8
  localparam int unsigned ROWS_PER_BLOCK    = BIGM / Q;           // 128/16 = 8
  localparam int unsigned BLOCKS_PER_MATRIX = MATRIX_BITS / BIGM; // 256/128 = 2

  localparam int unsigned MW = (NUM_MATRICES <= 1) ? 1 : $clog2(NUM_MATRICES);

  // --------------------------------------------
  // Block extraction (MUST match your working code)
  // NOTE: k=0 returns trng[SMALLN-1 -: BIGM] (top block)
  // --------------------------------------------
  function automatic logic [BIGM-1:0] get_block(input int unsigned k);
    logic [31:0] base;
    begin
      base      = SMALLN - (k+1)*BIGM;
      get_block = trng[base +: BIGM];
    end
  endfunction

  // --------------------------------------------
  // Matrix buffer: 16 rows of 16b, registered
  // --------------------------------------------
  logic [Q-1:0] rows_buf [0:Q-1];

  // --------------------------------------------
  // GF2 core interface
  // --------------------------------------------
  logic        gf2_start;
  logic        gf2_done;
  logic [31:0] gf2_rank;

  gf2_rank_q #(.Q(Q)) u_gf2 (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (gf2_start),
    .rows_in (rows_buf),
    .rank    (gf2_rank),
    .done    (gf2_done)
  );

  // --------------------------------------------
  // FSM
  // --------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_LOAD,     // load rows_buf from trng blocks
    S_LAUNCH,   // pulse gf2_start
    S_WAIT,     // wait gf2_done
    S_ACCUM,    // update rfull/rfullm1, bump matrix index
    S_DONE
  } state_t;

  state_t state, next_state;

  logic [MW-1:0] m_idx;

  // next-state
  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:   next_state = (en && start) ? S_LOAD   : S_IDLE;
      S_LOAD:   next_state = S_LAUNCH;
      S_LAUNCH: next_state = S_WAIT;
      S_WAIT:   next_state = gf2_done ? S_ACCUM : S_WAIT;
      S_ACCUM:  next_state = (m_idx == (NUM_MATRICES-1)) ? S_DONE : S_LOAD;
      S_DONE:   next_state = en ? S_DONE : S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  // outputs
  assign done = (state == S_DONE);
  assign pass = (state == S_DONE); // per lab: T5 always "passes" once computed

  // sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      m_idx     <= '0;
      rfull     <= 32'd0;
      rfullm1   <= 32'd0;
      gf2_start <= 1'b0;

      for (int r = 0; r < Q; r++) rows_buf[r] <= '0;

    end else begin
      state <= next_state;

      // default: 1-cycle start pulse
      gf2_start <= 1'b0;

      unique case (state)
        S_IDLE: begin
          if (en && start) begin
            m_idx   <= '0;
            rfull   <= 32'd0;
            rfullm1 <= 32'd0;
          end
        end

        // Load one 16x16 matrix into rows_buf
        // EXACT same unpacking as your working code:
        // - matrix m uses blocks (m*2) and (m*2+1)
        // - within each 128b block, row0 comes from MSB 16 bits, etc
        S_LOAD: begin
          logic [BIGM-1:0] blk_hi, blk_lo;

          blk_hi = get_block(int'(m_idx) * BLOCKS_PER_MATRIX + 0);
          blk_lo = get_block(int'(m_idx) * BLOCKS_PER_MATRIX + 1);

          for (int r = 0; r < int'(ROWS_PER_BLOCK); r++) begin
            rows_buf[r]                 <= blk_hi[(ROWS_PER_BLOCK-1-r)*Q +: Q];
            rows_buf[r + ROWS_PER_BLOCK]<= blk_lo[(ROWS_PER_BLOCK-1-r)*Q +: Q];
          end
        end

        S_LAUNCH: begin
          gf2_start <= 1'b1;
        end

        S_ACCUM: begin
          if (gf2_rank == Q)        rfull   <= rfull + 32'd1;
          else if (gf2_rank == Q-1) rfullm1 <= rfullm1 + 32'd1;

          if (m_idx != (NUM_MATRICES-1))
            m_idx <= m_idx + 1'b1;
        end

        default: begin end
      endcase
    end
  end

endmodule


// ============================================================
// Multi-cycle GF(2) rank engine for QxQ (Q=16)
// - start: 1-cycle pulse
// - done : 1-cycle pulse when rank valid
// - per-cycle work: small (swap mux + optional 16-bit XOR for one row)
// ============================================================
module gf2_rank_q #(
  parameter int unsigned Q = 16
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start,
  input  logic [Q-1:0] rows_in [0:Q-1],

  output logic [31:0]  rank,
  output logic         done
);

  localparam int unsigned QW = (Q <= 1) ? 1 : $clog2(Q);

  logic [Q-1:0] a [0:Q-1];

  typedef enum logic [2:0] {
    S_IDLE,
    S_LOAD,
    S_PIVOT,   // decide pivot for current column (combinational search)
    S_SWAP,
    S_ELIM,    // eliminate one row per cycle
    S_NEXT,
    S_DONE
  } state_t;

  state_t state, next_state;

  logic signed [$clog2(Q+1):0] col;       // Q-1 downto -1
  logic [QW:0]                 pivot_row; // 0..Q
  logic [QW-1:0]               elim_row;  // 0..Q-1

  // combinational pivot finder (tiny for Q=16)
  logic          found_pivot;
  logic [QW-1:0] sel_row;

  always_comb begin
    found_pivot = 1'b0;
    sel_row     = '0;

    if (col >= 0 && pivot_row < Q) begin
      for (int r = 0; r < Q; r++) begin
        if (!found_pivot &&
            (r >= int'(pivot_row)) &&
            a[r][int'(col)]) begin
          found_pivot = 1'b1;
          sel_row     = r[QW-1:0];
        end
      end
    end
  end

  // next-state
  always_comb begin
    next_state = state;
    unique case (state)
      S_IDLE:  next_state = start ? S_LOAD : S_IDLE;
      S_LOAD:  next_state = S_PIVOT;

      S_PIVOT: begin
        if (col < 0 || pivot_row == Q) next_state = S_DONE;
        else if (found_pivot)          next_state = S_SWAP;
        else                           next_state = S_NEXT;
      end

      S_SWAP:  next_state = S_ELIM;
      S_ELIM:  next_state = (elim_row == Q-1) ? S_NEXT : S_ELIM;
      S_NEXT:  next_state = S_PIVOT;
      S_DONE:  next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      rank      <= 32'd0;
      done      <= 1'b0;
      col       <= '0;
      pivot_row <= '0;
      elim_row  <= '0;
      for (int r = 0; r < Q; r++) a[r] <= '0;

    end else begin
      state <= next_state;
      done  <= 1'b0; // pulse

      unique case (state)
        S_IDLE: begin
          if (start) begin
            rank      <= 32'd0;
            pivot_row <= '0;
            col       <= $signed(int'(Q-1));
          end
        end

        S_LOAD: begin
          for (int r = 0; r < Q; r++) a[r] <= rows_in[r];
        end

        S_SWAP: begin
          if (sel_row != pivot_row[QW-1:0]) begin
            logic [Q-1:0] tmp;
            tmp                   = a[pivot_row[QW-1:0]];
            a[pivot_row[QW-1:0]] <= a[sel_row];
            a[sel_row]           <= tmp;
          end
          elim_row <= '0;
        end

        S_ELIM: begin
          int er;
          er = int'(elim_row);

          if (er != int'(pivot_row)) begin
            if (a[er][int'(col)]) begin
              a[er] <= a[er] ^ a[pivot_row[QW-1:0]];
            end
          end

          if (elim_row != Q-1) elim_row <= elim_row + 1'b1;
        end

        S_NEXT: begin
          if (found_pivot) begin
            rank      <= rank + 32'd1;
            pivot_row <= pivot_row + 1'b1;
          end
          col <= col - 1'sd1;
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin end
      endcase
    end
  end

endmodule