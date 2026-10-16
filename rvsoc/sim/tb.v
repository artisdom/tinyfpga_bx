// Simulation: the SoC with the USB core replaced by a byte-stream model.
// Types a fixed script into the shell and prints everything the CPU sends.

`timescale 1ns / 1ps

module tb;
    reg clk = 0;
    always #20.8333 clk = !clk;   // 24 MHz

    reg resetn = 0;
    initial #200 resetn = 1;

    wire       led;
    wire [7:0] tx_data;
    wire       tx_valid;
    reg  [7:0] rx_data;
    reg        rx_valid = 0;
    wire       rx_ready;

    soc dut (
        .clk     (clk),
        .resetn  (resetn),
        .led     (led),
        .tx_data (tx_data),
        .tx_valid(tx_valid),
        .tx_ready(1'b1),
        .rx_data (rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready)
    );

    always @(posedge clk)
        if (tx_valid) $write("%c", tx_data);

    always @(led) if (resetn) $display("\n[tb] LED = %0d", led);

    // Bytes typed into the shell, one character at a time. The first CR wakes
    // the shell up; it prints nothing before that.
    localparam SCRIPT = "\015help\015led toggle\015peek 0x10000000\015poke 0x10000000 0\015led\015primes 500\015bogus\015";
    localparam LEN = $bits(SCRIPT) / 8;

    integer i;
    initial begin
        @(posedge resetn);
        for (i = LEN - 1; i >= 0; i = i - 1) begin
            repeat (2000) @(posedge clk);
            rx_data  <= SCRIPT >> (i * 8);
            rx_valid <= 1;
            @(posedge clk);
            while (!rx_ready) @(posedge clk);
            rx_valid <= 0;
            // Give each command time to finish before typing the next.
            if (((SCRIPT >> (i * 8)) & 8'hff) == 8'h0d) wait_idle();
        end
        wait_idle();
        $display("\n[tb] done after %0d cycles", dut.cpu.count_cycle);
        $finish;
    end

    // Wait until the CPU has been silent for a while (it is waiting for input).
    task wait_idle;
        integer quiet;
        begin
            quiet = 0;
            while (quiet < 20000) begin
                @(posedge clk);
                quiet = tx_valid ? 0 : quiet + 1;
            end
        end
    endtask

    initial begin
        #2_000_000_000;   // 2 s of simulated time
        $display("\n[tb] timeout");
        $finish;
    end
endmodule
