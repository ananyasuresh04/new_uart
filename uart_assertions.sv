module uart_assertions #(
    parameter int CLK_FREQ_MHZ = 50,    // UART input clock frequency (MHz)
    parameter int BAUD_DIVISOR  = 27,    // DLL+DLH value programmed by test
    parameter int OSM           = 16     // Over-sampling: 16 or 13
)(
    input logic        pclk,
    input logic        presetn,

    // Serial lines (the only UART-specific pins)
    input logic        txd,              // UART1 transmit output
    input logic        rxd,              // UART1 receive  input

    // APB bus (needed ONLY to observe register writes that affect UART state)
    input logic [7:0]  paddr,
    input logic        pwrite,
    input logic [7:0]  pwdata,
    input logic [7:0]  prdata,
    input logic        psel,
    input logic        penable,
    input logic        pready
);

//=========================================================================
    // Derived timing constants
    // bit_period_clks = number of pclk cycles per one UART bit
    //=========================================================================
    localparam real BIT_PERIOD_NS  = (BAUD_DIVISOR * OSM * 1000.0) / CLK_FREQ_MHZ;
    localparam int  BIT_CLKS       = BAUD_DIVISOR * OSM;  // pclk cycles per bit
    localparam int  FRAME_CLKS_8N1 = BIT_CLKS * 10;       // START+8data+STOP
    localparam int  FRAME_CLKS_MAX = BIT_CLKS * 13;       // worst: START+8+PAR+2STOP

    // Short window used in liveness checks
    localparam int  TIMEOUT_CLKS   = FRAME_CLKS_MAX * 20; // 20 frames max

    //=========================================================================
    // Helper signals derived from register bus observations
    //=========================================================================

    // Shadow the LCR register to know active configuration
    logic [7:0] lcr_shadow;
    logic [7:0] fcr_shadow;
    logic       dlab;

    logic [1:0] wls;
    logic       stb;
    logic       pen;
    logic       eps;
    logic       stick_parity;
    logic       break_ctrl;

    assign wls          = lcr_shadow[1:0];
    assign stb          = lcr_shadow[2];
    assign pen          = lcr_shadow[3];
    assign eps          = lcr_shadow[4];
    assign stick_parity = lcr_shadow[5];
    assign break_ctrl   = lcr_shadow[6];

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            lcr_shadow <= 8'h00;
            fcr_shadow <= 8'h00;
        end else begin
            if (psel && penable && pready && pwrite) begin
                if (paddr == 8'h0C) lcr_shadow <= pwdata; // LCR
                if (paddr == 8'h08) fcr_shadow <= pwdata; // FCR
            end
        end
    end

    assign dlab = lcr_shadow[7];

    // Detect a THR write (paddr=0x00, pwrite=1, DLAB=0)
    logic thr_write;
    assign thr_write = psel && penable && pready && pwrite &&
                       (paddr == 8'h00) && !dlab;

    // Detect FIFO enabled
    logic fifo_en;
    assign fifo_en = fcr_shadow[0];

    // A1: After reset deasserts, TXD must be logic 1 (idle/Mark state)
    property p_txd_idle_after_reset;
        @(posedge pclk)
        $rose(presetn) |-> ##[0:10] (txd === 1'b1);
    endproperty
    A1_TXD_IDLE_AFTER_RESET :
        assert property (p_txd_idle_after_reset)
        else $error("ASSERT FAIL A1: TXD not idle (1) within 10 cycles of reset release");

    // A2: TXD must be stable for exactly BIT_CLKS cycles during each bit
    property p_txd_bit_stable;
        @(posedge pclk) disable iff (!presetn)
        $changed(txd) |-> $stable(txd) [*(BIT_CLKS - 2)];
    endproperty
    A2_TXD_BIT_STABLE :
        assert property (p_txd_bit_stable)
        else $error("ASSERT FAIL A2: TXD changed too fast bit width < BIT_CLKS-2 cycles");

    // A3: TXD START bit must be logic 0
    property p_txd_start_bit_zero;
        @(posedge pclk) disable iff (!presetn)
        // Detect falling edge: txd was 1 last cycle, now 0
        ($fell(txd)) |-> (txd === 1'b0);
    endproperty
    A3_TXD_START_BIT_ZERO :
        assert property (p_txd_start_bit_zero)
        else $error("ASSERT FAIL A3: TXD fell but START bit is not 0");

     // A4: After a full UART frame, TXD must return to idle (1) within
     property p_txd_returns_to_idle;
        @(posedge pclk) disable iff (!presetn)
        $fell(txd) |-> ##[FRAME_CLKS_8N1 : FRAME_CLKS_MAX] (txd === 1'b1);
    endproperty
    A4_TXD_RETURNS_IDLE :
        assert property (p_txd_returns_to_idle)
        else $error("ASSERT FAIL A4: TXD did not return to idle after frame (STOP bit missing?)");

     // A5: TXD must not glitch (must stay stable) while UART is NOT transmitting
      property p_txd_no_glitch;
        @(posedge pclk) disable iff (!presetn)
        $fell(txd) |-> not ($rose(txd) [->1] within ##[1:(BIT_CLKS/2)] $fell(txd));
    endproperty
    A5_TXD_NO_GLITCH :
        assert property (p_txd_no_glitch)
        else $error("ASSERT FAIL A5: TXD glitch detected – fell and rose within half a bit period");

      // A6: When a THR write occurs, TXD must eventually go low (start transmitting)
         property p_thr_write_causes_tx;
        @(posedge pclk) disable iff (!presetn)
        thr_write |-> ##[1:TIMEOUT_CLKS] $fell(txd);
    endproperty
    A6_THR_WRITE_CAUSES_TX :
        assert property (p_thr_write_causes_tx)
        else $error("ASSERT FAIL A6: THR was written but TXD never went low (no transmission)");

      // B1: RXD must be logic 1 (idle) at the start of simulation
     property p_rxd_idle_at_start;
        @(posedge pclk)
        $rose(presetn) |-> ##[0:5] (rxd === 1'b1);
    endproperty
    B1_RXD_IDLE_AT_RESET :
        assert property (p_rxd_idle_at_start)
        else $error("ASSERT FAIL B1: RXD not idle (1) after reset release");

        // B2: RXD START bit must be logic 0
        property p_rxd_start_bit_zero;
        @(posedge pclk) disable iff (!presetn)
        $fell(rxd) |-> (rxd === 1'b0);
    endproperty
    B2_RXD_START_BIT_ZERO :
        assert property (p_rxd_start_bit_zero)
        else $error("ASSERT FAIL B2: RXD fell but START bit is not 0");

      // B3: RXD bit must be stable for at least (BIT_CLKS-2) cycles
      property p_rxd_bit_stable;
        @(posedge pclk) disable iff (!presetn)
        $changed(rxd) |-> $stable(rxd) [*(BIT_CLKS - 2)];
    endproperty
    B3_RXD_BIT_STABLE :
        assert property (p_rxd_bit_stable)
        else $error("ASSERT FAIL B3: RXD changed too fast – slave not driving at correct baud rate");


     // B4: After a full RXD frame, line must return to idle within FRAME_CLKS_MAX
    property p_rxd_returns_to_idle;
        @(posedge pclk) disable iff (!presetn)
        $fell(rxd) |-> ##[FRAME_CLKS_8N1 : FRAME_CLKS_MAX] (rxd === 1'b1);
    endproperty
    B4_RXD_RETURNS_IDLE :
        assert property (p_rxd_returns_to_idle)
        else $error("ASSERT FAIL B4: RXD did not return to idle after frame");

     // C1: During reset (presetn=0), TXD must remain at logic 1 (idle)
     property p_txd_during_reset;
        @(posedge pclk)
        (!presetn) |-> (txd === 1'b1);
    endproperty
    C1_TXD_HELD_DURING_RESET :
        assert property (p_txd_during_reset)
        else $error("ASSERT FAIL C1: TXD not idle (1) while presetn=0");

     // C2: During reset, RXD driven by slave must be ignored.
     property p_no_tx_during_reset;
        @(posedge pclk)
        (!presetn) |-> (txd !== 1'b0);
    endproperty
    C2_NO_TX_DURING_RESET :
        assert property (p_no_tx_during_reset)
        else $error("ASSERT FAIL C2: TXD went low (TX started) while presetn=0");

     // D1: A UART frame must contain at least one STOP bit = 1 after data bits
     property p_txd_stop_bit_present;
        @(posedge pclk) disable iff (!presetn)
        // After a falling edge (START), within 10*BIT_CLKS (8N1 frame),
        // TXD must eventually be 1
        $fell(txd) |-> ##[BIT_CLKS*9 : BIT_CLKS*13] (txd === 1'b1);
    endproperty
    D1_TXD_STOP_BIT_PRESENT :
        assert property (p_txd_stop_bit_present)
        else $error("ASSERT FAIL D1: TXD STOP bit not detected – possible framing error");

      // D2: Minimum inter-frame gap on TXD
      property p_txd_min_idle_gap;
        @(posedge pclk) disable iff (!presetn)
        // After TXD goes high (end of STOP), must stay high for at least
        // half a bit period before next START
        $rose(txd) |-> $stable(txd)[*(BIT_CLKS/2)];
     endproperty
     D2_TXD_MIN_IDLE_GAP :
        assert property (p_txd_min_idle_gap)
        else $error("ASSERT FAIL D2: TXD inter-frame gap too short (< half bit period)");

    // D3: RXD same  minimum inter-frame gap between slave-driven frames
     property p_rxd_min_idle_gap;
        @(posedge pclk) disable iff (!presetn)
        $rose(rxd) |-> $stable(rxd)[*(BIT_CLKS/2)];
    endproperty
    D3_RXD_MIN_IDLE_GAP :
        assert property (p_rxd_min_idle_gap)
        else $error("ASSERT FAIL D3: RXD inter-frame gap too short (< half bit period)");

     // E1: DLAB must be 0 before any THR write can be valid
     property p_thr_write_dlab_zero;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pready && pwrite && (paddr == 8'h00)) |->
        (lcr_shadow[7] == 1'b0);
    endproperty
    E1_THR_WRITE_NEEDS_DLAB_ZERO :
        assert property (p_thr_write_dlab_zero)
        else $error("ASSERT FAIL E1: THR written with DLAB=1 (writing DLL instead of THR!)");

     // E2: DLAB must be 0 before any RBR read
      property p_rbr_read_dlab_zero;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pready && !pwrite && (paddr == 8'h00)) |->
        (lcr_shadow[7] == 1'b0);
    endproperty
    E2_RBR_READ_NEEDS_DLAB_ZERO :
        assert property (p_rbr_read_dlab_zero)
        else $error("ASSERT FAIL E2: RBR read with DLAB=1 (reading DLL instead of RBR!)");

     // E3: FCR FIFOEN must be set FIRST before other FCR bits
     property p_fcr_fifoen_first;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pready && pwrite && (paddr == 8'h08) &&
         (pwdata[7:1] != 7'h00)) |-> (pwdata[0] == 1'b1);
    endproperty
    E3_FCR_FIFOEN_FIRST :
        assert property (p_fcr_fifoen_first)
        else $error("ASSERT FAIL E3: FCR written with non-FIFOEN bits but FIFOEN=0 (spec 3.5 violation)");

    // F1: TXD must not stay LOW for more than FRAME_CLKS_MAX cycles
    property p_txd_not_stuck_low;
        @(posedge pclk) disable iff (!presetn || lcr_shadow[6])
        $fell(txd) |-> ##[1:FRAME_CLKS_MAX] $rose(txd);
    endproperty
    F1_TXD_NOT_STUCK_LOW :
        assert property (p_txd_not_stuck_low)
        else $error("ASSERT FAIL F1: TXD stuck LOW beyond maximum frame time (hung TX or unintended BREAK)");

     // F2: RXD must not stay LOW for more than FRAME_CLKS_MAX cycles
     property p_rxd_not_stuck_low;
        @(posedge pclk) disable iff (!presetn)
        $fell(rxd) |-> ##[1:FRAME_CLKS_MAX] $rose(rxd);
    endproperty
    F2_RXD_NOT_STUCK_LOW :
        assert property (p_rxd_not_stuck_low)
        else $error("ASSERT FAIL F2: RXD stuck LOW beyond maximum frame time (slave model bug?)");


//--------------------------------------------------------------------------------
    property p_thr_write_after_valid_config;
    @(posedge pclk) disable iff (!presetn)
    thr_write |-> (
      !dlab &&
      (wls inside {2'b00, 2'b01, 2'b10, 2'b11})
    );
    endproperty

    A_THR_WRITE_AFTER_VALID_CONFIG :
    assert property(p_thr_write_after_valid_config)
    else $error("ASSERT FAIL: THR write happened before valid UART config");

    //FCR reset bits should be used only with FIFO enable
    property p_fcr_clear_requires_fifo_en;
    @(posedge pclk) disable iff (!presetn)
    (psel && penable && pready && pwrite &&
     (paddr == 8'h08) &&
      (pwdata[1] || pwdata[2]))
     |-> pwdata[0];
    endproperty

    A_FCR_CLEAR_REQUIRES_FIFO_EN :
    assert property(p_fcr_clear_requires_fifo_en)
    else $error("ASSERT FAIL: RX/TX FIFO clear used while FIFOEN=0");

endmodule
