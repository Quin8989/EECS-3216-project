// test_uart_poll.c — Minimal test: poll UART status, write one FB word.
// If UART polling hangs, we'll see it in the waveform.

#define UART_STATUS ((volatile unsigned int *)0x10000004)
#define UART_TX     ((volatile unsigned int *)0x10000000)
#define FB_BASE     ((volatile unsigned int *)0x80000000)

int main(void) {
    // Poll UART tx_ready
    while (!(*UART_STATUS & 1))
        ;
    // Write a character
    *UART_TX = 'H';

    // Poll again for second char
    while (!(*UART_STATUS & 1))
        ;
    *UART_TX = 'i';

    // Write a pattern to first FB word
    FB_BASE[0] = 0xDEADBEEF;
    FB_BASE[1] = 0x12345678;

    return 1;  // PASS
}
