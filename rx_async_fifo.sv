module rx_async_fifo #(
    parameter WIDTH      = 8,
    parameter REG_WIDTH      = 8,
    parameter DEPTH      = 16
)(
    input  logic                  clk_w,
    input  logic                  rst_n,
    input  logic                  write_enable,
    input  logic [WIDTH-1:0]      data_in,
 input logic   FCR1,
    input  logic data_rd_en,
    input  logic                  clk_r,

    output logic [WIDTH-1:0] data_out,
    output logic	rx_empty,
    output logic	overrun_err
  //  output logic	rx_full

);
logic valid;
logic done;

logic               rx_full;


    logic [WIDTH-1:0] fifo_mem [DEPTH-1:0];
localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [ADDR_WIDTH:0] wptr_bin;
    logic [ADDR_WIDTH:0] rptr_bin;

    logic [ADDR_WIDTH:0] wptr_gray;
    logic [ADDR_WIDTH:0] rptr_gray;

    logic [ADDR_WIDTH:0] rptr_gray_w1;
    logic [ADDR_WIDTH:0] rptr_gray_wsync;

    logic [ADDR_WIDTH:0] wptr_gray_r1;
    logic [ADDR_WIDTH:0] wptr_gray_rsync;

    assign wptr_gray = wptr_bin ^ (wptr_bin >> 1);
    assign rptr_gray = rptr_bin ^ (rptr_bin >> 1);

    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            rptr_gray_w1    <= '0;
            rptr_gray_wsync <= '0;
        end else begin
            rptr_gray_w1    <= rptr_gray;
            rptr_gray_wsync <= rptr_gray_w1;
        end
    end

    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            wptr_bin <= '0;
			valid <=1'b0;

            for (int i = 0; i < DEPTH; i++)
                fifo_mem[i] <= '0;
        end else if (FCR1) begin
            wptr_bin <= '0;
            for (int i = 0; i < DEPTH; i++)
                fifo_mem[i] <= '0;
        end else begin
            if (write_enable && !rx_full) begin
                fifo_mem[wptr_bin[ADDR_WIDTH-1:0]] <= data_in;
                wptr_bin <= wptr_bin + {{(ADDR_WIDTH){1'b0}},1'b1};;
			valid <=1'b1;

            end
        end
    end

    logic full_comb;

    always_comb begin
        full_comb = (wptr_gray[ADDR_WIDTH]     != rptr_gray_wsync[ADDR_WIDTH])   &&
                    (wptr_gray[ADDR_WIDTH-1]   != rptr_gray_wsync[ADDR_WIDTH-1]) &&
                    (wptr_gray[ADDR_WIDTH-2:0] == rptr_gray_wsync[ADDR_WIDTH-2:0]);
    end

    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n)
            rx_full <= 1'b0;
        else if (FCR1)
            rx_full <= 1'b0;
        else
            rx_full <= full_comb;
    end

    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            wptr_gray_r1    <= '0;
            wptr_gray_rsync <= '0;
        end else begin
            wptr_gray_r1    <= wptr_gray;
            wptr_gray_rsync <= wptr_gray_r1;
        end
    end
logic read;
assign read = (valid && !done)? 1'b1:1'b0;


    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            rptr_bin <= '0;
            data_out <= '0;
	    done <= 1'b0;
	
        end
 
	else begin
            if (data_rd_en && !rx_empty && read) begin
                data_out <= fifo_mem[rptr_bin[ADDR_WIDTH-1:0]];
		done <= 1'b1;
                rptr_bin <= rptr_bin + {{(ADDR_WIDTH){1'b0}},1'b1};;
		
            end
	  else begin
		data_out <='0;
		rptr_bin <=rptr_bin;
		done <= '0;
		end
        end
    end

    logic empty_comb;

    always_comb begin
        empty_comb = (rptr_gray == wptr_gray_rsync);
    end

    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n)
            rx_empty <= 1'b1;
              else
            rx_empty <= empty_comb;
    end
assign overrun_err = rx_full & write_enable;

endmodule
