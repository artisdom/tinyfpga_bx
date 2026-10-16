// Minimal PicoRV32 system-on-chip.
//
// Memory map
//   0x0000_0000  RAM, MEM_WORDS x 32 bit, preloaded with the firmware image
//   0x1000_0000  LED       write bit 0 to set, read back current state
//   0x2000_0000  UART data write: send a byte; read: take the received byte
//   0x2000_0004  UART stat bit 0 = received byte waiting, bit 1 = ready to send
//
// The UART side is a pair of valid/ready byte streams, so the same SoC runs on
// the USB serial core in hardware and on a simple model in simulation.

module soc #(
    parameter MEM_WORDS = 2048,
    parameter FIRMWARE  = "build/firmware.hex"   // relative to rvsoc/
) (
    input  wire       clk,
    input  wire       resetn,
    output reg        led,

    // CPU -> host
    output reg  [7:0] tx_data,
    output reg        tx_valid,
    input  wire       tx_ready,

    // host -> CPU
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output wire       rx_ready
);
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire  [3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (1),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT     (1),
        .BARREL_SHIFTER      (0),
        .CATCH_MISALIGN      (0),
        .CATCH_ILLINSN       (0),
        .COMPRESSED_ISA      (0),
        .ENABLE_MUL          (1),
        .ENABLE_DIV          (1),
        .ENABLE_IRQ          (0),
        .PROGADDR_RESET      (32'h0000_0000),
        .STACKADDR           (MEM_WORDS * 4)
    ) cpu (
        .clk      (clk),
        .resetn   (resetn),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    reg [31:0] mem [0:MEM_WORDS-1];
    initial $readmemh(FIRMWARE, mem);

    wire [$clog2(MEM_WORDS)-1:0] word = mem_addr[$clog2(MEM_WORDS)+1:2];

    wire sel_ram  = mem_addr[31:28] == 4'h0;
    wire sel_led  = mem_addr[31:28] == 4'h1;
    wire sel_uart = mem_addr[31:28] == 4'h2;
    wire uart_reg = mem_addr[2];             // 0 = data, 1 = status

    // RAM: a plain synchronous port so yosys maps it onto block RAM.
    wire       access = mem_valid && !mem_ready;
    reg [31:0] ram_rdata;
    always @(posedge clk) begin
        ram_rdata <= mem[word];
        if (access && sel_ram) begin
            if (mem_wstrb[0]) mem[word][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) mem[word][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) mem[word][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[word][31:24] <= mem_wdata[31:24];
        end
    end

    // One received byte is buffered until the CPU reads the data register.
    reg [7:0] rx_buf;
    reg       rx_full;
    assign rx_ready = !rx_full;

    reg        ram_read;
    reg [31:0] io_rdata;
    assign mem_rdata = ram_read ? ram_rdata : io_rdata;

    always @(posedge clk) begin
        if (tx_valid && tx_ready)
            tx_valid <= 1'b0;
        if (rx_valid && rx_ready) begin
            rx_buf  <= rx_data;
            rx_full <= 1'b1;
        end

        // Every access completes in one cycle; mem_ready pulses for one clock.
        mem_ready <= access;
        if (access) begin
            ram_read <= sel_ram;
            io_rdata <= 32'h0;

            if (sel_led) begin
                io_rdata <= {31'b0, led};
                if (mem_wstrb[0]) led <= mem_wdata[0];
            end

            if (sel_uart) begin
                if (uart_reg) begin
                    io_rdata <= {30'b0, !tx_valid, rx_full};
                end else if (|mem_wstrb) begin
                    // Firmware polls the status bit first, so tx_valid is low here.
                    tx_data  <= mem_wdata[7:0];
                    tx_valid <= 1'b1;
                end else begin
                    io_rdata <= {24'b0, rx_buf};
                    rx_full  <= 1'b0;
                end
            end
        end

        if (!resetn) begin
            mem_ready <= 1'b0;
            led       <= 1'b0;
            tx_valid  <= 1'b0;
            rx_full   <= 1'b0;
        end
    end
endmodule
