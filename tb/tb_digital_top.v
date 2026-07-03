// digital_top testbench: Level0 SPI ID check + Level1 MAC bypass
module tb_digital_top;
    reg clk=0, rst_n=0;
    reg spi_clk=0, spi_csn=1, spi_mosi=0;
    wire spi_miso;
    integer pass_cnt=0, fail_cnt=0;

    digital_top dut(
        .clk(clk), .rst_n(rst_n),
        .spi_clk(spi_clk), .spi_csn(spi_csn),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .sa_therm(3'b000), .sa_done(0),
        .scan_in(0)
    );

    always #5 clk=~clk;  // 100MHz system clk

    task spi_byte(input [7:0] d);
        integer k;
        for(k=7;k>=0;k=k-1) begin
            spi_mosi=d[k]; #50; spi_clk=1; #50; spi_clk=0;
        end
    endtask

    task spi_write(input [7:0] addr, data);
        spi_csn=0; #100;
        spi_byte({1'b0,addr[6:0]});  // write: MSB=0
        spi_byte(data);
        #100; spi_csn=1; #200;
    endtask

    reg [7:0] rd_val;
    task spi_read(input [7:0] addr);
        integer k;
        spi_csn=0; #100;
        spi_byte({1'b1,addr[6:0]});  // read: MSB=1
        rd_val=0;
        for(k=7;k>=0;k=k-1) begin
            #50; spi_clk=1; rd_val[k]=spi_miso; #50; spi_clk=0;
        end
        #100; spi_csn=1; #200;
    endtask

    task check(input [7:0] got, exp, input [63:0] msg);
        if(got===exp) begin
            pass_cnt=pass_cnt+1;
            $display("  PASS: %0s  got=0x%02X",msg,got);
        end else begin
            fail_cnt=fail_cnt+1;
            $display("  FAIL: %0s  got=0x%02X exp=0x%02X",msg,got,exp);
        end
    endtask

    integer i;
    reg [7:0] acc_b0,acc_b1,acc_b2,acc_b3;
    reg signed [31:0] acc32;

    initial begin
        $dumpfile("/root/autodl-tmp/ic_design/digital/sim/tb_top.vcd");
        $dumpvars(0, tb_digital_top);
        #30; rst_n=1; #100;

        $display("=== Level 0: SPI identity ===");
        spi_read(8'h00); check(rd_val,8'hA3,"CHIP_ID");
        spi_read(8'h01); check(rd_val,8'h30,"VERSION");
        spi_write(8'h02,8'hA5);
        spi_read(8'h02); check(rd_val,8'hA5,"SCRATCH");

        $display("=== Level 1: MAC bypass ===");
        spi_write(8'h50,8'h00);  // SCALE_MODE=per-layer
        spi_write(8'h51,8'h10);  // SCALE_W_G0=16
        spi_write(8'h04,8'h02);  // act_load_mode=1 (enable activation load)
        // Load 16 activations: a[i]=i (0..15)
        spi_write(8'h40,8'h00);  // ACT_ADDR_L=0
        spi_write(8'h41,8'h00);  // ACT_ADDR_H=0
        spi_write(8'h43,8'h01);  // auto_inc=1
        for(i=0;i<16;i=i+1) spi_write(8'h42,i);

        // Set n_rows=16, row_addr=0
        spi_write(8'h07,8'h10);  // N_ROWS_L=16
        spi_write(8'h08,8'h00);  // N_ROWS_H=0
        spi_write(8'h05,8'h00);  // ROW_ADDR_L=0
        spi_write(8'h06,8'h00);  // ROW_ADDR_H=0

        // Start MAC (bypass_sa=1 -> w8=1, so acc = sum(a[i]) for i=0..15)
        // Expected: 0+1+2+...+15 = 120
        spi_write(8'h04,8'h90);  // start=1, bypass_sa=1, act_load_mode=0
        #5000;  // wait for completion
        spi_read(8'h10);
        $display("  STATUS=0x%02X (mac_done=%b)", rd_val, rd_val[7]);

        spi_read(8'h20); acc_b0=rd_val;
        spi_read(8'h21); acc_b1=rd_val;
        spi_read(8'h22); acc_b2=rd_val;
        spi_read(8'h23); acc_b3=rd_val;
        acc32 = $signed({{6{acc_b3[1]}}, acc_b3[1:0], acc_b2, acc_b1, acc_b0});
        $display("  ACC=%0d (expected=120 for bypass w8=1, a=0..15)", acc32);
        if(acc32===120) begin pass_cnt=pass_cnt+1; $display("  PASS: MAC result"); end
        else begin fail_cnt=fail_cnt+1; $display("  FAIL: MAC result got=%0d",acc32); end

        $display("=== DONE: pass=%0d fail=%0d ===", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
