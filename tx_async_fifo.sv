module tx_async_fifo #(
    parameter WIDTH       = 8,
    parameter DEPTH       = 16,
    parameter ADDR_WIDTH1 = 8
)(
    input  logic             clk_w,
    input  logic             rst_n,
    input  logic             tx_clr,
    input  logic             write_enable,
    input  logic [WIDTH-1:0] data_in,
    output logic             fifo_full,
    input  logic             clk_r,
    input  logic             read_enable,
    output logic [WIDTH-1:0] data_out,
    output logic             fifo_empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam CNT_WIDTH  = $clog2(DEPTH+1);

    logic [WIDTH-1:0]     fifo_mem [DEPTH-1:0];

    // ---------------------------------------------------------------
    // Write pointer ? clk_w domain
    // ---------------------------------------------------------------
    logic [ADDR_WIDTH:0]  wptr_bin;
    logic [ADDR_WIDTH:0]  wptr_bin_next;

    // ---------------------------------------------------------------
    // Read pointer ? clk_r domain
    // ---------------------------------------------------------------
    logic [ADDR_WIDTH:0]  rptr_bin;
    logic [ADDR_WIDTH:0]  rptr_bin_next;
    logic [ADDR_WIDTH:0]  rptr_gray;
    logic [ADDR_WIDTH:0]  rptr_gray_next;

    // ---------------------------------------------------------------
    // tx_clr syncs
    // ---------------------------------------------------------------
    logic tx_clr_w1;
    logic tx_clr_wsync;
    logic tx_clr_r1;
    logic tx_clr_rsync;

    // ---------------------------------------------------------------
    // Occupancy counter ? clk_w domain
    // ---------------------------------------------------------------
    logic [CNT_WIDTH-1:0] wr_count;

    // ---------------------------------------------------------------
    // CDC: read pulse clk_r -> clk_w
    // ---------------------------------------------------------------
    logic read_toggle_r;
    logic read_tog_sync1;
    logic read_tog_sync2;
    logic read_tog_sync2_d;
    logic read_pulse_w;

    assign read_pulse_w = read_tog_sync2 ^ read_tog_sync2_d;

    // ---------------------------------------------------------------
    // do_write / do_read
    // Use REGISTERED fifo_full and fifo_empty ? no combinational loop
    // ---------------------------------------------------------------
    logic do_write;
    logic do_read;

    // ---------------------------------------------------------------
    // Read-side pulse stretch breaker (clk_r domain)
    //
    // read_enable can be held high for many cycles. We only want ONE
    // internal pulse (1 clk_r cycle wide) every 21 cycles
    // (count 0 .. 20) while read_enable stays asserted:
    //   - When read_enable is low, rd_count is held at 0.
    //   - When read_enable is high, rd_count counts 0 -> 20 and
    //     wraps back to 0.
    //   - internal_read_enable is asserted combinationally only when
    //     read_enable is high AND rd_count == 0. Since rd_count
    //     increments away from 0 on the very next clk_r edge (as long
    //     as read_enable stays high), this pulse is exactly one
    //     clk_r cycle wide.
    // ---------------------------------------------------------------
    localparam int RD_CNT_MAX   = 20;
    localparam int RD_CNT_WIDTH = $clog2(RD_CNT_MAX+1);

    logic [RD_CNT_WIDTH-1:0] rd_count;
    logic                    internal_read_enable;

    assign internal_read_enable = read_enable & (rd_count == '0);

    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            rd_count <= '0;
        end else if (tx_clr_rsync) begin
            rd_count <= '0;
        end else if (read_enable) begin
            if (rd_count == RD_CNT_WIDTH'(RD_CNT_MAX))
                rd_count <= '0;
            else
                rd_count <= rd_count + RD_CNT_WIDTH'(1);
        end else begin
            rd_count <= '0;
        end
    end


    assign do_write = write_enable & ~fifo_full;
    assign do_read  = internal_read_enable & ~fifo_empty;

    // ---------------------------------------------------------------
    // fifo_full and fifo_empty ? REGISTERED on clk_w
    //
    // Key design: flags are computed from REGISTERED wr_count
    // (not wr_count_next) so there is NO combinational loop.
    //
    // Look-ahead logic gives same-cycle response:
    //
    // fifo_full asserts same cycle as 16th write because:
    //   On the posedge where write #16 is sampled, wr_count=15
    //   (from previous cycle). write_enable=1, fifo_full=0, so
    //   do_write=1. The always_ff block fires:
    //   full_next = (15+1==16) & do_write = 1 -> fifo_full <= 1
    //   fifo_full updates at END of that posedge = same cycle.
    //
    // fifo_empty deasserts same cycle as first write because:
    //   On the posedge where write #1 is sampled, wr_count=0,
    //   fifo_empty=1. write_enable=1, do_write=1. always_ff fires:
    //   empty_next: wr_count==0 & do_write=1 -> 0 -> fifo_empty<=0
    //   fifo_empty updates at END of that posedge = same cycle.
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // tx_clr sync -> clk_w
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            tx_clr_w1    <= 1'b0;
            tx_clr_wsync <= 1'b0;
        end else begin
            tx_clr_w1    <= tx_clr;
            tx_clr_wsync <= tx_clr_w1;
        end
    end

    // ---------------------------------------------------------------
    // tx_clr sync -> clk_r
    // ---------------------------------------------------------------
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            tx_clr_r1    <= 1'b0;
            tx_clr_rsync <= 1'b0;
        end else begin
            tx_clr_r1    <= tx_clr;
            tx_clr_rsync <= tx_clr_r1;
        end
    end

    // ---------------------------------------------------------------
    // Write pointer ? clk_w
    // ---------------------------------------------------------------
    assign wptr_bin_next = wptr_bin + {{ADDR_WIDTH{1'b0}}, do_write};

    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n)
            wptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else if (tx_clr_wsync)
            wptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else
            wptr_bin <= wptr_bin_next;
    end

    // ---------------------------------------------------------------
    // Memory write ? clk_w
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            begin : rst_mem_w
                integer i;
                for (i = 0; i < DEPTH; i = i + 1)
                    fifo_mem[i] <= {WIDTH{1'b0}};
            end
        end else if (tx_clr_wsync) begin
            begin : clr_mem_w
                integer i;
                for (i = 0; i < DEPTH; i = i + 1)
                    fifo_mem[i] <= {WIDTH{1'b0}};
            end
        end else if (do_write) begin
            fifo_mem[wptr_bin[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    // ---------------------------------------------------------------
    // Read toggle ? clk_r
    // ---------------------------------------------------------------
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n)
            read_toggle_r <= 1'b0;
        else if (tx_clr_rsync)
            read_toggle_r <= 1'b0;
        else if (do_read)
            read_toggle_r <= ~read_toggle_r;
    end

    // ---------------------------------------------------------------
    // 2-FF + edge-detect sync: read_toggle_r -> clk_w
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            read_tog_sync1   <= 1'b0;
            read_tog_sync2   <= 1'b0;
            read_tog_sync2_d <= 1'b0;
        end else if (tx_clr_wsync) begin
            read_tog_sync1   <= 1'b0;
            read_tog_sync2   <= 1'b0;
            read_tog_sync2_d <= 1'b0;
        end else begin
            read_tog_sync1   <= read_toggle_r;
            read_tog_sync2   <= read_tog_sync1;
            read_tog_sync2_d <= read_tog_sync2;
        end
    end

    // ---------------------------------------------------------------
    // Occupancy counter ? clk_w
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n)
            wr_count <= {CNT_WIDTH{1'b0}};
        else if (tx_clr_wsync)
            wr_count <= {CNT_WIDTH{1'b0}};
        else begin
            case ({do_write, read_pulse_w})
                2'b10:   wr_count <= wr_count + {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                2'b01:   wr_count <= wr_count - {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                default: wr_count <= wr_count;
            endcase
        end
    end

    // ---------------------------------------------------------------
    // fifo_full ? registered, look-ahead from wr_count (no loop)
    //
    // fifo_full asserts  : when count after this cycle == DEPTH
    //   case write only  : wr_count+1 == DEPTH  ->  wr_count == DEPTH-1
    //   case both        : wr_count+0 == DEPTH  ->  wr_count == DEPTH
    //   case neither     : wr_count   == DEPTH
    //
    // fifo_full deasserts: when count after this cycle < DEPTH
    //   case read only   : always deasserts (wr_count was <= DEPTH)
    //   case write only  : wr_count+1 < DEPTH
    //   case both        : wr_count   < DEPTH
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            fifo_full <= 1'b0;
        end else if (tx_clr_wsync) begin
            fifo_full <= 1'b0;
        end else begin
            case ({do_write, read_pulse_w})
                2'b10: fifo_full <= (wr_count == CNT_WIDTH'(DEPTH-1));
                2'b01: fifo_full <= 1'b0;
                2'b11: fifo_full <= (wr_count == CNT_WIDTH'(DEPTH));
                2'b00: fifo_full <= (wr_count == CNT_WIDTH'(DEPTH));
            endcase
        end
    end

    // ---------------------------------------------------------------
    // fifo_empty ? registered, look-ahead from wr_count (no loop)
    //
    // fifo_empty asserts  : when count after this cycle == 0
    //   case read only    : wr_count-1 == 0  ->  wr_count == 1
    //   case both         : wr_count+0 == 0  ->  wr_count == 0 (impossible during both)
    //   case neither      : wr_count   == 0
    //
    // fifo_empty deasserts: when count after this cycle > 0
    //   case write only   : always deasserts
    //   case both         : wr_count stays same -> if >0 stays non-empty
    // ---------------------------------------------------------------
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            fifo_empty <= 1'b1;
        end else if (tx_clr_wsync) begin
            fifo_empty <= 1'b1;
        end else begin
            case ({do_write, read_pulse_w})
                2'b10: fifo_empty <= 1'b0;
                2'b01: fifo_empty <= (wr_count == CNT_WIDTH'(1));
                2'b11: fifo_empty <= (wr_count == CNT_WIDTH'(0));
                2'b00: fifo_empty <= (wr_count == CNT_WIDTH'(0));
            endcase
        end
    end

    // ---------------------------------------------------------------
    // Read pointer ? clk_r
    // ---------------------------------------------------------------
    assign rptr_bin_next  = rptr_bin + {{ADDR_WIDTH{1'b0}}, do_read};
    assign rptr_gray_next = rptr_bin_next ^ (rptr_bin_next >> 1);

    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            rptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else if (tx_clr_rsync) begin
            rptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    // ---------------------------------------------------------------
    // data_out ? registered, clk_r
    // ---------------------------------------------------------------
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= {WIDTH{1'b0}};
        end else if (tx_clr_rsync) begin
            data_out <= {WIDTH{1'b0}};
        end else if (do_read) begin
            data_out <= fifo_mem[rptr_bin[ADDR_WIDTH-1:0]];
        end
    end

endmodule
