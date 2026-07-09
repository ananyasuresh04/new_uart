module ndff_sync (
    input  logic pclk,
    input  logic rst_n,
    input  logic data_in,
    output logic data_out
);

    logic stage1;
    logic stage2;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= '0;
            stage2 <= '0;
        end else begin
            stage1 <= data_in;
            stage2 <= stage1;
        end
    end

    assign data_out = stage2;

endmodule
