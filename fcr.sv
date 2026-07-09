module fcr #(
    parameter WIDTH = 8
)(
    input  logic               pclk,
    input  logic               rst_n,
    input  logic [WIDTH-1:0]   data_in,
    input  logic               clk,
    output logic [WIDTH-1:0]   data_out
);

    // -----------------------------------------------------------------
    // gray_data : named exactly as the TCL expects
    //   check_cdc -signal_config -add_gray_code {dut_fcr1.gray_data}
    // This is the Gray-coded register in pclk domain (stage1).
    // It must be named "gray_data" so the CDC tool can find it.
    // -----------------------------------------------------------------
    logic [WIDTH-1:0] gray_data;    // pclk domain — Gray-coded, this is stage1
    logic [WIDTH-1:0] stage2;       // clk  domain — Gray value after crossing

    // -----------------------------------------------------------------
    // Binary -> Gray  (on input, before storing into gray_data)
    // gray[i] = binary[i] ^ binary[i+1]   ;   gray[MSB] = binary[MSB]
    // -----------------------------------------------------------------
    function automatic [WIDTH-1:0] bin2gray;
        input [WIDTH-1:0] bin;
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction

    // -----------------------------------------------------------------
    // Gray -> Binary  (on output, after crossing into clk domain)
    // binary[MSB] = gray[MSB]
    // binary[i]   = binary[i+1] ^ gray[i]
    // -----------------------------------------------------------------
    function automatic [WIDTH-1:0] gray2bin;
        input [WIDTH-1:0] gray;
        integer j;
        logic [WIDTH-1:0] bin;
        begin
            bin[WIDTH-1] = gray[WIDTH-1];
            for (j = WIDTH-2; j >= 0; j = j - 1)
                bin[j] = bin[j+1] ^ gray[j];
            gray2bin = bin;
        end
    endfunction

    // -----------------------------------------------------------------
    // pclk domain: convert binary input to Gray and store in gray_data
    // TCL: check_cdc -signal_config -add_gray_code {dut_fcr1.gray_data}
    //      will find this signal by name. ?
    // -----------------------------------------------------------------
    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n)
            gray_data <= bin2gray({{(WIDTH-1){1'b0}}, 1'b1});  // gray of 8'b01
        else
            gray_data <= bin2gray(data_in);   // Binary -> Gray before crossing
    end

    // -----------------------------------------------------------------
    // clk domain: capture Gray value from pclk domain
    // Safe CDC: Gray code changes only 1 bit per transition
    // -----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stage2 <= bin2gray({{(WIDTH-1){1'b0}}, 1'b1});
        else
            stage2 <= gray_data;              // Cross domain (Gray — safe)
    end

    // -----------------------------------------------------------------
    // Output: Gray -> Binary decode — same value as data_in, CDC-safe
    // -----------------------------------------------------------------
    assign data_out = gray2bin(stage2);

endmodule
