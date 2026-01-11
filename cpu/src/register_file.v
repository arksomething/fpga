module register_file (
    input  wire        clk,
    input  wire [2:0]  read_addr1,
    input  wire [2:0]  read_addr2,
    input  wire [2:0]  write_addr,
    input  wire [15:0] write_data,
    input  wire        write_enable,
    output reg  [15:0] read_data1,
    output reg  [15:0] read_data2
);
    reg [15:0] r [0:7];

    always @(*) begin
        read_data1 = r[read_addr1];
        read_data2 = r[read_addr2];
    end

    always @(posedge clk) begin
        if (write_enable)
            r[write_addr] <= write_data;
    end
endmodule
