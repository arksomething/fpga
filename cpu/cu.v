module cu (
    input reg [3:0] instruction_pointer,
    input reg [15:0] memory_output_data,
    input wire [15:0] alu_output,

    output wire [3:0] memory_address,
    output wire memory_op,

    output reg [3:0] register_read_addr1
    output reg [3:0] register_read_addr2

    input reg [15:0] read_memory;
    output reg memory_read
    output reg memory_write
    output reg [15:0] memory_address
    output reg [15:0] memory_write_data
)   
    reg [15:0] fetched_instruction;

    reg [3:0] opcode;
    reg [2:0] rd; // destination
    reg [2:0] r1;
    reg [2:0] r2;

    reg [1:0] alu_op;
    reg [3:0] alu_addr1;
    reg [3:0] alu_addr2;

    reg [15:0] data_to_register;


    always @(*) begin
        if (reset) begin
            // set initial cu state
        end
    end

    always @(*) begin
        case (opcode)
            4'b0000: begin // ADD
                alu_op = 2'b00;
                alu_addr1 = r1;
                alu_addr2 = r2;
            end

            default: begin
                alu_op = 2'b11; // NO OP
                alu_addr1 = 3b'0;
                alu_addr2 = 3b'0;
            end
        endcase

        memory_instruction_address = instruction_pointer;
    end

    always @(*) begin
        case (executed_opcode)
            4b'0110 begin // LOAD - R[rd] <- MEM[R[r1]]
                register_read_addr1 = executed_r1; // input of register
                register_read_addr2 = 3b'0; 
                // i now have register_read_data, this is the address to read
                memory_read = 1b'1;
                memory_write = 1b'0;

                memory_address = register_read_data1; // writing to memory the contents of the executed_r1
                memory_write_data = 16b'0;
            end

            4b'0111 begin // STORE - MEM[R[r1]] <- R[rd]
                register_read_addr1 = executed_rd; // input of register
                register_read_addr2 = executed_r1; 
                // i now have register_read_data (contents of rd and r1)
                memory_read = 1b'0;
                memory_write = 1b'1;

                memory_address = register_read_data2; // where memory is writing to
                memory_write_data = register_read_data1; // writing to memory the contents of the executed_r1
            end

            default: begin
                register_read_addr1 = 3b'0;
                register_read_addr2 = 3b'0;

                memory_read = 1b'0;
                memory_write = 1b'0;

                memory_address = 16b'0;
                memory_write_data = 16b'0;
            end
        endcase
    end

    always @(*) begin
        case (post_memory_opcode)
            4b'0110 begin // LOAD - R[rd] <- MEM[R[r1]]
                data_to_register = read_memory;
                register_enabling_write = 1b'1;
            end
            4'b0000: begin // ADD
                data_to_register = post_memory_alu_result;
                register_enabling_write = 1b'1;
            end

            default: begin
                data_to_register = 16b'0;
                register_enabling_write = 1b'0;
            end
        endcase
    end
 
    always @(posedge clk) begin
        // the stages follow - fetch instruction - decode instruction - execute instruction - memory op - write to register
        if (not reset) begin

            // instruction fetch
            //increment ip in cpu top every clock cycle
            fetched_instruction <= memory_output_data;

            // instruction decode
            opcode <= fetched_instruction[15:12];
            rd <= fetched_instruction[11:9];
            r1 <= fetched_instruction[8:6];
            r2 <= fetched_instruction[5:3];
            
            // execute
            executed_opcode <= opcode; // in the execute stage to be used in memory op
            executed_rd <= rd;
            executed_r1 <= r1;
            executed_alu_result <= alu_output;

            // memory op
            read_memory <= memory_data_out;
            post_memory_alu_result <= executed_alu_result;
            post_memory_opcode <= executed_opcode;
            post_memory_rd <= executed_rd;

            // write to register
            // this depends - i only write sometimes. 
            // for now, do LOAD r1 > rd and ADD alu > rd
            register_write_addr <= post_memory_rd;
            register_write_data <= data_to_register;
            register_write_enable <= 1b'1;

        end
        // move through pipeline
    end
endmodule