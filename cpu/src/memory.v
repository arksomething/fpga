module memory (
    input  wire        clk,
    input  wire [7:0]  address,
    input  wire        memory_write,
    input  wire        memory_read,
    input  wire [15:0] data_in,
    output reg  [15:0] data_out
);
    reg [15:0] mem [0:255];

    initial begin
        // Create program.hex in same folder: one 16-bit hex per line
        $readmemh("program.hex", mem);
    end

    // synchronous read + write
    always @(posedge clk) begin
        if (memory_write)
            mem[address] <= data_in;

        if (memory_read)
            data_out <= mem[address];
    end
endmodule
