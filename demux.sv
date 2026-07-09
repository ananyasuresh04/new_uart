module demux #(
  parameter WIDTH = 8
)(
  input  logic              sel,
  input  logic              bus_wr_en,
  input  logic [WIDTH-1:0]  bus_data_in,
  input  logic              thr_empty,
  input  logic              thr_full,
  input  logic              fifo_empty,
  input  logic              fifo_full,

  output logic              bus_empty,
  output logic              bus_full,
  output logic              thr_wr_en,
  output logic              fifo_wr_en,
  output logic [WIDTH-1:0]  thr_data_in,
  output logic [WIDTH-1:0]  fifo_data_in
);

  always_comb begin

    bus_empty    = 1'b0;
    bus_full     = 1'b0;
    thr_wr_en    = 1'b0;
    thr_data_in  = {WIDTH{1'b0}};
    fifo_wr_en   = 1'b0;
    fifo_data_in = {WIDTH{1'b0}};

     case (sel)

      1'b0 : begin
        thr_wr_en    = bus_wr_en;
        thr_data_in  = bus_data_in;
        bus_empty    = thr_empty;
        bus_full     = thr_full;         
      end

      1'b1 : begin
        fifo_wr_en   = bus_wr_en;
        fifo_data_in = bus_data_in;
        bus_empty    = fifo_empty;
        bus_full     = fifo_full;
      end

      default : begin
        bus_empty    = 1'b0;
        bus_full     = 1'b0;
        thr_wr_en    = 1'b0;
        thr_data_in  = {WIDTH{1'b0}};
        fifo_wr_en   = 1'b0;
        fifo_data_in = {WIDTH{1'b0}};
      end

    endcase
  end

endmodule
