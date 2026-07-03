// Digital Top: integrates all 14 sub-modules
// Interfaces: SPI slave, analog SA inputs, control/data outputs to analog
module digital_top (
    input  wire        clk,
    input  wire        rst_n,
    // SPI pads
    input  wire        spi_clk,
    input  wire        spi_csn,
    input  wire        spi_mosi,
    output wire        spi_miso,
    // SA interface (from analog)
    input  wire [2:0]  sa_therm,      // 3 comparator outputs
    input  wire        sa_done,       // SA conversion complete
    // Analog control outputs
    output wire [7:0]  trim_dac0, trim_dac1, trim_dac2,
    output wire [7:0]  timing_cfg,
    output wire [7:0]  load_cfg,
    output wire [7:0]  emulator_cfg,
    output wire [3:0]  analog_mux_sel,
    output wire [7:0]  dac_direct,
    // DFT
    input  wire        scan_in,
    output wire        scan_out
);
    // SPI <-> regfile wires
    wire [7:0] reg_addr, reg_wdata, reg_rdata;
    wire       reg_wen, reg_ren;

    // act_regfile indirect access
    wire [9:0]  act_spi_ptr;
    wire [7:0]  act_spi_wdata, act_spi_rdata;
    wire        act_spi_wen;
    wire        act_auto_inc;

    // regfile control outputs
    wire [7:0]  ctrl_reg;
    wire [9:0]  row_addr_cfg, n_rows_cfg;
    wire [1:0]  scale_mode;
    wire [7:0]  scale_w_g0,scale_w_g1,scale_w_g2,scale_w_g3;
    wire [7:0]  scale_w_g4,scale_w_g5,scale_w_g6,scale_w_g7;
    wire [7:0]  scan_ctrl_reg;

    // datapath status
    wire [7:0]  fsm_state_out, error_code_out;
    wire        mac_done_top, sa_error_top;
    wire        bist_pass_top, act_loaded_top;
    wire        acc_overflow;
    wire signed [25:0] acc_out;
    wire [7:0]  bist_result_byte;
    wire        bist_done_top, bist_pass_w;
    wire [5:0]  fail_row_hint;

    // ADC decoder
    wire [1:0]  adc_bin;
    wire        adc_valid;
    wire [7:0]  read_data_byte = {6'd0, adc_bin};

    // Row sequencer
    wire [9:0]  row_addr_seq;
    wire [2:0]  group_id;
    wire        mac_start_seq, seq_done, seq_active;

    // Activation
    wire [9:0]  act_raddr;
    wire [7:0]  act_rdata;

    // MAC/accum
    wire        mac_done_bit, acc_en;
    wire signed [25:0] product_shifted;
    // Accumulator cleared once at start of MAC operation (edge-detect on mac_run)
    wire        mac_run = go_bit && !act_load_mode;
    reg         mac_run_r;
    always @(posedge clk or negedge rst_n_int)
        if (!rst_n_int) mac_run_r <= 0;
        else mac_run_r <= mac_run;
    wire acc_clear = mac_run && !mac_run_r;  // rising edge of mac_run
    // act_waddr for correct write address
    wire [9:0] act_waddr_from_reg;

    // dequant
    wire signed [3:0] w4_signed;
    wire signed [7:0] w8_out;

    // Scale select based on group
    reg [7:0] cur_scale;
    always @(*) begin
        case(group_id)
            3'd0: cur_scale = scale_w_g0;
            3'd1: cur_scale = scale_w_g1;
            3'd2: cur_scale = scale_w_g2;
            3'd3: cur_scale = scale_w_g3;
            3'd4: cur_scale = scale_w_g4;
            3'd5: cur_scale = scale_w_g5;
            3'd6: cur_scale = scale_w_g6;
            default: cur_scale = scale_w_g7;
        endcase
    end

    // Control decode
    wire go_bit          = ctrl_reg[7];
    wire bypass_sa       = ctrl_reg[4];
    wire cds_en          = ctrl_reg[3];
    wire bist_en_bit     = ctrl_reg[2];
    wire act_load_mode   = ctrl_reg[1];
    wire sw_rst          = ctrl_reg[0];
    wire rst_n_int       = rst_n & ~sw_rst;

    // act_loaded flag: goes high after act_load_mode deasserted if any writes done
    reg act_loaded_reg;
    always @(posedge clk or negedge rst_n_int)
        if (!rst_n_int) act_loaded_reg <= 0;
        else if (act_spi_wen) act_loaded_reg <= 1;
        else if (go_bit)      act_loaded_reg <= 0;
    assign act_loaded_top = act_loaded_reg;

    // SA error: placeholder (real SA timeout from analog FSM)
    assign sa_error_top = 1'b0;

    // Module instantiations
    spi_slave u_spi (
        .clk(clk), .rst_n(rst_n_int),
        .spi_clk(spi_clk), .spi_csn(spi_csn),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata),
        .reg_wen(reg_wen), .reg_ren(reg_ren),
        .reg_rdata(reg_rdata)
    );

    regfile u_reg (
        .clk(clk), .rst_n(rst_n_int),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata),
        .reg_wen(reg_wen), .reg_ren(reg_ren),
        .reg_rdata(reg_rdata),
        .mac_done(mac_done_top), .sa_error(sa_error_top),
        .bist_pass_in(bist_pass_w), .act_loaded(act_loaded_top),
        .fsm_state(fsm_state_out), .error_code(error_code_out),
        .adc_therm(sa_therm), .read_data(read_data_byte),
        .bist_result(bist_result_byte), .acc_out(acc_out),
        .ctrl_reg(ctrl_reg), .row_addr(row_addr_cfg), .n_rows(n_rows_cfg),
        .trim_dac0(trim_dac0), .trim_dac1(trim_dac1), .trim_dac2(trim_dac2),
        .timing_cfg(timing_cfg), .load_cfg(load_cfg),
        .emulator(emulator_cfg), .bist_cfg(),
        .scan_ctrl(scan_ctrl_reg), .dac_direct(dac_direct),
        .analog_mux(analog_mux_sel),
        .scale_mode(scale_mode),
        .scale_w_g0(scale_w_g0), .scale_w_g1(scale_w_g1),
        .scale_w_g2(scale_w_g2), .scale_w_g3(scale_w_g3),
        .scale_w_g4(scale_w_g4), .scale_w_g5(scale_w_g5),
        .scale_w_g6(scale_w_g6), .scale_w_g7(scale_w_g7),
        .act_ptr(act_spi_ptr), .act_waddr(act_waddr_from_reg),
        .act_wdata(act_spi_wdata),
        .act_wen(act_spi_wen), .act_rdata(act_spi_rdata),
        .act_auto_inc(act_auto_inc)
    );

    act_regfile u_act (
        .clk(clk),
        .waddr(act_waddr_from_reg), .wdata(act_spi_wdata), .wen(act_spi_wen),
        .raddr(act_raddr), .rdata(act_rdata),
        .spi_raddr(act_spi_ptr), .spi_rdata(act_spi_rdata)
    );

    activation_shift_ctrl u_actctrl (
        .row_addr(row_addr_seq), .act_raddr(act_raddr)
    );

    adc_decoder_2b u_adc (
        .therm_in(sa_therm), .bin_out(adc_bin), .valid(adc_valid)
    );

    int4_rebuild u_i4r (
        .cell_hi(adc_bin), .cell_lo(adc_bin), .w4_signed(w4_signed)
    );

    dequant_unit u_dq (
        .w4_in(w4_signed), .scale(cur_scale),
        .mode(scale_mode), .w8_out(w8_out)
    );

    row_seq u_rseq (
        .clk(clk), .rst_n(rst_n_int),
        .go(mac_run),
        .start_row(row_addr_cfg), .n_rows(n_rows_cfg),
        .mac_row_done(mac_done_bit),
        .row_addr(row_addr_seq), .group_id(group_id),
        .mac_start(mac_start_seq), .seq_done(seq_done), .seq_active(seq_active)
    );

    bitserial_mac u_mac (
        .clk(clk), .rst_n(rst_n_int),
        .start(mac_start_seq),
        .w8(bypass_sa ? 8'sd1 : w8_out),
        .a8(act_rdata),
        .done(mac_done_bit),
        .acc_en(acc_en), .product_shifted(product_shifted)
    );

    accum26 u_acc (
        .clk(clk), .rst_n(rst_n_int),
        .start(acc_clear), .acc_en(acc_en),
        .product(product_shifted[15:0]),
        .acc_out(acc_out), .overflow(acc_overflow)
    );

    fsm_debug u_fsm (
        .clk(clk), .rst_n(rst_n_int),
        .go(go_bit), .act_load_mode(act_load_mode),
        .seq_done(seq_done), .acc_overflow(acc_overflow), .sa_timeout(1'b0),
        .fsm_state(fsm_state_out), .error_code(error_code_out),
        .mac_done_out(mac_done_top)
    );

    bist_ctrl u_bist (
        .clk(clk), .rst_n(rst_n_int),
        .bist_en(bist_en_bit), .bist_cfg(8'h00),
        .mac_done(mac_done_top), .acc_in(acc_out),
        .bist_done(bist_done_top), .bist_pass(bist_pass_w), .fail_row_hint(fail_row_hint)
    );

    assign bist_result_byte = {bist_done_top, bist_pass_w, fail_row_hint};
    assign scan_out = scan_in; // placeholder DFT chain

endmodule
