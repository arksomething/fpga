module memory (
    input  wire        clk,
    input  wire [7:0]  memory_address,
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

    always @(posedge clk) begin
        if (memory_write)
            mem[memory_address] <= data_in;
    end

    // Combinational read so fetch can latch Mem[PC] in the same cycle as address.
    always @(*) begin
        if (memory_read)
            data_out = mem[memory_address];
        else
            data_out = 16'h0000;
    end
endmodule
