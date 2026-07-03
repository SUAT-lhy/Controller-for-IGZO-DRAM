// BIST controller
module bist_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bist_en,
    input  wire [7:0]  bist_cfg,
    input  wire        mac_done,
    input  wire signed [25:0] acc_in,
    output reg         bist_done,
    output reg         bist_pass,
    output reg  [5:0]  fail_row_hint
);
    reg [1:0] state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin state<=0; bist_done<=0; bist_pass<=0; fail_row_hint<=0; end
        else begin
            bist_done<=0;
            case(state)
                2'd0: if(bist_en) state<=2'd1;
                2'd1: if(mac_done) state<=2'd2;
                2'd2: begin
                    bist_pass<=(bist_cfg[7:4]!=4'h0)?(acc_in!=26'sd0):1'b1;
                    bist_done<=1; state<=2'd3;
                end
                2'd3: if(!bist_en) state<=2'd0;
            endcase
        end
    end
endmodule
