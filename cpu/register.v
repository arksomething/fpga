module register (
    input  wire        clk,
    input  wire [2:0]  read_addr1,
    input  wire [2:0]  read_addr2,
    input  wire [2:0]  pc_read_addr, // e.g. ir[11:9]; stable for JMP/JZ while IR holds the jump insn
    input  wire [2:0]  write_addr,
    input  wire [15:0] write_data,
    input  wire        write_enable,
    output reg  [15:0] read_data1,
    output reg  [15:0] read_data2,
    output wire [15:0] pc_read_data
);
    reg [15:0] r [0:7];

    integer ri;
    initial begin
        for (ri = 0; ri < 8; ri = ri + 1)
            r[ri] = 16'h0000;
    end

    always @(*) begin
        read_data1 = r[read_addr1];
        read_data2 = r[read_addr2];
    end

    assign pc_read_data = r[pc_read_addr];

    always @(posedge clk) begin
        if (write_enable) begin
            r[write_addr] <= write_data;
        end
    end
endmodule
