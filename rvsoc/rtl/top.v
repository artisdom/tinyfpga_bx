// TinyFPGA BX top level: PicoRV32 SoC at 24 MHz with a USB CDC serial port
// (48 MHz) that shows up on the host as /dev/ttyACM*.

module top (
    input  wire CLK,      // 16 MHz oscillator
    output wire LED,
    inout  wire USBP,
    inout  wire USBN,
    output wire USBPU     // 1.5k pull-up on D+, high = attach to the host
);
    wire clk_48mhz, clk_24mhz;
    wire pll_locked;

    pll pll (
        .clock_in (CLK),
        .clk_48mhz(clk_48mhz),
        .clk_24mhz(clk_24mhz),
        .locked   (pll_locked)
    );

    // Hold everything in reset for a while after the PLL locks.
    reg [5:0] reset_cnt = 0;
    wire      usb_reset = !reset_cnt[5];
    always @(posedge clk_48mhz)
        if (pll_locked)
            reset_cnt <= reset_cnt + usb_reset;

    reg [1:0] cpu_resetn = 0;
    always @(posedge clk_24mhz)
        cpu_resetn <= {cpu_resetn[0], !usb_reset};

    // CPU <-> clock-domain crossing <-> USB serial
    wire [7:0] cpu_tx_data, cpu_rx_data, usb_tx_data, usb_rx_data;
    wire       cpu_tx_valid, cpu_tx_ready, cpu_rx_valid, cpu_rx_ready;
    wire       usb_tx_valid, usb_tx_ready, usb_rx_valid, usb_rx_ready;

    soc soc (
        .clk     (clk_24mhz),
        .resetn  (cpu_resetn[1]),
        .led     (LED),
        .tx_data (cpu_tx_data),
        .tx_valid(cpu_tx_valid),
        .tx_ready(cpu_tx_ready),
        .rx_data (cpu_rx_data),
        .rx_valid(cpu_rx_valid),
        .rx_ready(cpu_rx_ready)
    );

    stream_cdc to_usb (
        .src_clk  (clk_24mhz),
        .src_data (cpu_tx_data),
        .src_valid(cpu_tx_valid),
        .src_ready(cpu_tx_ready),
        .dst_clk  (clk_48mhz),
        .dst_data (usb_tx_data),
        .dst_valid(usb_tx_valid),
        .dst_ready(usb_tx_ready)
    );

    stream_cdc from_usb (
        .src_clk  (clk_48mhz),
        .src_data (usb_rx_data),
        .src_valid(usb_rx_valid),
        .src_ready(usb_rx_ready),
        .dst_clk  (clk_24mhz),
        .dst_data (cpu_rx_data),
        .dst_valid(cpu_rx_valid),
        .dst_ready(cpu_rx_ready)
    );

    usb_serial usb (
        .clk_48mhz(clk_48mhz),
        .reset    (usb_reset),
        .pin_usb_p(USBP),
        .pin_usb_n(USBN),
        .in_data  (usb_tx_data),
        .in_valid (usb_tx_valid),
        .in_ready (usb_tx_ready),
        .out_data (usb_rx_data),
        .out_valid(usb_rx_valid),
        .out_ready(usb_rx_ready)
    );

    assign USBPU = 1'b1;
endmodule
