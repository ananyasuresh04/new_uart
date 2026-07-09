module thr #(
    parameter WIDTH = 8
)(
    input  logic               clk_w,
    input  logic               clk_r,
    input  logic               rst_n,
    input  logic               tx_clr,
    input  logic               write_enable,
    input  logic               tsr_load,        // clk_r domain: load TSR now
    input  logic [WIDTH-1:0]   thr_data_in,
    output logic [WIDTH-1:0]   thr_data_out,
    output logic               thr_empty,       // clk_w domain, combinational
    output logic               thr_full         // clk_w domain, registered
);

    // -------------------------------------------------------------------------
    // tx_clr – 2-FF sync into clk_w
    // -------------------------------------------------------------------------
    logic tx_clr_w1, tx_clr_wsync;
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) {tx_clr_wsync, tx_clr_w1} <= 2'b00;
        else        {tx_clr_wsync, tx_clr_w1} <= {tx_clr_w1, tx_clr};
    end

    // -------------------------------------------------------------------------
    // tx_clr – 2-FF sync into clk_r
    // -------------------------------------------------------------------------
   /* logic tx_clr_r1, tx_clr_rsync;
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) {tx_clr_rsync, tx_clr_r1} <= 2'b00;
        else        {tx_clr_rsync, tx_clr_r1} <= {tx_clr_r1, tx_clr};
    end
*/

    // -------------------------------------------------------------------------
    // tsr_load CDC  (clk_r ? clk_w)  –  TOGGLE HANDSHAKE
    //
    //  Step 1 (clk_r): each rising edge of tsr_load toggles tgl_r
    //  Step 2 (clk_w): 2-FF sync of tgl_r  ?  tgl_w1, tgl_w2
    //  Step 3 (clk_w): edge detect tgl_w1 ^ tgl_w2  ?  tsr_pulse_w
    //                  (one clk_w-wide pulse, minimum CDC latency = 2 clk_w)
    // -------------------------------------------------------------------------
    logic tgl_r;                        // toggle FF, clk_r domain
    logic tgl_w1, tgl_w2;              // 2-FF synchroniser, clk_w domain
    logic tsr_pulse_w;                  // single clk_w pulse

    // Toggle on every rising edge of tsr_load (clk_r)
    always_ff @(posedge clk_r or negedge rst_n) begin
        if      (!rst_n)       tgl_r <= 1'b0;
      //  else if (tx_clr_rsync) tgl_r <= 1'b0;
        else if (tsr_load)     tgl_r <= ~tgl_r;
    end

    // 2-FF synchroniser in clk_w + edge detect
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            tgl_w1    <= 1'b0;
            tgl_w2    <= 1'b0;
        end else if (tx_clr_wsync) begin
            tgl_w1    <= 1'b0;
            tgl_w2    <= 1'b0;
        end else begin
            tgl_w1    <= tgl_r;
            tgl_w2    <= tgl_w1;
        end
    end

    // Pulse fires whenever tgl_w1 ? tgl_w2  (any toggle edge)
    assign tsr_pulse_w = tgl_w1 ^ tgl_w2;

    // -------------------------------------------------------------------------
    // Data register + thr_full  (clk_w domain)
    //
    //  Priority (when both tsr_pulse_w and write_enable arrive same cycle):
    //    write_enable wins ? data is kept, thr_full stays HIGH
    //    (the TSR was just loaded; CPU is already writing new data)
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] reg_data;

    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            reg_data <= '0;
            thr_full <= 1'b0;
        end else if (tx_clr_wsync) begin
            reg_data <= '0;
            thr_full <= 1'b0;
        end else begin
            // Write takes priority over clear
            if (write_enable && !thr_full) begin
                reg_data <= thr_data_in;
                thr_full <= 1'b1;
            end else if (tsr_pulse_w) begin
                thr_full <= 1'b0;           // TSR consumed the byte
            end
        end
    end

    // thr_empty: purely combinational inverse of thr_full (clk_w domain)
    assign thr_empty = ~thr_full;

    // -------------------------------------------------------------------------
    // thr_data_out  (clk_r domain)
    // Captures reg_data on the clk_r edge where tsr_load is asserted
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_r or negedge rst_n) begin
        if      (!rst_n)       thr_data_out <= '0;
      //  else if (tx_clr_rsync) thr_data_out <= '0;
        else if (tsr_load)     thr_data_out <= reg_data;
    end


endmodule
