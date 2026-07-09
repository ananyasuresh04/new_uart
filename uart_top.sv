
`timescale 1ns/1ps

module uart_top #(
		parameter CLK_FREQ = 50_000_000,
		parameter BAUD_RATE  = 115200,
		 parameter WIDTH      = 8,
		parameter  OUT_WIDTH =32,
		parameter REG_WIDTH=8,
 		 parameter DEPTH      = 16,
		  parameter ADDR_WIDTH = 8
)
(

  input  logic                      pclk,         
  input  logic                      presetn,
  input  logic [ADDR_WIDTH-1:0]     paddr,
  input  logic                      psel,
  input  logic                      penable,
  input  logic                      pwrite,
  input  logic [WIDTH-1:0]	    pwdata,


    input  logic   		rx,
     output logic 		tx_out,
    output logic [OUT_WIDTH-1:0] 	prdata,
    output logic                pready,
    output logic                pslverr

);

             
         // RX Top Outputs
         logic pe, fe, bi, oe;
	 logic rx_empty;
	//  logic [WIDTH-1:0] rdata;  
	  logic [WIDTH-1:0] r_data;  
	  logic [WIDTH-1:0] data_in; 
 logic              tx_full;
//logic             	tx_empty;


logic rx1;
logic data_wr_en; 
logic data_rd_en; 
logic [REG_WIDTH-1:0] LCR_OUT;
logic [REG_WIDTH-1:0] LCR_OUT1;

logic [REG_WIDTH-1:0] FCR_OUT ; 
logic [REG_WIDTH-1:0] FCR_OUT1 ; 
logic [REG_WIDTH-1:0] DLL_OUT;
logic [REG_WIDTH-1:0] DLH_OUT;
logic [REG_WIDTH-1:0] MDR_OUT; 
//logic [REG_WIDTH:0] LSR;
//logic [REG_WIDTH-1:0] THR;      

//logic [REG_WIDTH-1:0] fcr_out;
logic [REG_WIDTH-1:0] fcr_out2;
logic [REG_WIDTH-1:0] lcr_out2;
  logic             tsr_shift; 
  logic             tsr_empty; 
logic baud_tick;
logic rx_baud_clk;
logic bclk;


logic MDR_SYNC;
   ndff_sync u_sync_mdr (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (MDR_OUT[0]),
        .data_out (MDR_SYNC)
    );
 

    ndff_sync1 rxx (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (rx),
        .data_out (rx1)
    );


logic [1:0]wls;
logic wls1;
logic wls2;
ndff_sync u_sync_tx_wls (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[0]),
        .data_out (wls1)
    );
ndff_sync u_sync_tx_wls2 (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[1]),
        .data_out (wls2)
    );
assign wls = {wls2,wls1};
logic pen;
ndff_sync u_sync_tx_pen (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[3]),
        .data_out (pen)
    );
logic eps;
ndff_sync u_sync_tx_eps (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[4]),
        .data_out (eps)
    );
logic sp;
ndff_sync u_sync_tx_sp (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[5]),
        .data_out (sp)
    );

logic stb;
ndff_sync u_sync_tx_stb (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[2]),
        .data_out (stb)
    );
logic break_control;
 ndff_sync u_sync_break_con (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT[6]),
        .data_out (break_control)
    );

logic tx_clr;
 ndff_sync u_sync_tx_clr (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (FCR_OUT[2]),
        .data_out (tx_clr)
    );
logic fifo_mode;
 ndff_sync u_sync_fifo_mode (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (FCR_OUT[0]),
        .data_out (fifo_mode)
    );



 tx_top #(
    .WIDTH      (WIDTH),
    .DEPTH      (DEPTH),
    .REG_WIDTH  (REG_WIDTH), 
    .ADDR_WIDTH (ADDR_WIDTH)
  ) u_uart_top (
    .clk_w      (pclk),
    .clk_r         (baud_tick),
    .bclk       (bclk),
    .rst_n       (presetn),
    .break_control (break_control),
    .mdr         (MDR_SYNC),
    .sel         (fifo_mode),
    .bus_data_in (data_in),
    .bus_wr_en   (data_wr_en),
    .tx_clr      (tx_clr),
    .wls         (wls),
    .pen         (pen),
    .eps         (eps),
    .sp          (sp),
    .stb         (stb),
    //.THR(THR),
    .bus_full    (tx_full),
  //  .bus_empty   (tx_empty),//
    .tx_out      (tx_out),
    .tsr_shift   (tsr_shift),
    .tsr_empty   (tsr_empty)
  );
logic wls_sync;
 ndff_sync u_sync_wls (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[0]),
        .data_out (wls_sync)
    );
logic wls2_sync;
 ndff_sync u_sync_wls2 (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[1]),
        .data_out (wls2_sync)
    );

logic stb_sync;
 ndff_sync u_sync_stb (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[2]),
        .data_out (stb_sync)
    );
 
logic pen_sync;
 ndff_sync u_sync_pen (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[3]),
        .data_out (pen_sync)
    );
logic eps_sync;
 ndff_sync u_sync_eps (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[4]),
        .data_out (eps_sync)
    );

logic sp_sync;
 ndff_sync u_sync_sp (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[5]),
        .data_out (sp_sync)
    );
logic bc_sync;
 ndff_sync u_sync_bc (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[6]),
        .data_out (bc_sync)
    );
logic dlab_sync;
 ndff_sync u_sync_dlab (
        .pclk     (bclk),
        .rst_n    (presetn),
        .data_in  (LCR_OUT1[7]),
        .data_out (dlab_sync)
    );

assign lcr_out2 = {dlab_sync,bc_sync,sp_sync,eps_sync,pen_sync,stb_sync,wls2_sync,wls_sync};
logic fifo_mode_sync;
 ndff_sync u_sync_fifo_mode1 (
        .pclk     (rx_baud_clk),
        .rst_n    (presetn),
        .data_in  (FCR_OUT1[0]),
        .data_out (fifo_mode_sync)
    );
logic rxclr_sync;
 ndff_sync u_sync_rxclr (
        .pclk     (rx_baud_clk),
        .rst_n    (presetn),
        .data_in  (FCR_OUT1[1]),
        .data_out (rxclr_sync)
    );

//assign fcr_out2 = {{REG_WIDTH-2{1'b0}}, rxclr_sync,fifo_mode_sync};


      // UART RX TOP
   rx_top#(
    .WIDTH      (WIDTH),
    .REG_WIDTH  (REG_WIDTH), 
    .DEPTH      (DEPTH),
    .ADDR_WIDTH (ADDR_WIDTH) 
  ) u_rx_top (
        .clk_w      (rx_baud_clk),
  	.clk_r      (pclk),
	.bclk	(bclk),
        .rst_n (presetn),
        .rx    (rx1),
        .rdata (r_data), 
	.FCR_SYNC(FCR_OUT1[0]) ,
        .LCR   (lcr_out2),
      //  .FCR0   (fifo_mode_sync),
        .FCR1   (rxclr_sync),
	.MDR (MDR_SYNC),
	.data_rd_en (data_rd_en),
        .pe    (pe),
        .fe    (fe),
        .bi    (bi),  
	.oe    (oe),   
	.rx_empty(rx_empty)
	//.rx_full (rx_full) 
    );


logic oe_sync;
 ndff_sync u_sync_oe_sync (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (oe),
        .data_out (oe_sync)
    );


         // UART RX REGS
       regs #(
    .DATA_WIDTH (WIDTH), 
    .ADDR_WIDTH (ADDR_WIDTH), 
    .OUT_WIDTH   (OUT_WIDTH),
    .REG_WIDTH (REG_WIDTH) 
  ) u_regs (
        . pclk      (pclk),
        . presetn   (presetn), 
	. paddr     (paddr),   
	. psel      (psel),    
	. penable   (penable), 
	. pwrite    (pwrite),  
	. pwdata    (pwdata),  
        . prdata    (prdata),  
        . pready    (pready),  
	. pslverr   (pslverr), 
	. tx_full    (tx_full),
	.indata	     (r_data),
	. rx_empty (rx_empty),
      //  . rx_full  (rx_full), 
        . parity_err  (pe),  
        . framing_err (fe),
        . break_int   (bi), 
	.overrun_err   (oe_sync),
        . tsr_empty   (tsr_empty),
	. tsr_shift   (tsr_shift),

	. LCR_OUT  (LCR_OUT), 
	. LCR_OUT1  (LCR_OUT1), 
	. FCR_OUT  (FCR_OUT), 
	. FCR_OUT1  (FCR_OUT1), 
	. DLL_OUT  (DLL_OUT), 
	. DLH_OUT  (DLH_OUT), 
        . MDR_OUT  (MDR_OUT),       
//	. LSR      (LSR),
//	. THR      (THR),         
        . data_wr_en(data_wr_en), 
        . data_rd_en(data_rd_en), 
        .data_in (data_in)


);  
  baud_gen #(
        .CLK_FREQ(CLK_FREQ),
	.REG_WIDTH(REG_WIDTH),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(pclk),
        .rst_n(presetn),
        .MDR(MDR_OUT),
        .DLL(DLL_OUT),
        .DLH(DLH_OUT),
        .bclk(bclk),
        .tx_baud_clk(baud_tick),
	.rx_baud_clk(rx_baud_clk)
    );

endmodule



/*initial begin
$shm_open("wave.shm");
$shm_probe("ACTMF");
end
*/


