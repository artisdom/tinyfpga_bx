// 16 MHz in -> 48 MHz (USB) and 24 MHz (CPU) out.
// Divider values from `icepll -i 16 -o 48`; port B runs at half rate.

module pll (
    input  wire clock_in,
    output wire clk_48mhz,
    output wire clk_24mhz,
    output wire locked
);
    SB_PLL40_2F_CORE #(
        .FEEDBACK_PATH      ("SIMPLE"),
        .DIVR               (4'b0000),     // DIVR =  0
        .DIVF               (7'b0101111),  // DIVF = 47
        .DIVQ               (3'b100),      // DIVQ =  4
        .FILTER_RANGE       (3'b001),      // FILTER_RANGE = 1
        .PLLOUT_SELECT_PORTA("GENCLK"),
        .PLLOUT_SELECT_PORTB("GENCLK_HALF")
    ) pll (
        .REFERENCECLK (clock_in),
        .PLLOUTGLOBALA(clk_48mhz),
        .PLLOUTGLOBALB(clk_24mhz),
        .LOCK         (locked),
        .RESETB       (1'b1),
        .BYPASS       (1'b0)
    );
endmodule
