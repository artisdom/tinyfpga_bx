// A tiny command shell for the PicoRV32 SoC, spoken over USB serial.

#include <stdint.h>

#define CPU_HZ 24000000u

#define REG(addr) (*(volatile uint32_t *)(addr))
#define LED       REG(0x10000000)
#define UART_DATA REG(0x20000000)
#define UART_STAT REG(0x20000004)
#define RX_READY  (1u << 0)
#define TX_READY  (1u << 1)

// clang may emit calls to these for struct/array copies.
void *memset(void *dst, int c, unsigned n)
{
    uint8_t *d = dst;
    while (n--) *d++ = (uint8_t)c;
    return dst;
}

void *memcpy(void *dst, const void *src, unsigned n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (n--) *d++ = *s++;
    return dst;
}

// ---------------------------------------------------------------- console

static void put_char(char c)
{
    while (!(UART_STAT & TX_READY)) {}
    UART_DATA = (uint8_t)c;
}

static void put_str(const char *s)
{
    while (*s) {
        if (*s == '\n') put_char('\r');
        put_char(*s++);
    }
}

static int get_char(void)
{
    while (!(UART_STAT & RX_READY)) {}
    return UART_DATA & 0xff;
}

static void put_dec(uint32_t v)
{
    char buf[11];
    int i = 0;
    do {
        buf[i++] = '0' + v % 10;
        v /= 10;
    } while (v);
    while (i) put_char(buf[--i]);
}

static void put_hex(uint32_t v)
{
    put_str("0x");
    for (int i = 28; i >= 0; i -= 4)
        put_char("0123456789abcdef"[(v >> i) & 0xf]);
}

// ---------------------------------------------------------------- timing

static uint64_t cycles(void)
{
    uint32_t hi, lo, hi2;
    do {
        __asm__ volatile ("rdcycleh %0" : "=r"(hi));
        __asm__ volatile ("rdcycle %0"  : "=r"(lo));
        __asm__ volatile ("rdcycleh %0" : "=r"(hi2));
    } while (hi != hi2);
    return ((uint64_t)hi << 32) | lo;
}

// The CPU has 32-bit divide only, so divide the 64-bit count bit by bit.
// Saturates after 2^32 ms (about 49 days).
static uint32_t cycles_to_ms(uint64_t c)
{
    const uint32_t per_ms = CPU_HZ / 1000;
    if ((c >> 32) >= per_ms) return 0xffffffff;
    uint32_t q = 0;
    for (int bit = 31; bit >= 0; bit--) {
        uint64_t t = (uint64_t)per_ms << bit;
        if (c >= t) { c -= t; q |= 1u << bit; }
    }
    return q;
}

static void put_ms(uint32_t ms)
{
    put_dec(ms / 1000);
    put_char('.');
    uint32_t frac = ms % 1000;
    put_char('0' + frac / 100);
    put_char('0' + frac / 10 % 10);
    put_char('0' + frac % 10);
    put_str(" s");
}

static void delay_ms(uint32_t ms)
{
    uint64_t end = cycles() + (uint64_t)ms * (CPU_HZ / 1000);
    while (cycles() < end) {}
}

// ---------------------------------------------------------------- parsing

static int streq(const char *a, const char *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

// Splits the line in place on spaces; returns the number of words.
static int split(char *s, char **argv, int max)
{
    int n = 0;
    while (*s && n < max) {
        while (*s == ' ') *s++ = 0;
        if (!*s) break;
        argv[n++] = s;
        while (*s && *s != ' ') s++;
    }
    return n;
}

// Decimal, or hex with a 0x prefix. Returns 0 on a malformed number.
static int parse_u32(const char *s, uint32_t *out)
{
    uint32_t v = 0, base = 10;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; s += 2; }
    if (!*s) return 0;
    for (; *s; s++) {
        uint32_t d;
        if (*s >= '0' && *s <= '9')                    d = *s - '0';
        else if (base == 16 && *s >= 'a' && *s <= 'f') d = *s - 'a' + 10;
        else if (base == 16 && *s >= 'A' && *s <= 'F') d = *s - 'A' + 10;
        else return 0;
        v = v * base + d;
    }
    *out = v;
    return 1;
}

// ---------------------------------------------------------------- commands

static void cmd_help(void)
{
    put_str("commands:\n"
         "  help                 this list\n"
         "  info                 what this machine is\n"
         "  led [on|off|toggle]  show or set the LED\n"
         "  blink [n]            blink the LED n times (default 5)\n"
         "  uptime               time since reset\n"
         "  peek <addr>          read a 32-bit word\n"
         "  poke <addr> <value>  write a 32-bit word\n"
         "  primes [n]           count primes below n, timed\n"
         "  mandel               draw the Mandelbrot set, timed\n");
}

static void cmd_info(void)
{
    put_str("PicoRV32 RV32IM @ 24 MHz on a Lattice iCE40LP8K (TinyFPGA BX)\n"
         "  0x00000000  RAM, 8 KB (code, data and stack)\n"
         "  0x10000000  LED\n"
         "  0x20000000  USB serial data\n"
         "  0x20000004  USB serial status (bit0 rx ready, bit1 tx ready)\n");
}

static void cmd_led(int argc, char **argv)
{
    if (argc > 1) {
        if (streq(argv[1], "on"))          LED = 1;
        else if (streq(argv[1], "off"))    LED = 0;
        else if (streq(argv[1], "toggle")) LED = !LED;
        else { put_str("usage: led [on|off|toggle]\n"); return; }
    }
    put_str(LED ? "led is on\n" : "led is off\n");
}

static void cmd_blink(int argc, char **argv)
{
    uint32_t n = 5;
    if (argc > 1 && !parse_u32(argv[1], &n)) { put_str("usage: blink [n]\n"); return; }
    uint32_t was = LED;
    for (uint32_t i = 0; i < n; i++) {
        LED = !was; delay_ms(150);
        LED = was;  delay_ms(150);
    }
}

static void cmd_uptime(void)
{
    put_str("up ");
    put_ms(cycles_to_ms(cycles()));
    put_char('\n');
}

static void cmd_peek(int argc, char **argv)
{
    uint32_t addr;
    if (argc != 2 || !parse_u32(argv[1], &addr)) { put_str("usage: peek <addr>\n"); return; }
    put_hex(addr); put_str(": "); put_hex(REG(addr & ~3u)); put_char('\n');
}

static void cmd_poke(int argc, char **argv)
{
    uint32_t addr, val;
    if (argc != 3 || !parse_u32(argv[1], &addr) || !parse_u32(argv[2], &val)) {
        put_str("usage: poke <addr> <value>\n");
        return;
    }
    REG(addr & ~3u) = val;
}

static void cmd_primes(int argc, char **argv)
{
    uint32_t n = 10000;
    if (argc > 1 && !parse_u32(argv[1], &n)) { put_str("usage: primes [n]\n"); return; }

    uint64_t t0 = cycles();
    uint32_t count = 0;
    for (uint32_t i = 2; i < n; i++) {
        int prime = 1;
        for (uint32_t d = 2; d * d <= i; d++)
            if (i % d == 0) { prime = 0; break; }
        count += prime;
    }
    uint64_t dt = cycles() - t0;

    put_dec(count); put_str(" primes below "); put_dec(n);
    put_str(" in "); put_ms(cycles_to_ms(dt)); put_char('\n');
}

// Fixed point with 12 fraction bits: values stay below 2^31 even right
// after a point escapes (|z| <= 6.5, so z^2 < 2^30 in this format).
#define FRAC 12
#define FIX(x) ((int32_t)((x) * (1 << FRAC)))

static void cmd_mandel(void)
{
    static const char shade[] = " .:-=+*#%@";
    const int w = 72, h = 28, max_iter = 40;
    const int32_t x0 = FIX(-2.2), x1 = FIX(0.8), y0 = FIX(-1.2), y1 = FIX(1.2);

    uint64_t t0 = cycles();
    for (int row = 0; row < h; row++) {
        int32_t ci = y0 + (y1 - y0) * row / (h - 1);
        for (int col = 0; col < w; col++) {
            int32_t cr = x0 + (x1 - x0) * col / (w - 1);
            int32_t zr = 0, zi = 0;
            int i = 0;
            for (; i < max_iter; i++) {
                int32_t zr2 = (zr * zr) >> FRAC;
                int32_t zi2 = (zi * zi) >> FRAC;
                if (zr2 + zi2 > FIX(4)) break;
                zi = ((2 * zr * zi) >> FRAC) + ci;
                zr = zr2 - zi2 + cr;
            }
            put_char(i == max_iter ? ' ' : shade[i % (sizeof shade - 2) + 1]);
        }
        put_str("\n");
    }
    uint64_t dt = cycles() - t0;
    put_str("drawn in "); put_ms(cycles_to_ms(dt)); put_char('\n');
}

static void run(char *line)
{
    char *argv[4];
    int argc = split(line, argv, 4);
    if (!argc) return;

    const char *c = argv[0];
    if      (streq(c, "help"))   cmd_help();
    else if (streq(c, "info"))   cmd_info();
    else if (streq(c, "led"))    cmd_led(argc, argv);
    else if (streq(c, "blink"))  cmd_blink(argc, argv);
    else if (streq(c, "uptime")) cmd_uptime();
    else if (streq(c, "peek"))   cmd_peek(argc, argv);
    else if (streq(c, "poke"))   cmd_poke(argc, argv);
    else if (streq(c, "primes")) cmd_primes(argc, argv);
    else if (streq(c, "mandel")) cmd_mandel();
    else { put_str("unknown command '"); put_str(c); put_str("', try help\n"); }
}

// ---------------------------------------------------------------- main

int main(void)
{
    char line[64];
    int len = 0;

    LED = 1;

    // Stay silent until the first keypress. A host that opens the port with
    // terminal echo still on would bounce anything we print straight back
    // as input, and the shell would keep answering its own output.
    get_char();
    put_str("\nPicoRV32 on TinyFPGA BX -- type 'help'\n> ");

    for (;;) {
        int c = get_char();
        if (c == '\r' || c == '\n') {
            put_str("\n");
            line[len] = 0;
            run(line);
            len = 0;
            put_str("> ");
        } else if (c == 0x7f || c == '\b') {
            if (len) { len--; put_str("\b \b"); }
        } else if (c >= ' ' && c < 0x7f && len < (int)sizeof line - 1) {
            line[len++] = c;
            put_char(c);
        }
    }
}
