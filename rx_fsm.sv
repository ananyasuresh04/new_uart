module rx_fsm #(
  parameter WIDTH      = 8, 
  parameter REG_WIDTH  = 8 
 ) (
   // input  logic clk,
    input  logic bclk,
    input  logic rst_n,
    input  logic rx,
    input  logic [REG_WIDTH-1:0] LCR,
    input  logic MDR,
   // input  logic [REG_WIDTH-1:0]DLL,
   // input  logic [REG_WIDTH-1:0]DLH,
    output logic [WIDTH-1:0] data_out,
    output logic data_valid,
    output logic parity_err,
    output logic framing_err,
    output logic break_int
);

    typedef enum {IDLE, START, DATA, PARITY, STOP, WAIT_STATE} state_t;
    state_t state;

    logic [3:0] bit_cnt;
    logic [WIDTH-1:0] shift_reg;
    logic [1:0] stop_reg1, stop_reg;
    logic [1:0] stop_cnt;
    logic parity_calc;
 

   logic [3:0] data_bits;
    logic [4:0] stop_bits;
  	logic break_int1;

  
    always_comb begin
        case (LCR[1:0])
            2'b00: data_bits = 4'd5;
            2'b01: data_bits = 4'd6;
            2'b10: data_bits = 4'd7;
            2'b11: data_bits = 4'd8;
            default: data_bits = 4'd8;
        endcase
    end

    always_comb begin
        if (LCR[2]) begin
            case (LCR[1:0])
                2'b00: stop_bits = MDR ? 5'd18 :5'd23;
                2'b01: stop_bits = MDR ? 5'd25 : 5'd31;
                2'b10: stop_bits = MDR ? 5'd25 :5'd31;
                2'b11: stop_bits = MDR ? 5'd25 :5'd31;
                default: stop_bits = 5'd12;
            endcase
        end else begin
            stop_bits = MDR ? 5'd12 : 5'd15;
        end
    end
logic [4:0]sample_cnt;
 always_ff @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt  <= 5'd0;
            end
	 else if (MDR == 1'b0 && state != STOP) begin
            if (sample_cnt == 5'd15) begin
                sample_cnt <= 5'd0;
             end 
	    else 
		sample_cnt  <= sample_cnt + 5'd1;
	end
	 else if (MDR == 1'b1 && state != STOP ) begin

            if (sample_cnt == 5'd12) begin
                sample_cnt <= 5'd0;
             end 
	    else 
		sample_cnt  <= sample_cnt + 5'd1;
	end
	else
            sample_cnt  <= sample_cnt;
	

  end 

logic [4:0]sample_cnt1;
 always_ff @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt1  <= 5'd0;
            end
	 else if (MDR == 1'b0 && state == STOP) begin
            if (sample_cnt1 == 5'd31) begin
                sample_cnt1 <= 5'd0;
             end 
	    else 
		sample_cnt1  <= sample_cnt1 + 5'd1;
	end
	 else if (MDR == 1'b1 && state == STOP ) begin

            if (sample_cnt1 == 5'd26) begin
                sample_cnt1 <= 5'd0;
             end 
	    else 
		sample_cnt1  <= sample_cnt1 + 5'd1;
	end
	else
            sample_cnt1  <= 5'd0;
	

  end 

    always_ff @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= START;
            data_valid  <= '0;
            parity_err  <= '0;
            shift_reg   <= '0;
            framing_err <= '0;
            break_int   <= '0;
            data_out    <= '0;
           // stop_reg    <= '0;
            bit_cnt     <= '0;
            stop_cnt    <= '0;
            parity_calc <= '0;
		 break_int1 <= '0;
		
          //  expected    <= '0;
        end else begin
           // data_valid <= data_valid;

            case (state)

                START: begin
			if(sample_cnt== 5'd2) data_valid<='0;
                    if (rx == 1'b0) begin
		
			if( sample_cnt==5'd2)begin
                        state       <= DATA;
                        bit_cnt     <= '0;
                        stop_cnt    <= '0;
                        shift_reg   <= '0;
                      //  stop_reg    <= '0;
                        data_out    <= '0;
                        data_valid  <= '0;
                        parity_calc <= '0;
                        framing_err <= '0;                        
		        break_int <= '0;
		        break_int1 <= '0;
			end
                    end else begin
                        state <= START;
                    end
                end

                DATA: begin
                    if (data_bits == 4'd5 && (sample_cnt ==5'd2))
                        shift_reg <= {3'b000, rx, shift_reg[4:1]};
                    else if (data_bits == 4'd6 && (sample_cnt ==5'd2))
                        shift_reg <= {2'b00, rx, shift_reg[5:1]};
                    else if (data_bits == 4'd7 && (sample_cnt ==5'd2))
                        shift_reg <= {1'b0, rx, shift_reg[6:1]};
		     else if(data_bits == 4'd8 && (sample_cnt ==5'd2))
                        shift_reg <= {rx, shift_reg[7:1]};

                    else
                        shift_reg <= shift_reg;

                    if ((sample_cnt ==5'd2 ))
                        parity_calc <= parity_calc ^ rx;
		  if(sample_cnt ==5'd2 )
                    bit_cnt <= bit_cnt + 4'b01;

                    if (bit_cnt == data_bits-4'b01  && (sample_cnt ==5'd2))begin
			if(LCR[3]) begin
				state<= PARITY;
				break_int1 <='0;
			end
			else begin
                        	state <= STOP;
				break_int1 <='1;
			end
			end
                    else
                        state <= DATA;
                end

                PARITY: begin
                    if (LCR[5] && sample_cnt ==5'd2)
                        parity_err <= (LCR[4])? (rx!=1'b0) : (rx !=1'b1);

                    else begin
			if(sample_cnt==5'd2)
                        parity_err <= (LCR[4]) ? (rx!=parity_calc) : (rx==parity_calc);
			end
		    if((sample_cnt ==5'd2 )) begin
                    break_int1 <= rx ?'0:'1;
                    state      <= STOP;
		    end
                end

                STOP: begin
		   if((sample_cnt1 ==stop_bits )) begin
                 
                   parity_err  <= 1'b0;
                   data_out    <= '0;
                    data_valid  <= '0;
		   end
		if ((!MDR && sample_cnt1 == 5'd0) ||
        ( MDR && sample_cnt1 == 5'd0))
    begin
        framing_err <= ~rx;
    end

                    if (sample_cnt1 == stop_bits )begin 
		//	framing_err <= framing_err1;

			if(stop_reg ==2'b00 || stop_reg ==2'b10)begin
			state 	<= WAIT_STATE;
			 data_out   <= shift_reg;
			data_valid <= '1;
			 break_int  <= break_int1 ? (shift_reg == '0 && !rx && break_int1) :(shift_reg == '0 && !rx ) ;
			end

			else begin
                        state      <= START;
                        break_int  <= (shift_reg == '0 && !rx && break_int1) ;
                        data_out   <= shift_reg;
                        data_valid <= '1;

                    end
		end
			else begin
			data_valid <= data_valid;
			state       <= STOP;
			end

                end
		WAIT_STATE: begin
			if(rx) begin 
			    state <= START;
				if(sample_cnt== 5'd2) data_valid<='0;
				end
			else begin
			    state <= WAIT_STATE;
			if(sample_cnt== 5'd2) data_valid<='0;
				end
			end

                default: begin
                    state       <= START;
                    break_int   <= '0;
                    data_out    <= '0;
                    data_valid  <= '0;
                    parity_err  <= '0;
                    framing_err <= '0;
                end

            endcase
        end
    end
assign stop_reg1 = ({stop_reg[0], rx});

always_comb begin
stop_reg='0;
if (state == STOP) begin

	if(sample_cnt1==5'd0)
	 stop_reg =stop_reg1;
	else
	   stop_reg = stop_reg;

	
   end
else begin
  stop_reg ='0;
end

end



endmodule

