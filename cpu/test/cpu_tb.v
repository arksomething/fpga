module cpu_tb();
    reg clk = 0;
    reg reset = 1;

    cpu_top DUT (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;   // 100 MHz clock

    initial begin
        $dumpfile("test/cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
        #20 reset = 0;
        #5000 $stop;
    end
endmodule

