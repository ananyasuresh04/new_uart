module tb_top;
 parameter ADDR_WIDTH = 8;
	 parameter WIDTH      = 8;
		parameter REG_WIDTH=8;

  parameter CLK_FREQ   = 50_000_000;
  parameter BAUD_RATE  = 115200;
  parameter CLK_PERIOD = 10;
 // parameter DLL_VAL    = 8'd27;
  parameter FRAME_WAIT = (CLK_FREQ / BAUD_RATE) * 10 * 6;

  // DUT ports
  logic        pclk;
  logic        presetn;
  logic [7:0]  paddr;
  logic        psel;
  logic        penable;
  logic       pwrite;
  logic [7:0]  pwdata;
  logic        rx;
   logic        tx_out;
  logic [31:0]  r_data;
  logic        pready;
  logic        pslverr;

  // DUT
  uart_top #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE),
 .REG_WIDTH  (REG_WIDTH), 
.WIDTH(WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH)

  ) dut (
    .pclk    (pclk),    .presetn (presetn),
    .paddr   (paddr),   .psel    (psel),
    .penable (penable), .pwrite  (pwrite),
    .pwdata  (pwdata),  .rx      (rx),
    .tx_out  (tx_out),  .prdata  (r_data),
    .pready  (pready),  .pslverr (pslverr)
  );

  // Loopback: tx_out --> rx
  assign rx = tx_out;

  // Clock
  initial begin
 pclk = 1'b0;
presetn =1'b0;	@(posedge pclk); 
paddr ='0;
	psel =0;
	penable =0;
	pwrite =0;
//rx=0;
pwdata ='0;	
end
  always  #(CLK_PERIOD/2) pclk = ~pclk;
//#10;


initial begin
#10; 
	presetn = 1'b1;
	psel =1;
	penable =1;
	pwrite =1;

//	#200;
	//@(posedge pclk);
	paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h34; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01; 
	@(posedge pclk); 
	paddr = 8'hc; pwdata = 8'h07; 
	@(posedge pclk); 
//	paddr = 8'h14; pwdata = 8'ha5; 
//	@(posedge pclk); 
	paddr = 8'h20; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h24; pwdata = 9'h1c2; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hba; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hca; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hda; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hea; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hfa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	//@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hbc; 
//pwrite ='1;
#154000;
pwrite =1;
@(posedge pclk);
paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h34; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01; 
	@(posedge pclk); 
	paddr = 8'hc; pwdata = 8'h07; 
	@(posedge pclk); 
//	paddr = 8'h14; pwdata = 8'ha5; 
//	@(posedge pclk); 
	paddr = 8'h20; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h24; pwdata = 9'h1c2; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hba; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hca; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hda; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hea; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hfa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	//@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hbc;
#154000; 
pwrite =0;
//#154000;
#82300;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#51830;
	@(posedge pclk); 
	paddr = 8'h14;
	@(posedge pclk); 
	paddr = 8'h00;
#1540000;
pwrite =1;
@(posedge pclk);
paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h34; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01; 
	@(posedge pclk); 
	paddr = 8'hc; pwdata = 8'h07; 
	@(posedge pclk); 
//	paddr = 8'h14; pwdata = 8'ha5; 
//	@(posedge pclk); 
	paddr = 8'h20; pwdata = 8'h00; 
	@(posedge pclk); 
	paddr = 8'h24; pwdata = 9'h1c2; 
	@(posedge pclk); 
	paddr = 8'h8; pwdata = 8'h01;
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hba; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hca; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hda; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hea; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hfa; 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'ha; 
	@(posedge pclk); 
	@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'haa; 
	@(posedge pclk); 
	//@(posedge pclk); 
	paddr = 8'h0; pwdata = 8'hbc;
#154000; 
pwrite =0;

/*
//initial begin 
//#40;
rx=0; 
#4320;
rx=1; 
#4320;
rx=0; 
#4320;
rx=1; 
#4320;
rx=0; 
#4320;
rx=1; 
#4320;
rx=1; 
#4320;


pwrite ='0;
#4320;
pwrite ='1;
rx=0; 
#4320;
rx=1; 
#4320;
rx=1; 
#4320;
rx=0; 
#4320;
rx=1; 
#4320;
rx=1; 
#4320;
rx=1; 
#4320;
rx=0; 
#4320;
pwrite ='0;

*/


 #5000000;
        $finish;

end
 
  // Waveform dump
initial begin
$shm_open("wave.shm");
$shm_probe("ACTMF");
end
  
 endmodule
