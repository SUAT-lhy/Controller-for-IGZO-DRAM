// Full RTL testbench - 7 test cases
module tb_full;
    reg clk=0, rst_n=0;
    reg spi_clk=0, spi_csn=1, spi_mosi=0;
    wire spi_miso;
    integer pass_cnt=0, fail_cnt=0;
    reg [7:0] rd_val;
    reg signed [31:0] acc32;
    reg [7:0] ab0,ab1,ab2,ab3;
    integer i;

    digital_top dut(
        .clk(clk),.rst_n(rst_n),
        .spi_clk(spi_clk),.spi_csn(spi_csn),
        .spi_mosi(spi_mosi),.spi_miso(spi_miso),
        .sa_therm(3'b000),.sa_done(0),.scan_in(0)
    );
    always #5 clk=~clk;

    task spi_byte; input [7:0] d; integer k;
        for(k=7;k>=0;k=k-1) begin spi_mosi=d[k];#50;spi_clk=1;#50;spi_clk=0; end
    endtask

    task spi_write; input [7:0] addr,data;
        spi_csn=0;#100;
        spi_byte({1'b0,addr[6:0]});
        spi_byte(data);
        #100;spi_csn=1;#200;
    endtask

    task spi_read; input [7:0] addr; integer k;
        spi_csn=0;#100;
        spi_byte({1'b1,addr[6:0]});
        rd_val=0;
        for(k=7;k>=0;k=k-1) begin #50;spi_clk=1;rd_val[k]=spi_miso;#50;spi_clk=0; end
        #100;spi_csn=1;#200;
    endtask

    task chk8; input [7:0] g,e; input [63:0] m;
        if(g===e) begin pass_cnt=pass_cnt+1;$display("  PASS: %0s=0x%02X",m,g); end
        else begin fail_cnt=fail_cnt+1;$display("  FAIL: %0s got=0x%02X exp=0x%02X",m,g,e); end
    endtask

    task chk32; input signed [31:0] g,e; input [63:0] m;
        if(g===e) begin pass_cnt=pass_cnt+1;$display("  PASS: %0s=%0d",m,g); end
        else begin fail_cnt=fail_cnt+1;$display("  FAIL: %0s got=%0d exp=%0d",m,g,e); end
    endtask

    task read_acc;
        spi_read(8'h20);ab0=rd_val;
        spi_read(8'h21);ab1=rd_val;
        spi_read(8'h22);ab2=rd_val;
        spi_read(8'h23);ab3=rd_val;
        acc32=$signed({{6{ab3[1]}},ab3[1:0],ab2,ab1,ab0});
    endtask

    task soft_reset;
        spi_write(8'h04,8'h01);#200;spi_write(8'h04,8'h00);#200;
    endtask

    task run_mac_bypass; input [7:0] nrows;
        spi_write(8'h04,8'h00);#200;
        spi_write(8'h07,nrows);spi_write(8'h08,8'h00);
        spi_write(8'h05,8'h00);spi_write(8'h06,8'h00);
        spi_write(8'h50,8'h00);spi_write(8'h51,8'h01);
        spi_write(8'h04,8'h90);
        #100000;
    endtask

    initial begin
        #30;rst_n=1;#300;

        $display("TC1: SPI identity");
        spi_read(8'h00);chk8(rd_val,8'hA3,"CHIP_ID");
        spi_read(8'h01);chk8(rd_val,8'h30,"VERSION");
        spi_write(8'h02,8'hA5);spi_read(8'h02);chk8(rd_val,8'hA5,"SCRATCH");

        $display("TC2: all-zero activations -> acc=0");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        for(i=0;i<16;i=i+1) spi_write(8'h42,8'h00);
        run_mac_bypass(16);
        read_acc;chk32(acc32,0,"zero_act");

        $display("TC3: sequential acts 0..15 scale=1 -> sum=120");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        for(i=0;i<16;i=i+1) spi_write(8'h42,i[7:0]);
        run_mac_bypass(16);
        read_acc;chk32(acc32,120,"seq_acts");

        $display("TC4: single row a=42 -> acc=42");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        spi_write(8'h42,8'h2A);
        run_mac_bypass(1);
        read_acc;chk32(acc32,42,"single_row");

        $display("TC5: 4 rows a=1,2,3,4 -> sum=10");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        spi_write(8'h42,8'h01);spi_write(8'h42,8'h02);
        spi_write(8'h42,8'h03);spi_write(8'h42,8'h04);
        run_mac_bypass(4);
        read_acc;chk32(acc32,10,"4row_sum");

        $display("TC6: SPI auto-inc readback 10,20,30,40");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        spi_write(8'h42,8'h0A);spi_write(8'h42,8'h14);
        spi_write(8'h42,8'h1E);spi_write(8'h42,8'h28);
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);
        spi_read(8'h42);chk8(rd_val,8'h0A,"autoinc0");
        spi_read(8'h42);chk8(rd_val,8'h14,"autoinc1");
        spi_read(8'h42);chk8(rd_val,8'h1E,"autoinc2");
        spi_read(8'h42);chk8(rd_val,8'h28,"autoinc3");

        $display("TC7: signed act a=0xFF(-1) x4 scale=1 -> acc=-4");
        soft_reset;
        spi_write(8'h40,8'h00);spi_write(8'h41,8'h00);spi_write(8'h43,8'h01);
        spi_write(8'h42,8'hFF);spi_write(8'h42,8'hFF);
        spi_write(8'h42,8'hFF);spi_write(8'h42,8'hFF);
        run_mac_bypass(4);
        read_acc;chk32(acc32,-4,"signed_act");

        $display("=== DONE: pass=%0d fail=%0d ===",pass_cnt,fail_cnt);
        $finish;
    end
endmodule
