module regs #(
    parameter DATA_WIDTH = 8,
    parameter REG_WIDTH  = 8,
    parameter OUT_WIDTH  = 32,
    parameter ADDR_WIDTH = 8
)(
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [OUT_WIDTH-1:0]  prdata,
    output logic                  pready,
    output logic                  pslverr,

    input  logic [DATA_WIDTH-1:0] indata,
    input  logic                  rx_empty,
   // input  logic                  rx_full,
    input  logic                  parity_err,
    input  logic                  framing_err,
    input  logic                  overrun_err,
    input  logic                  break_int,
    input  logic                  tsr_empty,
    input  logic                  tsr_shift,
    input  logic                  tx_full,

    output logic [REG_WIDTH-1:0]  LCR_OUT,
    output logic [REG_WIDTH-1:0]  LCR_OUT1,
    output logic [REG_WIDTH-1:0]  FCR_OUT,
    output logic [REG_WIDTH-1:0]  FCR_OUT1,
    output logic [REG_WIDTH-1:0]  DLL_OUT,
    output logic [REG_WIDTH-1:0]  DLH_OUT,
    output logic [REG_WIDTH-1:0]  MDR_OUT,
//    output logic [REG_WIDTH  :0]  LSR,
    output logic                  data_wr_en,
    output logic                  data_rd_en,
    output logic [DATA_WIDTH-1:0] data_in
);

    // ----------------------------------------------------------------
    // Address Map
    // ----------------------------------------------------------------
    localparam [ADDR_WIDTH-1:0] ADDR_THR = 8'h00;
    localparam [ADDR_WIDTH-1:0] ADDR_FCR = 8'h08;
    localparam [ADDR_WIDTH-1:0] ADDR_LCR = 8'h0C;
    localparam [ADDR_WIDTH-1:0] ADDR_LSR = 8'h14;
    localparam [ADDR_WIDTH-1:0] ADDR_DLL = 8'h20;
    localparam [ADDR_WIDTH-1:0] ADDR_DLH = 8'h24;
    localparam [ADDR_WIDTH-1:0] ADDR_MDR = 8'h34;
//logic [REG_WIDTH-1:0]  LSR;
    logic [ADDR_WIDTH-1:0] paddr_r;
    logic                  psel_r;
    logic                  penable_r;
   // logic                  penable2;
    logic                  pwrite_r;
    logic [DATA_WIDTH-1:0] pwdata_r;
logic read_en1;
 logic read_en;

logic [REG_WIDTH  :0]  LSR;



    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            paddr_r   <= '0;
            psel_r    <= 1'b0;
            penable_r <= 1'b0;
          //  penable2 <= 1'b0;
            pwrite_r  <= 1'b0;
            pwdata_r  <= '0;
	    read_en1 <= '0;
        end else begin
            paddr_r   <= paddr;
            psel_r    <= psel;
           // penable2 <= penable_r;
            penable_r <= penable;
            pwrite_r  <= pwrite;
            pwdata_r  <= pwdata;
	    read_en1<=read_en;
        end
    end

    // ----------------------------------------------------------------
    // Control Signals — now all derived from registered inputs
    // ----------------------------------------------------------------
    logic write_en;
           logic access_en;

    assign write_en  = psel_r & penable_r &  pwrite_r;
    assign read_en   = psel & penable & ~pwrite;
   // assign read_en1   = psel & ~pwrite & penable2;
    assign access_en = psel_r & penable_r;

    // ----------------------------------------------------------------
    // Synchronized status signals (CDC synchronizers already present)
    // ----------------------------------------------------------------
    logic rx_empty_sync;
  //  logic rx_full_sync;
    logic parity_err_sync;
   // logic overrun_err_sync;
    logic framing_err_sync;
    logic break_int_sync;
    logic tsr_empty_sync;
  //  logic tsr_shift_sync;
    logic tx_full_sync;

    assign pready = (pwrite)? (psel & penable) : (psel_r & penable_r);//~tx_full_sync | ~rx_empty_sync;
   // assign pready = ~tx_full_sync | ~rx_empty_sync;

    // ----------------------------------------------------------------
    // Address Decode — using registered paddr_r
    // ----------------------------------------------------------------
    logic addr_valid;
    logic addr_valid_lsr;

    always_comb begin
        addr_valid     = 1'b0;
        addr_valid_lsr = 1'b0;

        case (paddr_r)
            ADDR_FCR : addr_valid     = 1'b1;
            ADDR_LCR : addr_valid     = 1'b1;
            ADDR_LSR : addr_valid_lsr = 1'b1;
            ADDR_DLL : addr_valid     = 1'b1;
            ADDR_DLH :addr_valid     = 1'b1;
            ADDR_MDR : addr_valid     = 1'b1;
            default  : ;
        endcase
    end

    // ----------------------------------------------------------------
    // Error Logic — using registered paddr_r
    // ----------------------------------------------------------------
    logic invalid_addr;

    assign invalid_addr = access_en && (paddr_r != ADDR_THR) &&
                          ~addr_valid && ~addr_valid_lsr;

    assign pslverr = invalid_addr;

    // ----------------------------------------------------------------
    // Register Declarations
    // ----------------------------------------------------------------
    logic [REG_WIDTH-1:0] reg_FCR;
    logic [REG_WIDTH-1:0] reg_LCR;
    logic [REG_WIDTH-1:0] reg_DLL;
    logic [REG_WIDTH-1:0] reg_DLH;
    logic [REG_WIDTH-1:0] reg_MDR;

    // ----------------------------------------------------------------
    // Register Write Logic — using registered paddr_r and pwdata_r
    // ----------------------------------------------------------------
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_FCR <= {{(REG_WIDTH-1){1'b0}}, 1'b1};
            reg_LCR <= '0;
            reg_DLL <= '0;
            reg_DLH <= '0;
            reg_MDR <= {{(REG_WIDTH-1){1'b0}}, 1'b0};
	   
	    FCR_OUT  <= {{(REG_WIDTH-1){1'b0}}, 1'b1};
    	    FCR_OUT1 <= '0;
    	LCR_OUT  <= '0;
    	LCR_OUT1 <= '0;
   	 DLL_OUT  <= '0;
   	 DLH_OUT  <= '0;
  	  MDR_OUT  <= {{(REG_WIDTH-1){1'b0}}, 1'b0};
        end
        else if (write_en && addr_valid) begin
            case (paddr_r)
              /*  ADDR_FCR : reg_FCR <= pwdata_r;
                ADDR_LCR : reg_LCR <= pwdata_r;
                ADDR_DLL : reg_DLL <= pwdata_r;
                ADDR_DLH : reg_DLH <= pwdata_r;
                ADDR_MDR : reg_MDR <= pwdata_r;*/


		ADDR_FCR :begin
			 FCR_OUT <= pwdata;
			 FCR_OUT1 <= pwdata;
			end
                ADDR_LCR :begin
			 LCR_OUT <= pwdata;
			 LCR_OUT1 <= pwdata;
			end
                ADDR_DLL : begin
			       if(LCR_OUT[7])
				DLL_OUT <= pwdata;
			   end
                ADDR_DLH : begin
			       if(LCR_OUT[7])
				DLH_OUT <= pwdata;
			   end
                ADDR_MDR : MDR_OUT <= pwdata;

                default  : ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // LSR - Line Status Register (combinational, from synced signals)
    // ----------------------------------------------------------------
    always_comb begin
        LSR    = '0;
        LSR[0] = ~rx_empty_sync;
        LSR[1] =  overrun_err;
        LSR[2] =  parity_err_sync;
        LSR[3] =  framing_err_sync;
        LSR[4] =  break_int_sync;
        LSR[5] = tsr_empty;;
        LSR[6] =  tsr_empty & ~tsr_shift;
        LSR[7] =  parity_err_sync | framing_err_sync | break_int_sync;
        LSR[8] = ~tx_full;
    end
    // ----------------------------------------------------------------
   //////////////////////////////////////////////////////////////////////////////////rx
 always_comb begin
     if(read_en && paddr==8'h14)begin
		
            prdata = {{(OUT_WIDTH - REG_WIDTH-1){1'b0}}, LSR};
          //  enable = 1;

	  end
	else if (read_en1 && paddr==8'h00) begin //if(data_rd_en && paddr=='0 )begin
	     prdata ={{(OUT_WIDTH - DATA_WIDTH){1'b0}}, indata};
			end
	else 
		prdata ='0; //prdata;

	
//end
end

    // ----------------------------------------------------------------
    // Data Path Controls — using registered paddr_r and pwdata_r
    // ----------------------------------------------------------------
    assign data_wr_en = (write_en & (paddr_r == ADDR_THR)) ? '1 : '0;
    assign data_rd_en = ((read_en && paddr == ADDR_THR))       ? '1 : '0;
    assign data_in    = (paddr_r  == ADDR_THR) ? pwdata_r  : '0;

    // ----------------------------------------------------------------
    // Output Assignments
    // ----------------------------------------------------------------
 /*   assign FCR_OUT = reg_FCR;
    assign LCR_OUT = reg_LCR;
    assign DLL_OUT = reg_DLL;
    assign DLH_OUT = reg_DLH;
    assign MDR_OUT = reg_MDR;
*/
    // ----------------------------------------------------------------
    // 2-FF Synchronizers for all baud_tick-domain status signals
    // ----------------------------------------------------------------
    ndff_sync u_sync_rx_empty (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (rx_empty),
        .data_out (rx_empty_sync)
    );

  
    ndff_sync u_sync_parity_err (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (parity_err),
        .data_out (parity_err_sync)
    );

    ndff_sync u_sync_framing_err (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (framing_err),
        .data_out (framing_err_sync)
    );
/* ndff_sync u_sync_overrun_err (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (overrun_err),
        .data_out (overrun_err_sync)
    );*/

    ndff_sync u_sync_break_int (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (break_int),
        .data_out (break_int_sync)
    );

    ndff_sync u_sync_tsr_empty (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (tsr_empty),
        .data_out (tsr_empty_sync)
    );

   /* ndff_sync u_sync_tsr_shift (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (tsr_shift),
        .data_out (tsr_shift_sync)
    );*/

    ndff_sync u_sync_tx_full (
        .pclk     (pclk),
        .rst_n    (presetn),
        .data_in  (tx_full),
        .data_out (tx_full_sync)
    );

endmodule



