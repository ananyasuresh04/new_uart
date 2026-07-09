// =============================================================================
// tsr_controler.sv  – Fully integrated (PISO + parity + stop_gen inlined)
//
// tx_out is driven combinationally then registered (see tx_next/tx_out below)
// so it is glitch-free and never shows X after reset.
//
// stop_bit / stop_done are fully internal (no ports).
//
// NEW: mdr input selects the per-state baud duration:
//   mdr = 1  -> "normal" mode (unchanged from before):
//                 every non-STOP state stays 16 clocks
//                 STOP stays 16 / 24 / 32 clocks depending on stb / wls
//   mdr = 0  -> "fast" mode:
//                 every non-STOP state stays 13 clocks
//                 STOP stays 13 / 19 / 26 clocks depending on stb / wls
//                   stb=0            -> 13  (same as the base baud count)
//                   stb=1, wls==00   -> 19
//                   stb=1, wls!=00   -> 26
// =============================================================================

module tsr_controler #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,

    // Frame configuration
    input  logic [WIDTH-1:0] data_in,   // parallel data to transmit
    input  logic [1:0]       wls,       // 00=5bit 01=6bit 10=7bit 11=8bit
    input  logic             stb,       // stop bit config
    input  logic             pen,       // parity enable
    input  logic             eps,       // even parity select
    input  logic             sp,        // stick parity
    input  logic             mdr,       // 1 = 16-cycle baud, 0 = 13-cycle baud

    // Break control
    input  logic             bc,        // 1 = force tx_out LOW (break condition)

    // Handshake
    input  logic             tsr_empty, // LOW = data available to send

    // Outputs
    output logic             tx_out,    // serial transmit line (UART TX)
    output logic             tsr_ready, // HIGH while frame is being sent
    output logic             tsr_shift1  // TSR shift enable
);

    // =========================================================================
    // 2-FF synchronizer for tsr_empty
    // =========================================================================
    logic tsr_empty_s1, tsr_empty_sync;
logic             tsr_shift;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tsr_empty_s1   <= 1'b1;
            tsr_empty_sync <= 1'b1;
        end else begin
            tsr_empty_s1   <= tsr_empty;
            tsr_empty_sync <= tsr_empty_s1;
        end
    end

    // =========================================================================
    // FSM State Encoding
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE   = 3'd0,
        WAIT1  = 3'd1,
        START  = 3'd2,
        DATA   = 3'd3,
        PARITY = 3'd4,
        STOP   = 3'd5
    } state_t;

    state_t present_state, next_state;

    // =========================================================================
    // baud_cycles – the per-state duration, selected by mdr
    //   mdr=1 -> 16 clocks   mdr=0 -> 13 clocks
    // baud_cnt counts 0 .. (baud_cycles-1) and resets every state change.
    // =========================================================================
    logic [4:0] baud_cycles;
    logic [3:0] baud_cnt;
    logic       baud_last;

    assign baud_cycles = !mdr ? 5'd16 : 5'd13;
    assign baud_last   = (baud_cnt == baud_cycles[3:0] - 4'd1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 4'd0;
        end else begin
            if (present_state == IDLE)
                baud_cnt <= 4'd0;
            else if (baud_last)
                baud_cnt <= 4'd0;   // reset every time a baud period completes -
                                    // covers both state transitions AND the
                                    // bit-to-bit boundaries *within* DATA,
                                    // where present_state does not change but
                                    // a new baud period still begins
            else
                baud_cnt <= baud_cnt + 4'd1;
        end
    end

    // =========================================================================
    // DATA bit counter
    // =========================================================================
    logic [2:0] max_bit;
    logic [2:0] bit_idx;
    logic       data_done;

    always_comb begin
        case (wls)
            2'b00:   max_bit = 3'd4;
            2'b01:   max_bit = 3'd5;
            2'b10:   max_bit = 3'd6;
            2'b11:   max_bit = 3'd7;
            default: max_bit = 3'd7;
        endcase
    end

    assign data_done = (present_state == DATA) && (bit_idx == max_bit) && baud_last;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_idx <= 3'd0;
        else begin
            if (present_state == DATA) begin
                if (baud_last)
                    bit_idx <= bit_idx + 3'd1;
            end else
                bit_idx <= 3'd0;
        end
    end

    // =========================================================================
    // PISO – inlined
    // shift_reg loaded every clock during START (piso_load = combinational).
    // Shifts right (LSB first) on every baud_last in DATA.
    // =========================================================================
    logic             piso_load;
    logic             piso_shift;
    logic [WIDTH-1:0] shift_reg;
    logic             serial_out;

    assign piso_load  = (present_state == START);
    assign piso_shift = (present_state == DATA) && baud_last;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= {WIDTH{1'b0}};
        else begin
            if (piso_load)
                shift_reg <= data_in;
            else if (piso_shift)
                shift_reg <= {1'b0, shift_reg[WIDTH-1:1]};
        end
    end

    assign serial_out = shift_reg[0];

    // =========================================================================
    // Parity – inlined (identical logic to parity.sv, unchanged)
    // =========================================================================
    logic [WIDTH-1:0] masked_data;
    logic             xor_all;
    logic             parity_comb;
    logic             parity_reg;
    logic             parity_load_en;

    always_comb begin
        case (wls)
            2'b00:   masked_data = {{3{1'b0}}, data_in[4:0]};
            2'b01:   masked_data = {{2{1'b0}}, data_in[5:0]};
            2'b10:   masked_data = { 1'b0,     data_in[6:0]};
            2'b11:   masked_data =             data_in[7:0];
            default: masked_data = {WIDTH{1'b0}};
        endcase
    end

    assign xor_all = ^masked_data;

    always_comb begin
        case ({sp, eps, pen})
            3'b000, 3'b010,
            3'b100, 3'b110: parity_comb = 1'b0;
            3'b001:          parity_comb = ~xor_all;   // odd
            3'b011:          parity_comb =  xor_all;   // even
            3'b101:          parity_comb = 1'b1;        // stick SET
            3'b111:          parity_comb = 1'b0;        // stick CLEAR
            default:         parity_comb = 1'b0;
        endcase
    end

    assign parity_load_en = data_done && pen;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parity_reg <= 1'b0;
        else if (parity_load_en)
            parity_reg <= parity_comb;
    end

    // =========================================================================
    // STOP duration – fully internal, selected by mdr
    //
    //   mdr=1 (16-cycle baud):
    //     stb=0  any wls  ? 16
    //     stb=1  wls==00  ? 24
    //     stb=1  wls!=00  ? 32
    //
    //   mdr=0 (13-cycle baud):
    //     stb=0  any wls  ? 13
    //     stb=1  wls==00  ? 19
    //     stb=1  wls!=00  ? 26
    // =========================================================================
    logic [5:0] stop_cycles;
    logic [5:0] stop_cnt;
    logic       in_stop;
    logic       stop_done_i;

    assign in_stop = (present_state == STOP);

    always_comb begin
        if (!mdr) begin
            // 16-cycle baud mode
            if (!stb)
                stop_cycles = 6'd16;
            else if (wls == 2'b00)
                stop_cycles = 6'd24;
            else
                stop_cycles = 6'd32;
        end else begin
            // 13-cycle baud mode
            if (!stb)
                stop_cycles = 6'd13;
            else if (wls == 2'b00)
                stop_cycles = 6'd19;
            else
                stop_cycles = 6'd26;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stop_cnt <= 6'd0;
        else begin
            if (in_stop)
                stop_cnt <= stop_cnt + 6'd1;
            else
                stop_cnt <= 6'd0;
        end
    end

    assign stop_done_i = in_stop && (stop_cnt == (stop_cycles - 6'd1));

    // =========================================================================
    // Present-state register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            present_state <= IDLE;
        else
            present_state <= next_state;
    end

    // =========================================================================
    // Next-state logic
    // =========================================================================
    always_comb begin
        next_state = present_state;

        if (bc) begin
            // Break condition: force the FSM into IDLE and hold it there
            // for as long as bc stays asserted. Normal sequencing resumes
            // automatically (from IDLE) once bc is released.
            next_state = IDLE;
        end else begin
            case (present_state)
                IDLE:   if (!tsr_empty_sync)  next_state = WAIT1;

                WAIT1:  if (baud_last)         next_state = START;

                START:  if (baud_last)         next_state = DATA;

                DATA:   if (data_done)
                            next_state = pen ? PARITY : STOP;

                PARITY: if (baud_last)         next_state = STOP;

                STOP:   if (stop_done_i)
                            next_state = (!tsr_empty_sync) ? WAIT1 : IDLE;

                default: next_state = IDLE;
            endcase
        end
    end

    // =========================================================================
    // tsr_ready / tsr_shift  (combinational)
    // =========================================================================
    always_comb begin
        tsr_shift = 1'b0;
        tsr_ready = 1'b0;
        case (present_state)
            WAIT1:  begin tsr_shift = 1'b1; tsr_ready = 1'b1; end
            START:  tsr_shift = 1'b1;
            DATA:   tsr_shift = 1'b1;
            PARITY: tsr_shift = 1'b1;
            STOP:   tsr_shift = 1'b1;
            default:;
        endcase
    end

    // =========================================================================
    // tx_out – SEQUENTIAL (registered)
    //
    // tx_next is computed combinationally from the *current* present_state /
    // bc / serial_out / parity_reg, but only sampled into tx_out on the
    // clock edge. This keeps tx_out glitch-free / X-free, at the cost of a
    // 1-cycle lag versus a purely-combinational output.
    //
    // Normal operation (bc=0):
    //   IDLE / WAIT1 / STOP  ? mark  (1)
    //   START                ? space (0)
    //   DATA                 ? serial_out  (LSB-first, from registered shift_reg)
    //   PARITY               ? parity_reg (registered)
    //
    // Break condition (bc=1):
    //   tx_next is forced LOW combinationally, so on the very next clock
    //   edge tx_out registers to 0 and stays 0 every subsequent cycle that
    //   bc remains asserted (the FSM is also forced into/held in IDLE,
    //   see next-state logic above). When bc drops back to 0, tx_out
    //   registers back to the normal FSM-driven value on the following edge.
    // =========================================================================
    logic tx_next;   // combinational "what tx_out should become next"

    always_comb begin
        if (bc) begin
            tx_next = 1'b0;
        end else begin
            case (present_state)
                START:   tx_next = 1'b0;
                DATA:    tx_next = serial_out;
                PARITY:  tx_next = parity_reg;
                default: tx_next = 1'b1;        // IDLE, WAIT1, STOP = mark
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            tx_out <= 1'b1; 
	    tsr_shift1 <= 1'b0;  // line idles HIGH (mark) out of reset
	end
        else begin
            tx_out <= tx_next;
	    tsr_shift1 <= tsr_shift;
		
    end
end
endmodule

