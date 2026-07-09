module baud_gen #(
    parameter logic unsigned [31:0] CLK_FREQ  = 50_000_000,
    parameter logic unsigned [31:0] BAUD_RATE = 115200,
    parameter                       REG_WIDTH = 8
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [REG_WIDTH-1:0] MDR,
    input  logic [REG_WIDTH-1:0] DLL,
    input  logic [REG_WIDTH-1:0] DLH,
    //input  logic [REG_WIDTH-1:0] LCR,
    output logic        bclk,

    output logic                 rx_baud_clk,
    output logic                 tx_baud_clk
);


    logic [15:0] divisior;
  
assign divisior = {DLH,DLL};  
    logic [15:0] bclk_cnt;
//    logic        bclk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_cnt <= '0;
            bclk     <= 1'b0;
        end else begin
            if (bclk_cnt == '0) begin
                bclk_cnt <= bclk_cnt + 16'b01;
                bclk     <= 1'b1;
            end 
	   else begin
		if(divisior=='0)begin
			bclk_cnt<= '0;
			 bclk     <= 1'b0;

		end
		else if(bclk_cnt==divisior-16'b1)begin
			bclk_cnt<= '0;
			 bclk     <= 1'b0;

		end

		else begin
                bclk_cnt <= bclk_cnt + 16'b01;
                bclk     <= 1'b0;
		end
            end
        end
    end

logic MDR_SYNC;
   ndff_sync u_sync_mdr (
        .pclk     (bclk),
        .rst_n    (rst_n),
        .data_in  (MDR[0]),
        .data_out (MDR_SYNC)
    );
 


    logic [4:0] sample_cnt;

    always_ff @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt  <= 5'd0;
            tx_baud_clk <= 1'b0;
            rx_baud_clk <= 1'b0;

        // --------------------------------------------------------------
        // Oversample = 16  (MDR[0] == 0)
        // --------------------------------------------------------------
        end else if (MDR_SYNC == 1'b0) begin
            if (sample_cnt == 5'd0) begin
                tx_baud_clk <= 1'b1;
                sample_cnt  <= sample_cnt + 5'd1;
            end else if (sample_cnt <= 5'd6) begin
                tx_baud_clk <= tx_baud_clk;
                rx_baud_clk <= rx_baud_clk;
                sample_cnt  <= sample_cnt + 5'd1;
            end else if (sample_cnt == 5'd7) begin
                tx_baud_clk <= tx_baud_clk;
                rx_baud_clk <= ~rx_baud_clk;
                sample_cnt  <= sample_cnt + 5'd1;
            end else begin   // sample_cnt >= 8
                rx_baud_clk <= rx_baud_clk;
                if (sample_cnt == 5'd8)
                    tx_baud_clk <= ~tx_baud_clk;
                else
                    tx_baud_clk <= tx_baud_clk;

                if (sample_cnt == 5'd16) begin
                    sample_cnt  <= 5'd1;
                    tx_baud_clk <= 1'b1;
                    rx_baud_clk <= 1'b0;
                end else begin
                    sample_cnt  <= sample_cnt + 5'd1;
                end
            end

        // --------------------------------------------------------------
        // Oversample = 13  (MDR[0] == 1)
        // --------------------------------------------------------------
        end else begin
            if (sample_cnt == 5'd0) begin
                tx_baud_clk <= 1'b1;
                sample_cnt  <= sample_cnt + 5'd1;
            end else if (sample_cnt <= 5'd5) begin
                tx_baud_clk <= tx_baud_clk;
                rx_baud_clk <= rx_baud_clk;
                sample_cnt  <= sample_cnt + 5'd1;
            end else if (sample_cnt == 5'd6) begin
                tx_baud_clk <= tx_baud_clk;
                rx_baud_clk <= ~rx_baud_clk;
                sample_cnt  <= sample_cnt + 5'd1;
            end else begin   // sample_cnt >= 7
                rx_baud_clk <= rx_baud_clk;
                if (sample_cnt == 5'd7)
                    tx_baud_clk <= ~tx_baud_clk;
                else
                    tx_baud_clk <= tx_baud_clk;

                if (sample_cnt == 5'd13) begin
                    sample_cnt  <= 5'd1;
                    tx_baud_clk <= 1'b1;
                    rx_baud_clk <= 1'b0;
                end else begin
                    sample_cnt  <= sample_cnt + 5'd1;
                end
            end
        end
    end

endmodule
