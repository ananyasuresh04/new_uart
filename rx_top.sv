module rx_top #(
		parameter WIDTH = 8,
		parameter DEPTH = 16,
		parameter ADDR_WIDTH = 4,
		parameter REG_WIDTH =8
		) (
    input  logic clk_w, 
    input  logic clk_r, 
    input  logic bclk, 
    
    input  logic rst_n,
    input  logic rx,

    output logic [WIDTH-1:0] rdata,
    input   logic [REG_WIDTH-1:0] LCR,
     input logic FCR_SYNC,FCR1,
     input  logic MDR,
	input logic data_rd_en,
    output logic pe, fe, bi,oe,
output logic rx_empty// rx_full
   

);

 // logic temp;
//assign temp = FCR[0]; 
    logic [WIDTH-1:0] rx_data;
     logic rx_valid;
logic oe1,oe2;


   logic rbr_empty; 
 //  logic rbr_full; 
   logic [WIDTH-1:0]rbr_data;

    rx_fsm   #(
    .WIDTH (WIDTH), 
    .REG_WIDTH (REG_WIDTH) 
  ) core (
       // .clk(clk_w),
        .bclk(bclk),
        .rst_n(rst_n),
        .rx(rx),
       // .baud_tick(baud_tick),
        .LCR(LCR),
	.MDR(MDR),
//	.DLL(DLL),
//	.DLH(DLH),
        .data_out(rx_data),
        .data_valid(rx_valid),
        .parity_err(pe),
        .framing_err(fe),
        .break_int(bi)
    );

logic [WIDTH-1:0] rx_data_sync;
lcr #(.WIDTH(REG_WIDTH)) dut_rxdata (
        .pclk     (bclk),
        .rst_n    (rst_n),
        .data_in  (rx_data),
        .clk      (clk_w),
        .data_out (rx_data_sync)
    );

logic data_valid1;
   ndff_sync u_sync_data_valid (
        .pclk     (clk_w),
        .rst_n    (rst_n),
        .data_in  (rx_valid),
        .data_out (data_valid1)
    );


    //   logic fifo_rd;
     logic rx_empty1;
    logic [WIDTH-1:0] fifo_data1;




    rx_async_fifo #(
    
    .DEPTH      (DEPTH),
    .REG_WIDTH (REG_WIDTH) 
    //.ADDR_WIDTH (ADDR_WIDTH)
  )  fifo (
        .clk_w(clk_w),
	.clk_r(clk_r),
        .rst_n(rst_n),
        .write_enable(data_valid1),
        .data_in(rx_data_sync),
	.data_rd_en(data_rd_en),
        .data_out(fifo_data1),
        .rx_empty(rx_empty1),
       // .rx_full(rx_full1),
	.overrun_err(oe1),
	.FCR1(FCR1)
//	.LCR(LCR),
//	.LSR(LSR)
    );

rbr  #(
    .WIDTH (WIDTH), 
    .REG_WIDTH (REG_WIDTH) 
  ) rbr (
         .clk_w(clk_w),
	.clk_r(clk_r),
        .rst_n(rst_n),
        .write_enable(data_valid1),
        .data_in(rx_data_sync),
	.data_rd_en(data_rd_en),
        .rbr_data_out(rbr_data),
        .rbr_empty(rbr_empty), 
      //  .rbr_full(rbr_full), 
	.overrun_err(oe2),

	.FCR1(FCR1)
//	.LCR(LCR),
//	.LSR(LSR)
    );
/*logic FCR_SYNC;
   ndff_sync u_sync_fcr0 (
        .pclk     (clk_r),
        .rst_n    (rst_n),
        .data_in  (FCR[0]),
        .data_out (FCR_SYNC)
    );
*/

assign rdata  = (FCR_SYNC) ? fifo_data1 : rbr_data;
assign rx_empty = (FCR_SYNC) ? rx_empty1    : rbr_empty; 
//assign rx_full = (FCR_REG[0]) ? rx_full1    : rbr_full; 
assign oe = (FCR_SYNC) ? oe1    : oe2; 

  /*  uart_rx_regs regs (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wdata(wdata),
        .rdata(rdata),

        .fifo_data(fifo_data),
        .rx_empty(rx_empty),
        .rx_full(rx_full),
        .parity_err(pe),
        .framing_err(fe),
        .break_int(bi),

        .fifo_rd(fifo_rd),

        .LCR(LCR), 
        .LSR(LSR), 
        .FCR(FCR),
        .DLL(DLL),
        .DLH(DLH)
    );
*/
endmodule



