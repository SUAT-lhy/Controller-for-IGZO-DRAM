module act_regfile (
    input  wire        clk,
    input  wire [9:0]  waddr,
    input  wire [7:0]  wdata,
    input  wire        wen,
    input  wire [9:0]  raddr,
    output wire [7:0]  rdata,
    input  wire [9:0]  spi_raddr,
    output reg  [7:0]  spi_rdata
);
    reg [7:0] mem [0:1023];
    integer ii;
    initial begin
        for(ii=0;ii<1024;ii=ii+1) mem[ii]=8'd0;
    end
    always @(posedge clk) begin
        if (wen) mem[waddr] <= wdata;
        spi_rdata <= mem[spi_raddr];
    end
    assign rdata = mem[raddr];
endmodule
