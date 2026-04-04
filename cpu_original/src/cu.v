// cu.v -- control unit for the 6-instruction + LDI ISA
//
// Instruction word (16 bits):
//   R-type (ADD,SUB,AND,MOV):
//     [15:12] opcode
//     [11:9]  rd    (destination)
//     [8:6]   rs1
//     [5:3]   rs2
//     [2:0]   unused
//
//   I-type (LDI):
//     [15:12] opcode (1100)
//     [11:9]  rd
//     [8:1]   imm8
//     [0]     unused
//
//   J-type (JMP,JZ):
//     [15:12] opcode
//     [11:9]  rs1  (register containing target address)
//     [8:0]   unused
//
module cu (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] instruction,
    input  wire        alu_zero,
    output reg  [2:0]  read_addr1,
    output reg  [2:0]  read_addr2,
    output reg  [2:0]  write_addr,
    output reg         write_enable,
    output reg  [1:0]  alu_op,
    output reg         pc_write,
    output reg         ir_write,
    output reg         is_mov,
    output reg  [1:0]  write_data_sel,
    output wire        fetch
);

    reg [1:0] state;
    localparam S_FETCH = 2'b00;
    localparam S_EXEC  = 2'b01;

    assign fetch = (state == S_FETCH);

    reg [3:0] opcode;
    reg [2:0] rd;
    reg [2:0] rs1;
    reg [2:0] rs2;

    initial begin
        state = S_FETCH;
    end

    always @(posedge clk) begin
        if (reset) begin
            state  <= S_FETCH;
            opcode <= 4'b0000;
            rd     <= 3'b000;
            rs1    <= 3'b000;
            rs2    <= 3'b000;
        end else if (state == S_FETCH) begin
            opcode <= instruction[15:12];
            rd     <= instruction[11:9];
            rs1    <= instruction[8:6];
            rs2    <= instruction[5:3];
            state  <= S_EXEC;
        end else begin
            state <= S_FETCH;
        end
    end

    // Combinational during EXEC so RF reads and pc_write align with clocked elements in top/RF.
    always @(*) begin
        read_addr1     = 3'b000;
        read_addr2     = 3'b000;
        write_addr     = 3'b000;
        write_enable   = 1'b0;
        alu_op         = 2'b11;
        pc_write       = 1'b0;
        is_mov         = 1'b0;
        ir_write       = 1'b0;
        write_data_sel = 2'b00;

        if (!reset && state == S_EXEC) begin
            case (opcode)
                4'b0000: begin // ADD
                    alu_op         = 2'b00;
                    read_addr1     = rs1;
                    read_addr2     = rs2;
                    write_addr     = rd;
                    write_enable   = 1'b1;
                    write_data_sel = 2'b00;
                end

                4'b0001: begin // SUB
                    alu_op         = 2'b01;
                    read_addr1     = rs1;
                    read_addr2     = rs2;
                    write_addr     = rd;
                    write_enable   = 1'b1;
                    write_data_sel = 2'b00;
                end

                4'b0010: begin // MOV
                    is_mov         = 1'b1;
                    read_addr1     = rs1;
                    write_addr     = rd;
                    write_enable   = 1'b1;
                    write_data_sel = 2'b01;
                end

                4'b0011: begin // AND
                    alu_op         = 2'b10;
                    read_addr1     = rs1;
                    read_addr2     = rs2;
                    write_addr     = rd;
                    write_enable   = 1'b1;
                    write_data_sel = 2'b00;
                end

                4'b0100: begin // JMP
                    read_addr1 = rs1;
                    pc_write   = 1'b1;
                end

                4'b0101: begin // JZ
                    read_addr1 = rs1;
                    if (alu_zero)
                        pc_write = 1'b1;
                end

                4'b1100: begin // LDI
                    write_addr     = rd;
                    write_enable   = 1'b1;
                    write_data_sel = 2'b10;
                end

                default: begin
                end
            endcase
        end
    end

endmodule
