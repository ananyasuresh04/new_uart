module mdr #(
    parameter WIDTH = 8
)(
    input  logic             pclk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_in,
    input  logic             clk,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] stage1;
    logic [WIDTH-1:0] stage2;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) stage1 <= {{(WIDTH-1){1'b0}}, 1'b1};
        else        stage1 <= data_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) stage2 <= {{(WIDTH-1){1'b0}}, 1'b1};
        else        stage2 <= stage1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) data_out <= {{(WIDTH-1){1'b0}}, 1'b1};
        else        data_out <= stage2;
    end
endmodule
