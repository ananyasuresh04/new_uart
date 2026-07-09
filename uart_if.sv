interface uart_if (input logic clk, input logic rst);

logic txd;// UART1 transmits  -> slave model receives/monitors
logic rxd;// Slave model drives  ->  UART1 receives

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input txd;
        input rxd;
    endclocking

    modport MON (clocking mon_cb,   input clk, rst);
    
endinterface
