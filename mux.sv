module mux #(
  parameter WIDTH = 8
)(
  input  logic              sel,
  input  logic [WIDTH-1:0]  thr_data_out,
  input  logic              thr_empty,

  input  logic [WIDTH-1:0]  fifo_data_out,
  input  logic              fifo_empty,

  input  logic              tsr_ready,

  output logic              tsr_ready_thr,
  output logic              tsr_ready_fifo,
  output logic [WIDTH-1:0]  tsr_data_out,
  output logic              tsr_empty

);

  always_comb begin
    tsr_ready_thr  = 1'b0;
    tsr_ready_fifo = 1'b0;
    tsr_data_out   = {WIDTH{1'b0}};
    tsr_empty      = 1'b1;

     case (sel)

      1'b0 : begin
        tsr_data_out   = thr_data_out;
        tsr_empty      = thr_empty;
        tsr_ready_thr  = tsr_ready;
        tsr_ready_fifo = 1'b0;        
      end

      1'b1 : begin
        tsr_data_out   = fifo_data_out;
        tsr_empty      = fifo_empty;
        tsr_ready_thr  = 1'b0;        
        tsr_ready_fifo = tsr_ready;
      end

      default : begin
        tsr_ready_thr  = 1'b0;
        tsr_ready_fifo = 1'b0;
        tsr_data_out   = {WIDTH{1'b0}};
        tsr_empty      = 1'b1;
      end

    endcase
  end

endmodule
