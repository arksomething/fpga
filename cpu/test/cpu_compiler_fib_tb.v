`timescale 1ns/1ps

module cpu_compiler_fib_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

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

        repeat (10000) begin
            @(posedge clk);
            #1;
            if (dut.instruction_pointer >= 43) begin
                $display("DONE at cy=%0d: r0=%0d r1=%0d r2=%0d sp=%0d ip=%0d",
                    $time/10, dut.register_file.r[0], dut.register_file.r[1],
                    dut.register_file.r[2], dut.register_file.r[7],
                    dut.instruction_pointer);
                if (dut.register_file.r[7] === 16'd255)
                    $display("SP restored OK");
                $finish;
            end
        end

        $display("TIMEOUT: r0=%0d r1=%0d r2=%0d sp=%0d ip=%0d",
            dut.register_file.r[0], dut.register_file.r[1], dut.register_file.r[2],
            dut.register_file.r[7], dut.instruction_pointer);
        $finish;
    end
endmodule
