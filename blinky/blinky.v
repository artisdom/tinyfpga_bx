// Breathing LED for the TinyFPGA BX.
//
// A free-running counter at 16 MHz drives two things:
//   - a slow 8-bit triangle wave (the brightness envelope, ~2 s per breath)
//   - a fast 16-bit PWM ramp (~244 Hz, too fast to see flicker)
// Brightness is squared before comparing so the fade looks linear to the eye.

module top (
    input  wire CLK,    // 16 MHz on-board oscillator
    output wire LED,    // user LED
    output wire USBPU   // USB pull-up; drive low so the host sees no device
);
    assign USBPU = 1'b0;

    reg [24:0] counter = 0;
    always @(posedge CLK)
        counter <= counter + 1'b1;

    // Triangle wave: ramp up while bit 24 is 0, ramp down while it is 1.
    wire [7:0] ramp       = counter[23:16];
    wire [7:0] brightness = counter[24] ? ~ramp : ramp;

    // Gamma ~2: perceived brightness grows roughly with the square.
    wire [15:0] duty = brightness * brightness;

    assign LED = counter[15:0] < duty;
endmodule
