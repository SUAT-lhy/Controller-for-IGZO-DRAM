module row_seq (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        go,
    input  wire [9:0]  start_row,
    input  wire [9:0]  n_rows,
    input  wire        mac_row_done,
    output reg  [9:0]  row_addr,
    output reg  [2:0]  group_id,
    output reg         mac_start,
    output reg         seq_done,
    output reg         seq_active
);
    reg [9:0] row_cnt;
    reg       go_prev;
    wire      go_rise = go && !go_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_cnt<=0; row_addr<=0; group_id<=0; go_prev<=0;
            mac_start<=0; seq_done<=0; seq_active<=0;
        end else begin
            mac_start<=0; seq_done<=0;
            go_prev <= go;
            if (go_rise && !seq_active) begin
                row_cnt    <= 10'd0;
                row_addr   <= start_row;
                group_id   <= start_row[9:7];
                seq_active <= 1;
                mac_start  <= 1;
            end else if (seq_active && mac_row_done) begin
                if (row_cnt + 1 >= n_rows) begin
                    seq_done   <= 1;
                    seq_active <= 0;
                end else begin
                    row_cnt    <= row_cnt + 1;
                    row_addr   <= row_addr + 1;
                    group_id   <= (row_addr + 1) >> 7;
                    mac_start  <= 1;
                end
            end
        end
    end
endmodule
