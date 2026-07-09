module lcr #(

    parameter WIDTH = 8
)(
    input  logic               pclk,
    input  logic               rst_n,
    input  logic [WIDTH-1:0]   data_in,
    input  logic               clk,
    output logic [WIDTH-1:0]   data_out
);

   // logic [WIDTH-1:0] reg_data;
    //logic [WIDTH-1:0] gray_data;
    //logic [WIDTH-1:0] reg_data;
    logic [WIDTH-1:0] stage1;
    

//assign gray_data = data_in ^ (data_in >> 1);


    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            stage1   <= {{(WIDTH-1){1'b0}}, 1'b0};
           // data_out <= {{(WIDTH-1){1'b0}}, 1'b0};
        end else begin
            stage1   <= data_in;
           // data_out <= stage1;
        end
    end
	 always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
           // stage1   <= {{(WIDTH-1){1'b0}}, 1'b0};
            data_out <= {{(WIDTH-1){1'b0}}, 1'b0};
        end else begin
           // stage1   <= data_in;
            data_out <= stage1;
        end
    end


endmodule
