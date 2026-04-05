module cu (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  instruction_pointer,
    input  wire [15:0] instruction_data,
    input  wire [15:0] alu_output,
    input  wire alu_zero,
    input  wire alu_carry,
    input  wire alu_negative,
    input  wire [15:0] register_read_data1,
    input  wire [15:0] register_read_data2,
    input  wire [15:0] register_read_data3,
    output reg  [2:0]  register_read_addr1,
    output reg  [2:0]  register_read_addr2,
    output reg  [2:0]  register_read_addr3,
    output reg  [15:0] register_write_data,
    output reg  [2:0]  register_write_addr,
    output reg         register_write_enable,
    input  wire [15:0] memory_read_data,
    output reg         memory_read,
    output reg         memory_write,
    output reg  [7:0]  memory_address,
    output reg  [15:0] memory_write_data,
    output reg  [15:0] alu_input_a,
    output reg  [15:0] alu_input_b,
    output reg         stall,
    output reg         pc_write,
    output reg  [7:0]  pc_write_addr,
    output reg  [1:0]  alu_op
);
    // Compiler-friendly ISA v1:
    // arithmetic/data: ADD, SUB, MOV, LDI, ADDI, LOAD, STORE
    // compare/branch: CMPEQ, CMPLT, BZ, BNZ, BRA, JMP
    // calls: CALL, RET
    localparam [3:0] OP_ADD   = 4'b0000; // ADD rd, rs1, rs2
    localparam [3:0] OP_SUB   = 4'b0001; // SUB rd, rs1, rs2
    localparam [3:0] OP_MOV   = 4'b0010; // MOV rd, rs1
    localparam [3:0] OP_BRA   = 4'b0011; // BRA off12
    localparam [3:0] OP_JMP   = 4'b0100; // JMP rs1
    localparam [3:0] OP_BZ    = 4'b0101; // BZ rd, off9
    localparam [3:0] OP_LOAD  = 4'b0110; // LOAD rd, [base + imm6]
    localparam [3:0] OP_STORE = 4'b0111; // STORE rs, [base + imm6]
    localparam [3:0] OP_CMPEQ = 4'b1000; // CMPEQ rd, rs1, rs2
    localparam [3:0] OP_CMPLT = 4'b1001; // CMPLT rd, rs1, rs2
    localparam [3:0] OP_ADDI  = 4'b1010; // ADDI rd, rs1, imm6
    localparam [3:0] OP_BNZ   = 4'b1011; // BNZ rd, off9
    localparam [3:0] OP_LDI   = 4'b1100; // LDI rd, imm8
    localparam [3:0] OP_CALL  = 4'b1101; // CALL off12
    localparam [3:0] OP_RET   = 4'b1110; // RET
    localparam [3:0] OP_NOP   = 4'b1111; // NOP

    localparam [2:0] REG_SP = 3'b111;

    reg [15:0] fetched_instruction;

    reg [3:0] opcode;
    reg [2:0] rd;
    reg [2:0] r1;
    reg [2:0] r2;
    reg [5:0] imm6;
    reg [7:0] imm8;
    reg [8:0] off9;
    reg [11:0] off12;
    reg [15:0] r1_data;
    reg [15:0] r2_data;
    reg [15:0] rd_data;
    reg [7:0] fetched_ip;
    reg [7:0] ip;

    reg [3:0]  executed_opcode;
    reg [2:0]  executed_rd;
    reg [2:0]  executed_r1;
    reg [2:0]  executed_r2;
    reg [5:0]  executed_imm6;
    reg [7:0]  executed_imm8;
    reg [8:0]  executed_off9;
    reg [11:0] executed_off12;
    reg [15:0] executed_r1_data;
    reg [15:0] executed_r2_data;
    reg [15:0] executed_alu_result;
    reg [7:0]  executed_ip;

    reg [3:0]  post_memory_opcode;
    reg [2:0]  post_memory_rd;
    reg [2:0]  post_memory_r1;
    reg [2:0]  post_memory_r2;
    reg [5:0]  post_memory_imm6;
    reg [7:0]  post_memory_imm8;
    reg [15:0] post_memory_alu_result;
    reg [15:0] post_memory_load_data;
    reg [15:0] post_memory_write_data;
    reg [15:0] post_memory_r1_data;
    reg [15:0] post_memory_r2_data;
    reg [7:0]  post_memory_ip;

    reg executed_zero;
    reg executed_carry;
    reg executed_negative;

    reg flush;
    reg flush_mem;

    wire executed_writes_rd;
    wire post_memory_writes_rd;

    reg        src_a_is_reg;
    reg        src_b_is_reg;
    reg [2:0]  src_a_reg;
    reg [2:0]  src_b_reg;
    reg [15:0] src_a_value;
    reg [15:0] src_b_value;
    reg [15:0] executed_write_data;

    assign executed_writes_rd = (executed_opcode == OP_ADD) ||
                                (executed_opcode == OP_SUB) ||
                                (executed_opcode == OP_CMPEQ) ||
                                (executed_opcode == OP_CMPLT) ||
                                (executed_opcode == OP_ADDI) ||
                                (executed_opcode == OP_LDI) ||
                                (executed_opcode == OP_MOV) ||
                                (executed_opcode == OP_CALL) ||
                                (executed_opcode == OP_RET);
    assign post_memory_writes_rd = (post_memory_opcode == OP_LOAD) ||
                                   (post_memory_opcode == OP_ADD)  ||
                                   (post_memory_opcode == OP_SUB)  ||
                                   (post_memory_opcode == OP_CMPEQ)  ||
                                   (post_memory_opcode == OP_CMPLT)  ||
                                   (post_memory_opcode == OP_ADDI)  ||
                                   (post_memory_opcode == OP_LDI)    ||
                                   (post_memory_opcode == OP_MOV)  ||
                                   (post_memory_opcode == OP_CALL) ||
                                   (post_memory_opcode == OP_RET);

    always @(*) begin // ID
        register_read_addr1 = fetched_instruction[8:6];
        register_read_addr2 = fetched_instruction[5:3];
        register_read_addr3 = fetched_instruction[11:9];

        if (fetched_instruction[15:12] == OP_RET || fetched_instruction[15:12] == OP_CALL) begin
            register_read_addr1 = REG_SP;
            register_read_addr2 = 3'b000;
            register_read_addr3 = 3'b000;
        end
    end

    always @(*) begin // EX
        alu_op = 2'b11; // NO OP
        stall = 1'b0;
        flush = 1'b0;
        pc_write = 1'b0;
        pc_write_addr = 8'b0;
        post_memory_write_data = 16'b0;
        src_a_is_reg = 1'b0;
        src_b_is_reg = 1'b0;
        src_a_reg = 3'b0;
        src_b_reg = 3'b0;
        src_a_value = 16'b0;
        src_b_value = 16'b0;
        executed_write_data = 16'b0;

        case (executed_opcode)
            OP_ADD, OP_SUB, OP_MOV, OP_ADDI: begin
                executed_write_data = executed_alu_result;
            end
            OP_CMPEQ: begin
                executed_write_data = executed_zero ? 16'b1 : 16'b0;
            end
            OP_CMPLT: begin
                executed_write_data = ($signed(executed_r1_data) < $signed(executed_r2_data)) ? 16'b1 : 16'b0;
            end
            OP_LDI: begin
                executed_write_data = {8'b0, executed_imm8};
            end
            OP_CALL: begin
                executed_write_data = executed_r1_data - 16'b1;
            end
            OP_RET: begin
                executed_write_data = executed_r1_data + 16'b1;
            end
            default: begin
            end
        endcase

        case (post_memory_opcode)
            OP_LOAD: begin
                post_memory_write_data = post_memory_load_data;
            end
            OP_ADD, OP_SUB, OP_MOV, OP_ADDI: begin
                post_memory_write_data = post_memory_alu_result;
            end
            OP_CMPEQ: begin
                post_memory_write_data = (post_memory_alu_result == 16'b0) ? 16'b1 : 16'b0;
            end
            OP_CMPLT: begin
                post_memory_write_data = ($signed(post_memory_r1_data) < $signed(post_memory_r2_data)) ? 16'b1 : 16'b0;
            end
            OP_LDI: begin
                post_memory_write_data = {8'b0, post_memory_imm8};
            end
            OP_CALL: begin
                post_memory_write_data = post_memory_r1_data - 16'b1;
            end
            OP_RET: begin
                post_memory_write_data = post_memory_r1_data + 16'b1;
            end
            default: begin
            end
        endcase

        // Phase 1: describe the operands this opcode wants.
        case (opcode)
            OP_ADD: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_is_reg = 1'b1;
                src_b_reg = r2;
                src_b_value = r2_data;
                alu_op = 2'b00; // ADD
            end

            OP_SUB: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_is_reg = 1'b1;
                src_b_reg = r2;
                src_b_value = r2_data;
                alu_op = 2'b01; // SUB
            end

            OP_MOV: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                // MOV uses the ALU as A + 0 so it participates in normal forwarding.
                alu_op = 2'b00;
            end

            OP_CMPEQ: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_is_reg = 1'b1;
                src_b_reg = r2;
                src_b_value = r2_data;
                alu_op = 2'b01;
            end

            OP_CMPLT: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_is_reg = 1'b1;
                src_b_reg = r2;
                src_b_value = r2_data;
            end

            OP_ADDI: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_value = {10'b0, imm6};
                alu_op = 2'b00;
            end

            OP_LDI: begin
                src_a_value = {8'b0, imm8};
            end

            OP_LOAD: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
            end

            OP_STORE: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
                src_b_is_reg = 1'b1;
                src_b_reg = r2;
                src_b_value = r2_data;
            end

            OP_JMP: begin
                src_a_is_reg = 1'b1;
                src_a_reg = r1;
                src_a_value = r1_data;
            end

            OP_BZ: begin
                src_a_is_reg = 1'b1;
                src_a_reg = rd;
                src_a_value = rd_data;
                alu_op = 2'b00;
            end 

            OP_BNZ: begin
                src_a_is_reg = 1'b1;
                src_a_reg = rd;
                src_a_value = rd_data;
                alu_op = 2'b00;
            end

            OP_CALL: begin
                src_a_is_reg = 1'b1;
                src_a_reg = REG_SP;
                src_a_value = r1_data;
            end

            OP_RET: begin
                src_a_is_reg = 1'b1;
                src_a_reg = REG_SP;
                src_a_value = r1_data;
            end

            default: begin
            end
        endcase

        // Phase 2: resolve hazards for the selected operands.
        if (executed_opcode == OP_LOAD &&
            ((src_a_is_reg && executed_rd == src_a_reg) ||
             (src_b_is_reg && executed_rd == src_b_reg))) begin
            stall = 1'b1;
        end else begin
            if (src_a_is_reg) begin
                if (executed_writes_rd && executed_rd == src_a_reg) begin
                    src_a_value = executed_write_data;
                end else if (post_memory_writes_rd && post_memory_rd == src_a_reg) begin
                    src_a_value = post_memory_write_data;
                end
            end

            if (src_b_is_reg) begin
                if (executed_writes_rd && executed_rd == src_b_reg) begin
                    src_b_value = executed_write_data;
                end else if (post_memory_writes_rd && post_memory_rd == src_b_reg) begin
                    src_b_value = post_memory_write_data;
                end
            end
        end

        alu_input_a = src_a_value;
        alu_input_b = src_b_value;

        // Phase 3: use the resolved operands for control flow.
        if (executed_opcode == OP_RET) begin
            pc_write_addr = memory_read_data[7:0];
            pc_write = 1'b1;
        end else if (!stall) begin
            case (opcode)
                OP_JMP: begin
                    pc_write_addr = src_a_value[7:0];
                    pc_write = 1'b1;
                    flush = 1'b1;
                end

                OP_BRA: begin
                    pc_write_addr = ip + off12;
                    pc_write = 1'b1;
                    flush = 1'b1;
                end

                OP_BZ: begin
                    pc_write_addr = ip + off9;
                    if (alu_zero) begin
                        pc_write = 1'b1;
                        flush = 1'b1;
                    end
                end

                OP_BNZ: begin
                    pc_write_addr = ip + off9;
                    if (!alu_zero) begin
                        pc_write = 1'b1;
                        flush = 1'b1;
                    end
                end

                OP_CALL: begin
                    pc_write_addr = ip + off12;
                    pc_write = 1'b1;
                    flush = 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

    always @(*) begin // MEM
        flush_mem = 1'b0;
        memory_read = 1'b0;
        memory_write = 1'b0;
        memory_address = 8'b0;
        memory_write_data = 16'b0;

        case (executed_opcode)
            OP_LOAD: begin // LOAD - R[rd] <- MEM[R[r1]]
                memory_read = 1'b1;
                memory_address = executed_r1_data[7:0] + executed_imm6; //executed 
            end

            OP_RET: begin // LOAD - R[rd] <- MEM[R[r1]]
                memory_read = 1'b1;
                memory_address = executed_r1_data[7:0];
                flush_mem = 1'b1;
            end

            OP_CALL: begin
                memory_write = 1'b1;
                memory_address = executed_r1_data[7:0] - 8'b1;
                memory_write_data = {8'b0, executed_ip} + 16'b1;
            end

            OP_STORE: begin // STORE - MEM[R[r2]] <- R[r1]
                memory_write = 1'b1;
                memory_address = executed_r2_data[7:0];
                memory_write_data = executed_r1_data;
            end

            default: begin
            end
        endcase
    end

    always @(*) begin
        register_write_data = 16'b0;
        register_write_addr = 3'b000;
        register_write_enable = 1'b0;

        case (post_memory_opcode)
            OP_LOAD, OP_ADD, OP_SUB, OP_MOV, OP_CMPEQ, OP_CMPLT, OP_ADDI, OP_LDI: begin
                register_write_data = post_memory_write_data;
                register_write_addr = post_memory_rd;
                register_write_enable = 1'b1;
            end

            OP_CALL: begin
                register_write_data = post_memory_write_data;
                register_write_addr = REG_SP;
                register_write_enable = 1'b1;
            end

            OP_RET: begin
                register_write_data = post_memory_write_data;
                register_write_addr = REG_SP;
                register_write_enable = 1'b1;
            end

            default: begin
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            fetched_instruction <= 16'b0;
            fetched_ip <= 8'b0;
            opcode <= 4'b1111;
            rd <= 3'b0;
            r1 <= 3'b0;
            r2 <= 3'b0;
            r1_data <= 16'b0;
            r2_data <= 16'b0;
            rd_data <= 16'b0;
            imm6 <= 6'b0;
            imm8 <= 8'b0;
            off9 <= 9'b0;
            off12 <= 12'b0;
            ip <= 8'b0;
            executed_opcode <= 4'b0;
            executed_rd <= 3'b0;
            executed_r1 <= 3'b0;
            executed_r2 <= 3'b0;
            executed_imm6 <= 6'b0;
            executed_imm8 <= 8'b0;
            executed_off9 <= 9'b0;
            executed_off12 <= 12'b0;
            executed_r1_data <= 16'b0;
            executed_r2_data <= 16'b0;
            executed_alu_result <= 16'b0;
            executed_ip <= 8'b0;
            post_memory_opcode <= 4'b0;
            post_memory_rd <= 3'b0;
            post_memory_r1 <= 3'b0;
            post_memory_r2 <= 3'b0;
            post_memory_imm6 <= 6'b0;
            post_memory_imm8 <= 8'b0;
            post_memory_alu_result <= 16'b0;
            post_memory_load_data <= 16'b0;
            post_memory_r1_data <= 16'b0;
            post_memory_r2_data <= 16'b0;
            post_memory_ip <= 8'b0;
        end else begin
            // instruction fetch
            if (!stall) begin
                if (!flush && !flush_mem) begin
                    fetched_instruction <= instruction_data;
                    fetched_ip <= instruction_pointer;
                    
                    // instruction decode
                    opcode <= fetched_instruction[15:12];
                    rd <= ((fetched_instruction[15:12] == OP_RET) || (fetched_instruction[15:12] == OP_CALL)) ? REG_SP : fetched_instruction[11:9];
                    r1 <= ((fetched_instruction[15:12] == OP_RET) || (fetched_instruction[15:12] == OP_CALL)) ? REG_SP : fetched_instruction[8:6];
                    r2 <= fetched_instruction[5:3];
                    imm6 <= fetched_instruction[5:0];
                    imm8 <= fetched_instruction[8:1];
                    off9 <= fetched_instruction[8:0];
                    off12 <= fetched_instruction[11:0];
                    r1_data <= register_read_data1;
                    r2_data <= register_read_data2;
                    rd_data <= register_read_data3;
                    ip <= fetched_ip;
                end
                else begin
                    fetched_instruction <= 16'b1111111111111111;
                    fetched_ip <= 8'b11111111;
                    // instruction decode
                    opcode <= 4'b1111;
                    rd <= 3'b0;
                    r1 <= 3'b0;
                    r2 <= 3'b0;
                    imm6 <= 6'b0;
                    imm8 <= 8'b0;
                    off9 <= 9'b0;
                    off12 <= 12'b0;
                    r1_data <= 16'b0;
                    r2_data <= 16'b0;
                    rd_data <= 16'b0;
                    ip <= 8'b11111111;

                end
            end
            // execute
            if (!flush_mem) begin
                executed_opcode <= stall ? 4'b1111 : opcode;
                executed_rd <= stall ? 3'b0 : rd;
                executed_r1 <= stall ? 3'b0 : r1;
                executed_r2 <= stall ? 3'b0 : r2;
                executed_imm6 <= stall ? 6'b0 : imm6;
                executed_imm8 <= stall ? 8'b0 : imm8;
                executed_off9 <= stall ? 9'b0 : off9;
                executed_off12 <= stall ? 12'b0 : off12;
                executed_r1_data <= stall ? 16'b0 : alu_input_a;
                executed_r2_data <= stall ? 16'b0 : alu_input_b;
                executed_ip <= stall ? 8'b11111111 : ip;
                executed_alu_result <= alu_output;
                executed_zero <= alu_zero;
                executed_negative <= alu_negative;
                executed_carry <= alu_carry;
            end else begin
                executed_opcode <= 4'b1111;
                executed_rd <= 3'b0;
                executed_r1 <= 3'b0;
                executed_r2 <= 3'b0;
                executed_imm6 <= 6'b0;
                executed_imm8 <= 8'b0;
                executed_off9 <= 9'b0;
                executed_off12 <= 12'b0;
                executed_r1_data <= 16'b0;
                executed_r2_data <= 16'b0;
                executed_ip <= 8'b11111111;
                executed_alu_result <= 16'b0;
                executed_zero <= 1'b0;
                executed_negative <= 1'b0;
                executed_carry <= 1'b0;
            end

            // memory op / write-back handoff
            post_memory_alu_result <= executed_alu_result;
            post_memory_load_data <= memory_read_data;
            post_memory_opcode <= executed_opcode;
            post_memory_rd <= executed_rd;
            post_memory_r1 <= executed_r1;
            post_memory_r2 <= executed_r2;
            post_memory_r1_data <= executed_r1_data;
            post_memory_r2_data <= executed_r2_data;
            post_memory_imm6 <= executed_imm6;
            post_memory_imm8 <= executed_imm8;
            post_memory_ip <= executed_ip;
        end
    end
endmodule