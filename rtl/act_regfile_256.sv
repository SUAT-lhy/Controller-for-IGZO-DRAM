// act_regfile: MVT 256-row version (reduced from 1024)
// Keeps same port interface as 1024-row version for digital_top compatibility
module act_regfile (
    input  wire        clk,
    input  wire [9:0]  waddr,   // only [7:0] used (256 rows)
    input  wire [7:0]  wdata,
    input  wire        wen,
    input  wire [9:0]  raddr,   // only [7:0] used
    output wire [7:0]  rdata,
    input  wire [9:0]  spi_raddr,
    output reg  [7:0]  spi_rdata
);
    reg [7:0] mem [0:255];  // 256x8bit = 2kbit
    integer ii;
    initial begin
        for(ii=0;ii<256;ii=ii+1) mem[ii]=8'd0;
    end
    always @(posedge clk) begin
        if (wen && (waddr[9:8] == 2'b00)) mem[waddr[7:0]] <= wdata;
        spi_rdata <= mem[spi_raddr[7:0]];
    end
    assign rdata = mem[raddr[7:0]];
endmodule
