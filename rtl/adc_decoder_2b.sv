module adc_decoder_2b (
    input  wire [2:0] therm_in,
    output reg  [1:0] bin_out,
    output reg        valid
);
    always @(*) begin
        case (therm_in)
            3'b000: begin bin_out=2'd0; valid=1'b1; end
            3'b001: begin bin_out=2'd1; valid=1'b1; end
            3'b011: begin bin_out=2'd2; valid=1'b1; end
            3'b111: begin bin_out=2'd3; valid=1'b1; end
            default:  begin bin_out=2'd0; valid=1'b0; end
        endcase
    end
endmodule
