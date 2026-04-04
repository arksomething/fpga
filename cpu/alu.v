module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [1:0]  alu_sel,   // 00=ADD,01=SUB,10=AND,11=NOP
    output reg  [15:0] result,
    output reg         zero,
    output reg         negative,
    output reg         carry
);
    reg [16:0] ext;
    always @(*) begin
        case (alu_sel)
            2'b00: begin // ADD
                ext = {1'b0, a} + {1'b0, b};
                result   = ext[15:0];
                carry    = ext[16];
                negative = result[15];
                zero     = (result == 16'b0);
            end
            2'b01: begin // SUB
                ext = {1'b0, a} - {1'b0, b};
                result   = ext[15:0];
                carry    = ext[16];
                negative = result[15];
                zero     = (result == 16'b0);
            end
            2'b10: begin // AND
                result   = a & b;
                carry    = 1'b0;
                negative = result[15];
                zero     = (result == 16'b0);
            end
            default: begin // NOP
                result   = 16'b0;
                carry    = 1'b0;
                negative = 1'b0;
                zero     = 1'b1;
            end
        endcase
    end
endmodule
