module rbr #(
    parameter WIDTH     = 8,
    parameter REG_WIDTH = 8
)(
    // ----------------------------------------------------------------
    // clk_w domain  (APB / write side – fast clock)
    // ----------------------------------------------------------------
    input  logic               clk_w,
    input  logic               rst_n,
    input  logic               write_enable,
    input  logic [WIDTH-1:0]   data_in,
    input  logic               data_rd_en,
    input  logic  FCR1,

    //output logic               rbr_full,
    output logic               rbr_empty,
    output logic               overrun_err,

    // ----------------------------------------------------------------
    // clk_r domain  (UART core / read side – slow clock)
    // ----------------------------------------------------------------
    input  logic               clk_r,
    output logic [WIDTH-1:0]   rbr_data_out
);

    logic [WIDTH-1:0] shadow_data;
logic               rbr_full;

// --------------------------------------------------------------------
// Toggle handshake signals (clk_w <-> clk_r)
// --------------------------------------------------------------------
    logic wr_req_tog;
    logic ack_tog;
    logic ack_w1, ack_wsync, ack_wprev;
    logic busy;

    assign busy = (wr_req_tog != ack_wsync);

// --------------------------------------------------------------------
// Sync rbr_empty into clk_r domain (2-FF) for one-shot guard
// --------------------------------------------------------------------
    logic empty_r1, empty_rsync;
logic rbr_empty1;
// ====================================================================
// CLK_W DOMAIN
// ====================================================================
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            shadow_data  <= '0;
            wr_req_tog   <= 1'b0;
            ack_w1       <= 1'b0;
            ack_wsync    <= 1'b0;
            ack_wprev    <= 1'b0;
           // rbr_full     <= 1'b0;
            rbr_empty1    <= 1'b1;
        end
        else if (FCR1) begin
            shadow_data  <= '0;
            wr_req_tog   <= 1'b0;
            ack_w1       <= 1'b0;
            ack_wsync    <= 1'b0;
            ack_wprev    <= 1'b0;
          //  rbr_full     <= 1'b0;
            rbr_empty1    <= 1'b1;
        end
        else begin
            // 2-FF sync: ack_tog (clk_r) -> clk_w
            ack_w1    <= ack_tog;
            ack_wsync <= ack_w1;
            ack_wprev <= ack_wsync;

            // Write wins over ack edge (same-cycle priority)
            if (write_enable && !busy) begin
                shadow_data <= data_in;
                wr_req_tog  <= ~wr_req_tog;
               // rbr_full    <= 1'b1;
                rbr_empty1   <= 1'b0;
		
            end
            else if (ack_wsync != ack_wprev) begin
               // rbr_full  <= 1'b0;
                rbr_empty1 <= 1'b1;
            end
        end
    end

// ====================================================================
// CLK_R DOMAIN
// ====================================================================
// 2-FF sync: rbr_empty (clk_w) -> clk_r
// Used to detect when the write side has acknowledged the read,
// so the one-shot read_done latch can be cleared safely.
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            empty_r1   <= 1'b1;
            empty_rsync <= 1'b1;
        end
        else begin
            empty_r1    <= rbr_empty1;
            empty_rsync <= empty_r1;
        end
    end

    // One-shot latch: set on first valid read, cleared when empty_rsync=1
    // This blocks re-reads while ack is propagating back to clk_w side
    logic read_done;

    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            ack_tog      <= 1'b0;
            rbr_data_out <= '0;
            read_done    <= 1'b0;
	   // rbr_full  <= 1'b0;
	//	ok <= 0;
        end
               else begin
            // Clear one-shot when write side confirms empty (ack complete)
            if (empty_rsync)
                read_done <= 1'b0;

            if (data_rd_en && !empty_rsync && !read_done) begin
                // Valid data available AND not already read this transaction
                rbr_data_out <= shadow_data;
                ack_tog      <= ~ack_tog;
                read_done    <= 1'b1;       // block further reads until empty
	//	ok <= 1;
		//rbr_full  <= 1'b0;
            end
            else if (data_rd_en && (empty_rsync || read_done)) begin
                // Read attempted with no valid data (empty or already consumed)
                rbr_data_out <= '0;
	//	ok <= 0;
	//	rbr_full  <= 1'b1;
            end
        end
    end
assign rbr_full = ~rbr_empty;
assign rbr_empty= empty_rsync|read_done;
assign overrun_err = rbr_full & write_enable;

endmodule



