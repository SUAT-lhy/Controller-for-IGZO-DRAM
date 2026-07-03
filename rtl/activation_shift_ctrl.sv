// Activation address passthrough
module activation_shift_ctrl (
    input  wire [9:0]  row_addr,
    output wire [9:0]  act_raddr
);
    assign act_raddr = row_addr;
endmodule
