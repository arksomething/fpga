module cu (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  instruction_pointer,
    input  wire [15:0] instruction_data,
    input  wire [15:0] alu_output,
    input  wire [15:0] register_read_data1,
    input  wire [15:0] register_read_data2,
    output reg  [2:0]  register_read_addr1,
    output reg  [2:0]  register_read_addr2,
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
    output reg  [1:0]  alu_op
);
    reg [15:0] fetched_instruction;

    reg [3:0] opcode;
    reg [2:0] rd;
    reg [2:0] r1;
    reg [2:0] r2;
    reg [15:0] r1_data;
    reg [15:0] r2_data;

    reg [3:0]  executed_opcode;
    reg [2:0]  executed_rd;
    reg [15:0] executed_alu_result;

    reg [3:0]  post_memory_opcode;
    reg [2:0]  post_memory_rd;
    reg [15:0] post_memory_alu_result;

    always @(*) begin // ID
        register_read_addr1 = fetched_instruction[8:6];
        register_read_addr2 = fetched_instruction[5:3];
    end

    always @(*) begin // EX
        alu_input_a = r1_data;
        alu_input_b = r2_data;

        // check for the HAZARDS
        // HAZARD 1: Current executed_opcode is LOAD and executed_rd there matches r1 or r2 here. STALL
        // HAZARD 2: Current executed alu_op returns rd, which matches r1 or r2 here. FORWARD
        // HAZARD 3: Current post_memory_rd matches r1 or r2 but has not returned it yet. FORWARD
        if (executed_opcode == 4'b0110 && (executed_rd == r1 || executed_rd == r2)) begin
            // STALL
        end
        else if (executed_opcode == 4'b0000 && (executed_rd == r1 || executed_rd == r2)) begin // extend to all alu ops where rd matters
            // FORWARD
            if (executed_rd == r1) begin
                alu_input_a = executed_rd;
            end
            if (executed_rd == r2) begin
                alu_input_b = executed_rd;
            end
        end
        else if (post_memory_rd == r1 || post_memory_rd == r2) begin
            // STALL
            if (post_memory_rd == r1) begin
                alu_input_a = post_memory_rd;
            end
            if (post_memory_rd == r2) begin
                alu_input_b = post_memory_rd;
            end
        end
        else begin
            alu_input_a = r1_data;
            alu_input_b = r2_data;
        end

        case (opcode)
            4'b0000: alu_op = 2'b00; // ADD
            default: alu_op = 2'b11; // NO OP
        endcase
    end

    always @(*) begin
        memory_read = 1'b0;
        memory_write = 1'b0;
        memory_address = 8'b0;
        memory_write_data = 16'b0;

        case (executed_opcode)
            4'b0110: begin // LOAD - R[rd] <- MEM[R[r1]]
                memory_read = 1'b1;
                memory_address = r1_data[7:0];
            end

            4'b0111: begin // STORE - MEM[R[r2]] <- R[r1]
                memory_write = 1'b1;
                memory_address = r2_data[7:0];
                memory_write_data = r1_data;
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
            4'b0110: begin // LOAD
                register_write_data = memory_read_data;
                register_write_addr = post_memory_rd;
                register_write_enable = 1'b1;
            end

            4'b0000: begin // ADD
                register_write_data = post_memory_alu_result;
                register_write_addr = post_memory_rd;
                register_write_enable = 1'b1;
            end

            default: begin
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            fetched_instruction <= 16'b0;
            opcode <= 4'b0;
            rd <= 3'b0;
            r1 <= 3'b0;
            r2 <= 3'b0;
            r1_data <= 16'b0;
            r2_data <= 16'b0;
            executed_opcode <= 4'b0;
            executed_rd <= 3'b0;
            executed_alu_result <= 16'b0;
            post_memory_opcode <= 4'b0;
            post_memory_rd <= 3'b0;
            post_memory_alu_result <= 16'b0;
        end else begin
            // instruction fetch
            if (stall) begin
                stall <= 1'b0;
            end
            if (!stall) begin
                fetched_instruction <= instruction_data;
                
                // instruction decode
                opcode <= fetched_instruction[15:12];
                rd <= fetched_instruction[11:9];
                r1 <= fetched_instruction[8:6];
                r2 <= fetched_instruction[5:3];
                r1_data <= register_read_data1;
                r2_data <= register_read_data2;

                if (executed_opcode == 4'b0110 && (executed_rd == r1 || executed_rd == r2)) begin
                    stall <= 1'b1;
                end
            end
            // execute
            executed_opcode <= stall ? 4'b1111 : opcode;
            executed_rd <= stall ? 3'b0 : rd;
            executed_r1 <= stall ? 3'b0 : r1;
            executed_r2 <= stall ? 3'b0 : r2;
            executed_alu_result <= alu_output;

            // memory op / write-back handoff
            post_memory_alu_result <= executed_alu_result;
            post_memory_opcode <= executed_opcode;
            post_memory_rd <= executed_rd;
            post_memory_r1 <= executed_r1;
            post_memory_r2 <= executed_r2;
        end
    end
endmodule