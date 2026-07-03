// Debug FSM state tracker
module fsm_debug (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        go,
    input  wire        act_load_mode,
    input  wire        seq_done,
    input  wire        acc_overflow,
    input  wire        sa_timeout,
    output reg  [7:0]  fsm_state,
    output reg  [7:0]  error_code,
    output reg         mac_done_out
);
    reg [3:0] state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin state<=0; fsm_state<=0; error_code<=0; mac_done_out<=0; end
        else begin
            mac_done_out<=0;
            case(state)
                4'h0: if(go) state <= act_load_mode ? 4'h1 : 4'h2;
                4'h1: if(!act_load_mode) state<=4'h0;
                4'h2: begin
                    if(acc_overflow) begin state<=4'hF; error_code<=8'h04; end
                    else if(sa_timeout) begin state<=4'hF; error_code<=8'h01; end
                    else if(seq_done) begin state<=4'h3; mac_done_out<=1; end
                end
                4'h3: if(!go) state<=4'h0;
                4'hF: if(!go) begin state<=4'h0; error_code<=0; end
                default: state<=4'h0;
            endcase
            fsm_state<={4'd0,state};
        end
    end
endmodule
