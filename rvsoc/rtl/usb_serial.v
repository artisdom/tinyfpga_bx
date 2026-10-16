// USB CDC serial port for the iCE40: the usb_uart_core from third_party plus
// its pin drivers, as in third_party/usbserial/usb_uart_i40.v, with one
// addition: a host bus reset (SE0 for >625 us) also resets the core.
// Without that, the core keeps its old USB address after the host resets the
// port, and every re-enumeration attempt fails until the board is reset.

module usb_serial (
    input  wire       clk_48mhz,
    input  wire       reset,

    inout  wire       pin_usb_p,
    inout  wire       pin_usb_n,

    // device -> host
    input  wire [7:0] in_data,
    input  wire       in_valid,
    output wire       in_ready,

    // host -> device
    output wire [7:0] out_data,
    output wire       out_valid,
    input  wire       out_ready
);
    wire usb_p_tx, usb_n_tx, usb_tx_en;
    wire usb_p_in, usb_n_in;

    // While transmitting, present an idle J state to the receiver.
    wire usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    wire usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;

    wire bus_reset;
    usb_reset_det reset_det (
        .clk     (clk_48mhz),
        .reset   (bus_reset),
        .usb_p_rx(usb_p_rx),
        .usb_n_rx(usb_n_rx)
    );

    usb_uart_core core (
        .clk_48mhz     (clk_48mhz),
        .reset         (reset || bus_reset),
        .usb_p_tx      (usb_p_tx),
        .usb_n_tx      (usb_n_tx),
        .usb_p_rx      (usb_p_rx),
        .usb_n_rx      (usb_n_rx),
        .usb_tx_en     (usb_tx_en),
        .uart_in_data  (in_data),
        .uart_in_valid (in_valid),
        .uart_in_ready (in_ready),
        .uart_out_data (out_data),
        .uart_out_valid(out_valid),
        .uart_out_ready(out_ready),
        .debug         ()
    );

    SB_IO #(
        .PIN_TYPE(6'b1010_01),   // tristate output, plain input
        .PULLUP  (1'b0)
    ) iobuf_usbp (
        .PACKAGE_PIN  (pin_usb_p),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0      (usb_p_tx),
        .D_IN_0       (usb_p_in)
    );

    SB_IO #(
        .PIN_TYPE(6'b1010_01),
        .PULLUP  (1'b0)
    ) iobuf_usbn (
        .PACKAGE_PIN  (pin_usb_n),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0      (usb_n_tx),
        .D_IN_0       (usb_n_in)
    );
endmodule
