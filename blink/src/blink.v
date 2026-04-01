module blink (
    input  wire clk,
    input  wire reset_n,
    output reg  led
);
    // Generic divider for visible LED toggling (assumes ~24 MHz input clock).
    reg [23:0] div_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            div_count <= 24'd0;
            led <= 1'b0;
        end else if (div_count == 24'd12_000_000 - 1) begin
            div_count <= 24'd0;
            led <= ~led;
        end else begin
            div_count <= div_count + 1'b1;
        end
    end
endmodule
