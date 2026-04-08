`timescale 1ns/1ps

// program.hex: compiler memory_allocator.txt + assembler; main return => r0 = 321
module cpu_memalloc_e2e_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;
    reg saw_exit;

    cpu dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            dut.data_memory.mem[i] = 16'h0000;

        for (i = 0; i < 7; i = i + 1)
            dut.register_file.r[i] = 16'h0000;
        dut.register_file.r[7] = 16'h00FF;

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;
        saw_exit = 1'b0;

        repeat (800000) begin
            @(posedge clk);
            #1;
            // .exit PC must match assembler label "exit" for this program (239 after removing trailing CALL main).
            if (!saw_exit && dut.instruction_pointer == 8'd239) begin
                saw_exit = 1'b1;
                repeat (12) begin
                    @(posedge clk);
                    #1;
                end
                $display("memalloc e2e: cy=%0d r0=%0d sp=%0d ip=%0d",
                    $time/10, dut.register_file.r[0], dut.register_file.r[7],
                    dut.instruction_pointer);
                if (dut.register_file.r[0] === 16'd321)
                    $display("PASS: r0=321");
                else
                    $display("FAIL: expected r0=321");
                $finish;
            end
        end

        $display("TIMEOUT r0=%0d sp=%0d ip=%0d", dut.register_file.r[0],
            dut.register_file.r[7], dut.instruction_pointer);
        $finish;
    end
endmodule
