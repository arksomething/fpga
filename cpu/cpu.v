module cpu (
    input wire clk,
    input wire reset
);
    reg  [7:0] instruction_pointer;

    wire [15:0] instruction_data;
    wire [15:0] memory_read_data;

    wire [2:0]  register_read_addr1;
    wire [2:0]  register_read_addr2;
    wire [2:0]  register_read_addr3;
    wire [15:0] register_read_data1;
    wire [15:0] register_read_data2;
    wire [15:0] register_read_data3;
    wire [2:0]  register_write_addr;
    wire [15:0] register_write_data;
    wire        register_write_enable;

    wire [7:0]  memory_address;
    wire        memory_read;
    wire        memory_write;
    wire [15:0] memory_write_data;

    wire [1:0]  alu_op;
    wire [15:0] alu_input_a;
    wire [15:0] alu_input_b;
    wire        stall;
    wire        pc_write;
    wire [7:0]  pc_write_addr;
    wire [15:0] alu_output;
    wire        alu_zero;
    wire        alu_negative;
    wire        alu_carry;
    wire [15:0] unused_pc_read_data;

    memory instruction_memory (
        .clk(clk),
        .memory_address(instruction_pointer),
        .memory_write(1'b0),
        .memory_read(1'b1),
        .data_in(16'b0),
        .data_out(instruction_data)
    );

    memory data_memory (
        .clk(clk),
        .memory_address(memory_address),
        .memory_write(memory_write),
        .memory_read(memory_read),
        .data_in(memory_write_data),
        .data_out(memory_read_data)
    );

    register register_file (
        .clk(clk),
        .read_addr1(register_read_addr1),
        .read_addr2(register_read_addr2),
        .read_addr3(register_read_addr3),
        .pc_read_addr(3'b000),
        .write_addr(register_write_addr),
        .write_data(register_write_data),
        .write_enable(register_write_enable),
        .read_data1(register_read_data1),
        .read_data2(register_read_data2),
        .read_data3(register_read_data3),
        .pc_read_data(unused_pc_read_data)
    );

    alu core_alu (
        .a(alu_input_a),
        .b(alu_input_b),
        .alu_sel(alu_op),
        .result(alu_output),
        .zero(alu_zero),
        .negative(alu_negative),
        .carry(alu_carry)
    );

    cu control_unit (
        .clk(clk),
        .reset(reset),
        .instruction_pointer(instruction_pointer),
        .instruction_data(instruction_data),
        .alu_output(alu_output),
        .alu_zero(alu_zero),
        .alu_carry(alu_carry),
        .alu_negative(alu_negative),
        .register_read_data1(register_read_data1),
        .register_read_data2(register_read_data2),
        .register_read_data3(register_read_data3),
        .register_read_addr1(register_read_addr1),
        .register_read_addr2(register_read_addr2),
        .register_read_addr3(register_read_addr3),
        .register_write_data(register_write_data),
        .register_write_addr(register_write_addr),
        .register_write_enable(register_write_enable),
        .memory_read_data(memory_read_data),
        .memory_read(memory_read),
        .memory_write(memory_write),
        .memory_address(memory_address),
        .memory_write_data(memory_write_data),
        .alu_input_a(alu_input_a),
        .alu_input_b(alu_input_b),
        .stall(stall),
        .pc_write(pc_write),
        .pc_write_addr(pc_write_addr),
        .alu_op(alu_op)
    );

    always @(posedge clk) begin
        if (reset)
            instruction_pointer <= 8'b0;
        else if (!stall) begin
            if (!pc_write) 
                instruction_pointer <= instruction_pointer + 1'b1;
            else
                instruction_pointer <= pc_write_addr;
            
        end
    end
endmodule
    