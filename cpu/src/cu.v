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
    input  wire [15:0] instruction,   // latched IR from top
    input  wire        alu_zero,      // zero flag from ALU (combinational)
    output reg  [2:0]  read_addr1,
    output reg  [2:0]  read_addr2,
    output reg  [2:0]  write_addr,
    output reg         write_enable,
    output reg  [1:0]  alu_op,        // 00=ADD,01=SUB,10=AND,11=NOP
    output reg         pc_write,      // instruct top to load PC from rf_read_data1
    output reg         ir_write,      // unused in top-level but exported for completeness
    output reg         is_mov,        // when high, write_data comes from rf_read_data1
    output reg  [1:0]  write_data_sel // 00 = ALU result, 01 = RF read1 (MOV), 10 = immediate (LDI)
);

    // FSM states
    reg [1:0] state;
    localparam S_FETCH = 2'b00;
    localparam S_EXEC  = 2'b01;

    // decoded fields (registered between states)
    reg [3:0] opcode;
    reg [2:0] rd;
    reg [2:0] rs1;
    reg [2:0] rs2;
    // imm8 can be extracted from instruction when needed by top (we expose via IR)
    // but CU selects write_data_sel = 2'b10 to tell top to mux imm from IR.

    initial begin
        state = S_FETCH;
    end

    // Main CU FSM (synchronous)
    always @(posedge clk) begin
        // set safe defaults each cycle; EXEC will override the ones it needs
        read_addr1   <= 3'b000;
        read_addr2   <= 3'b000;
        write_addr   <= 3'b000;
        write_enable <= 1'b0;
        alu_op       <= 2'b11; // NOP
        pc_write     <= 1'b0;
        is_mov       <= 1'b0;
        ir_write     <= 1'b0;
        write_data_sel<= 2'b00; // default to ALU

        if (state == S_FETCH) begin
            // instruction is assumed latched by top into IR and passed in
            opcode <= instruction[15:12];
            rd     <= instruction[11:9];
            rs1    <= instruction[8:6];
            rs2    <= instruction[5:3];
            // move to EXEC next cycle
            state <= S_EXEC;
        end else begin
            // EXECUTE: generate control signals based on opcode and decoded fields
            case (opcode)
                4'b0000: begin // ADD rd = rs1 + rs2
                    alu_op        <= 2'b00;
                    read_addr1    <= rs1;
                    read_addr2    <= rs2;
                    write_addr    <= rd;
                    write_enable  <= 1'b1;
                    write_data_sel<= 2'b00; // ALU result
                end

                4'b0001: begin // SUB rd = rs1 - rs2
                    alu_op        <= 2'b01;
                    read_addr1    <= rs1;
                    read_addr2    <= rs2;
                    write_addr    <= rd;
                    write_enable  <= 1'b1;
                    write_data_sel<= 2'b00; // ALU result
                end

                4'b0010: begin // MOV rd = rs1
                    // pass-through from register file read1 into dest
                    is_mov        <= 1'b1;
                    read_addr1    <= rs1; // source
                    write_addr    <= rd;  // destination
                    write_enable  <= 1'b1;
                    write_data_sel<= 2'b01; // RF read1
                end

                4'b0011: begin // AND rd = rs1 & rs2
                    alu_op        <= 2'b10;
                    read_addr1    <= rs1;
                    read_addr2    <= rs2;
                    write_addr    <= rd;
                    write_enable  <= 1'b1;
                    write_data_sel<= 2'b00; // ALU result
                end

                4'b0100: begin // JMP PC = R[rs1]
                    // Top-level must use RF read_data1 as new PC when pc_write asserted.
                    read_addr1    <= rs1;   // top will read rf_read_data1 for PC
                    pc_write      <= 1'b1;
                end

                4'b0101: begin // JZ PC = R[rs1] if zero flag set
                    read_addr1    <= rs1;   // read potential target address
                    // Note: alu_zero must reflect the previous ALU operation (or a compare instruction)
                    if (alu_zero)
                        pc_write <= 1'b1;
                end

                4'b1100: begin // LDI rd, imm8  -> rd = zero_extend(imm8)
                    // instruction format for LDI:
                    // [15:12]=1100, [11:9]=rd, [8:1]=imm8, [0]=unused
                    write_addr    <= rd;
                    write_enable  <= 1'b1;
                    write_data_sel<= 2'b10; // immediate selected by top as {8'b0, instruction[8:1]}
                end

                default: begin
                    // NOP or unsupported opcode -> do nothing
                end
            endcase

            // return to FETCH for next instruction
            state <= S_FETCH;
        end
    end

endmodule
