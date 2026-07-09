import uart_test_pkg::*;
interface apb_intf(input clk,rst);

    logic psel;						  //psel input which helps to select the particular slave
	logic pwrite;
	logic penable;					  //input enable enables the access phase.
	logic [ADDR_WIDTH-1:0]paddr;	  //address input
	logic [DATA_WIDTH-1:0]pwdata;	  //write data input
	
	logic pslverr;				  //pslverr is 1 when address is out off range for the slave
	logic pready;				  //handshaking single 
	logic [OUT_WIDTH-1:0]prdata;


    // Driver clocking Block
    clocking drv_cb @(posedge clk);
        default input #1 output #0;
        input pslverr;
        input pready;
        input prdata;
        output psel;
        output pwrite;
        output penable;
        output paddr;
        output pwdata;
    endclocking


    // Monitor Clocking block
    clocking mon_cb @(posedge clk);
        default input #0;
        input pslverr;
        input pready;
        input prdata;
        input psel;
        input pwrite;
        input penable;
        input paddr;
        input pwdata;


    endclocking

    // modports

    modport DRV (clocking drv_cb, input clk, rst);
    modport MON (clocking mon_cb, input clk, rst); 

endinterface
