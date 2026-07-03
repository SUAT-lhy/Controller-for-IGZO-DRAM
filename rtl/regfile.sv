module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  reg_addr,
    input  wire [7:0]  reg_wdata,
    input  wire        reg_wen,
    input  wire        reg_ren,
    output reg  [7:0]  reg_rdata,
    input  wire        mac_done,
    input  wire        sa_error,
    input  wire        bist_pass_in,
    input  wire        act_loaded,
    input  wire [7:0]  fsm_state,
    input  wire [7:0]  error_code,
    input  wire [2:0]  adc_therm,
    input  wire [7:0]  read_data,
    input  wire [7:0]  bist_result,
    input  wire [25:0] acc_out,
    output reg  [7:0]  ctrl_reg,
    output reg  [9:0]  row_addr,
    output reg  [9:0]  n_rows,
    output reg  [7:0]  trim_dac0, trim_dac1, trim_dac2,
    output reg  [7:0]  timing_cfg,
    output reg  [7:0]  load_cfg,
    output reg  [7:0]  emulator,
    output reg  [7:0]  bist_cfg,
    output reg  [7:0]  scan_ctrl,
    output reg  [7:0]  dac_direct,
    output reg  [3:0]  analog_mux,
    output reg  [1:0]  scale_mode,
    output reg  [7:0]  scale_w_g0, scale_w_g1, scale_w_g2, scale_w_g3,
    output reg  [7:0]  scale_w_g4, scale_w_g5, scale_w_g6, scale_w_g7,
    output reg  [9:0]  act_ptr,
    output reg  [7:0]  act_wdata,
    output reg         act_wen,
    output reg  [9:0]  act_waddr,
    input  wire [7:0]  act_rdata,
    output reg         act_auto_inc
);
    reg [7:0] scratch;
    reg mac_done_lat, sa_error_lat, bist_pass_lat, act_loaded_lat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin mac_done_lat<=0; sa_error_lat<=0; bist_pass_lat<=0; act_loaded_lat<=0; end
        else begin
            if (mac_done)     mac_done_lat   <= 1;
            if (sa_error)     sa_error_lat   <= 1;
            if (bist_pass_in) bist_pass_lat  <= 1;
            if (act_loaded)   act_loaded_lat <= 1;
            if (reg_wen && (reg_addr == 8'h13)) begin
                if (reg_wdata[1]) mac_done_lat  <= 0;
                if (reg_wdata[2]) bist_pass_lat <= 0;
                if (reg_wdata[3]) sa_error_lat  <= 0;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scratch<=0; ctrl_reg<=0; row_addr<=0; n_rows<=0;
            trim_dac0<=8'h88; trim_dac1<=8'h88; trim_dac2<=8'h88;
            timing_cfg<=8'h11; load_cfg<=0; emulator<=0; bist_cfg<=0;
            scan_ctrl<=0; dac_direct<=0; analog_mux<=0; scale_mode<=0;
            scale_w_g0<=8'h10; scale_w_g1<=8'h10; scale_w_g2<=8'h10; scale_w_g3<=8'h10;
            scale_w_g4<=8'h10; scale_w_g5<=8'h10; scale_w_g6<=8'h10; scale_w_g7<=8'h10;
            act_ptr<=0; act_waddr<=0; act_wdata<=0; act_wen<=0; act_auto_inc<=1;
        end else begin
            act_wen <= 0;
            if (reg_wen) begin
                case (reg_addr)
                    8'h02: scratch       <= reg_wdata;
                    8'h04: ctrl_reg      <= reg_wdata;
                    8'h05: row_addr[7:0] <= reg_wdata;
                    8'h06: row_addr[9:8] <= reg_wdata[1:0];
                    8'h07: n_rows[7:0]   <= reg_wdata;
                    8'h08: n_rows[9:8]   <= reg_wdata[1:0];
                    8'h09: trim_dac0     <= reg_wdata;
                    8'h0A: trim_dac1     <= reg_wdata;
                    8'h0B: trim_dac2     <= reg_wdata;
                    8'h0C: timing_cfg    <= reg_wdata;
                    8'h0D: load_cfg      <= reg_wdata;
                    8'h0E: emulator      <= reg_wdata;
                    8'h0F: bist_cfg      <= reg_wdata;
                    8'h16: dac_direct    <= reg_wdata;
                    8'h17: analog_mux    <= reg_wdata[3:0];
                    8'h1A: scan_ctrl     <= reg_wdata;
                    8'h40: act_ptr[7:0]  <= reg_wdata;
                    8'h41: act_ptr[9:8]  <= reg_wdata[1:0];
                    8'h42: begin act_waddr<=act_ptr; act_wdata<=reg_wdata; act_wen<=1; if(act_auto_inc) act_ptr<=act_ptr+1; end
                    8'h43: act_auto_inc  <= reg_wdata[0];
                    8'h50: scale_mode    <= reg_wdata[1:0];
                    8'h51: scale_w_g0 <= reg_wdata;
                    8'h52: scale_w_g1 <= reg_wdata;
                    8'h53: scale_w_g2 <= reg_wdata;
                    8'h54: scale_w_g3 <= reg_wdata;
                    8'h55: scale_w_g4 <= reg_wdata;
                    8'h56: scale_w_g5 <= reg_wdata;
                    8'h57: scale_w_g6 <= reg_wdata;
                    8'h58: scale_w_g7 <= reg_wdata;
                    default: ;
                endcase
            end
            if (reg_ren && (reg_addr==8'h42) && act_auto_inc) act_ptr<=act_ptr+1;
        end
    end
    always @(*) begin
        case (reg_addr)
            8'h00: reg_rdata = 8'hA3;
            8'h01: reg_rdata = 8'h30;
            8'h02: reg_rdata = scratch;
            8'h04: reg_rdata = ctrl_reg;
            8'h05: reg_rdata = row_addr[7:0];
            8'h06: reg_rdata = {6'd0, row_addr[9:8]};
            8'h07: reg_rdata = n_rows[7:0];
            8'h08: reg_rdata = {6'd0, n_rows[9:8]};
            8'h09: reg_rdata = trim_dac0;
            8'h0A: reg_rdata = trim_dac1;
            8'h0B: reg_rdata = trim_dac2;
            8'h0C: reg_rdata = timing_cfg;
            8'h0D: reg_rdata = load_cfg;
            8'h0E: reg_rdata = emulator;
            8'h0F: reg_rdata = bist_cfg;
            8'h10: reg_rdata = {mac_done_lat,sa_error_lat,bist_pass_lat,act_loaded_lat,3'd0,sa_error_lat};
            8'h11: reg_rdata = fsm_state;
            8'h12: reg_rdata = error_code;
            8'h14: reg_rdata = {5'd0, adc_therm};
            8'h16: reg_rdata = dac_direct;
            8'h17: reg_rdata = {4'd0, analog_mux};
            8'h18: reg_rdata = read_data;
            8'h19: reg_rdata = bist_result;
            8'h1A: reg_rdata = scan_ctrl;
            8'h20: reg_rdata = acc_out[7:0];
            8'h21: reg_rdata = acc_out[15:8];
            8'h22: reg_rdata = acc_out[23:16];
            8'h23: reg_rdata = {6'd0, acc_out[25:24]};
            8'h40: reg_rdata = act_ptr[7:0];
            8'h41: reg_rdata = {6'd0, act_ptr[9:8]};
            8'h42: reg_rdata = act_rdata;
            8'h43: reg_rdata = {7'd0, act_auto_inc};
            8'h50: reg_rdata = {6'd0, scale_mode};
            8'h51: reg_rdata = scale_w_g0;
            8'h52: reg_rdata = scale_w_g1;
            8'h53: reg_rdata = scale_w_g2;
            8'h54: reg_rdata = scale_w_g3;
            8'h55: reg_rdata = scale_w_g4;
            8'h56: reg_rdata = scale_w_g5;
            8'h57: reg_rdata = scale_w_g6;
            8'h58: reg_rdata = scale_w_g7;
            default: reg_rdata = 8'h00;
        endcase
    end
endmodule
