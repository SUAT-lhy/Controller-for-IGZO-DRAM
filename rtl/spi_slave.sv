// SPI Slave: Mode 0 (CPOL=0,CPHA=0), 8-bit addr + 8-bit data, MSB first
// Write: CSN=0, send 0x00|addr(7:0), send data(7:0)
// Read:  CSN=0, send 0x80|addr(7:0), MISO outputs data on next 8 clocks
module spi_slave (
    input  wire        clk,
    input  wire        rst_n,
    // SPI pads
    input  wire        spi_clk,
    input  wire        spi_csn,
    input  wire        spi_mosi,
    output reg         spi_miso,
    // Register file interface
    output reg  [7:0]  reg_addr,
    output reg  [7:0]  reg_wdata,
    output reg         reg_wen,
    output reg         reg_ren,
    input  wire [7:0]  reg_rdata
);

    // Double-sync SPI signals into clk domain
    reg [2:0] sclk_sr, mosi_sr, csn_sr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sr <= 3'b0; mosi_sr <= 3'b0; csn_sr <= 3'b111;
        end else begin
            sclk_sr <= {sclk_sr[1:0], spi_clk};
            mosi_sr <= {mosi_sr[1:0], spi_mosi};
            csn_sr  <= {csn_sr[1:0],  spi_csn};
        end
    end

    wire sclk_rise = (sclk_sr[2:1] == 2'b01);
    wire sclk_fall = (sclk_sr[2:1] == 2'b10);
    wire mosi_in   = mosi_sr[1];
    wire csn_in    = csn_sr[1];
    wire csn_rise  = (csn_sr[2:1] == 2'b01);

    reg [3:0] bit_cnt;
    reg [7:0] shift_in;
    reg [7:0] shift_out;
    reg       is_read;
    reg       addr_done;
    reg [7:0] addr_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt   <= 4'd0;
            shift_in  <= 8'd0;
            shift_out <= 8'd0;
            is_read   <= 1'b0;
            addr_done <= 1'b0;
            addr_latch <= 8'd0;
            reg_addr  <= 8'd0;
            reg_wdata <= 8'd0;
            reg_wen   <= 1'b0;
            reg_ren   <= 1'b0;
            spi_miso  <= 1'b0;
        end else begin
            reg_wen <= 1'b0;
            reg_ren <= 1'b0;

            if (csn_in) begin
                bit_cnt   <= 4'd0;
                addr_done <= 1'b0;
                is_read   <= 1'b0;
            end else begin
                if (sclk_rise) begin
                    shift_in <= {shift_in[6:0], mosi_in};
                    if (bit_cnt == 4'd7) begin
                        if (!addr_done) begin
                            addr_done  <= 1'b1;
                            is_read    <= shift_in[6]; // MSB after shift = bit7 of incoming
                            addr_latch <= {1'b0, shift_in[5:0], mosi_in};
                            reg_addr   <= {1'b0, shift_in[5:0], mosi_in};
                            if (shift_in[6]) begin // read request
                                reg_ren <= 1'b1;
                            end
                        end else begin
                            if (!is_read) begin
                                reg_wdata <= {shift_in[6:0], mosi_in};
                                reg_wen   <= 1'b1;
                            end
                        end
                        bit_cnt <= 4'd0;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end

                // Load shift_out one cycle after reg_ren
                if (reg_ren) shift_out <= reg_rdata;

                if (sclk_fall) begin
                    if (addr_done && is_read) begin
                        spi_miso  <= shift_out[7];
                        shift_out <= {shift_out[6:0], 1'b0};
                    end
                end
            end
        end
    end
endmodule
