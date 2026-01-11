module cpu_top (
    input wire clk,
    input wire reset
);
    // ----------------------------------------------------
    // PROGRAM COUNTER (8-bit) — 256-word program memory
    // ----------------------------------------------------
    reg  [7:0] pc;
    reg  [15:0] ir;       // instruction register
    wire [15:0] mem_data; // instruction from memory

    // ----------------------------------------------------
    // CONTROL UNIT WIRES
    // ----------------------------------------------------
    wire [2:0] rf_read1;
    wire [2:0] rf_read2;
    wire [2:0] rf_write;
    wire       rf_write_en;

    wire [1:0] alu_op;
    wire       pc_write;
    wire       is_mov;
    wire [1:0] write_data_sel;

    wire       alu_zero;

    // ----------------------------------------------------
    // REGISTER FILE & ALU WIRES
    // ----------------------------------------------------
    wire [15:0] rf_read_data1;
    wire [15:0] rf_read_data2;
    wire [15:0] alu_result;

    reg  [15:0] write_data;

    // ----------------------------------------------------
    // INSTRUCTION MEMORY
    // ----------------------------------------------------
    memory instr_mem (
        .clk(clk),
        .address(pc),
        .memory_write(1'b0),
        .memory_read(1'b1),  // always fetching instructions
        .data_in(16'b0),
        .data_out(mem_data)
    );

    // ----------------------------------------------------
    // CONTROL UNIT
    // ----------------------------------------------------
    cu control_unit (
        .clk(clk),
        .instruction(ir),
        .alu_zero(alu_zero),

        .read_addr1(rf_read1),
        .read_addr2(rf_read2),
        .write_addr(rf_write),
        .write_enable(rf_write_en),
        .alu_op(alu_op),
        .pc_write(pc_write),
        .ir_write(),   // unused
        .is_mov(is_mov),
        .write_data_sel(write_data_sel)
    );

    // ----------------------------------------------------
    // REGISTER FILE
    // ----------------------------------------------------
    register_file regs (
        .clk(clk),
        .read_addr1(rf_read1),
        .read_addr2(rf_read2),
        .write_addr(rf_write),
        .write_data(write_data),
        .write_enable(rf_write_en),
        .read_data1(rf_read_data1),
        .read_data2(rf_read_data2)
    );

    // ----------------------------------------------------
    // ALU
    // ----------------------------------------------------
    alu core_alu (
        .a(rf_read_data1),
        .b(rf_read_data2),
        .alu_sel(alu_op),
        .result(alu_result),
        .zero(alu_zero),
        .negative(), 
        .carry()
    );

    // ----------------------------------------------------
    // WRITE DATA MUX (ALU / MOV / IMM)
    //
    // controlled by CU.write_data_sel:
    //   00 = ALU
    //   01 = RF read_data1   (MOV)
    //   10 = imm8 (zero extended)
    // ----------------------------------------------------
    always @(*) begin
        case (write_data_sel)
            2'b00: write_data = alu_result;
            2'b01: write_data = rf_read_data1;
            2'b10: write_data = {8'b0, ir[8:1]}; // imm8 from instruction
            default: write_data = 16'b0;
        endcase
    end

    // ----------------------------------------------------
    // FETCH + PC UPDATE + IR LATCH
    // ----------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 8'b0;
            ir <= 16'b0;
        end else begin
            // latch instruction from memory into IR
            ir <= mem_data;

            // PC update
            if (pc_write) begin
                // CU signals top to load target from rf_read_data1
                pc <= rf_read_data1[7:0];
            end else begin
                pc <= pc + 1;
            end
        end
    end

endmodule
