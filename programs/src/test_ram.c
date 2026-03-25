// RAM byte/half/word access test — reports results via UART

#define RAM_BASE    ((volatile unsigned char *)0x02000100)
#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

static void uart_putc(char c) {
    while (!(UART_STATUS & 1));
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static int test_bytes(void) {
    volatile unsigned char *p = RAM_BASE;
    p[0] = 0xDE; p[1] = 0xAD; p[2] = 0xBE; p[3] = 0xEF;
    
    if (p[0] != 0xDE) return 1;
    if (p[1] != 0xAD) return 2;
    if (p[2] != 0xBE) return 3;
    if (p[3] != 0xEF) return 4;
    return 0;
}

static int test_halfs(void) {
    volatile unsigned short *p = (volatile unsigned short *)(RAM_BASE + 16);
    p[0] = 0x1234; p[1] = 0x5678;
    
    if (p[0] != 0x1234) return 1;
    if (p[1] != 0x5678) return 2;
    return 0;
}

static int test_words(void) {
    volatile unsigned int *p = (volatile unsigned int *)(RAM_BASE + 32);
    p[0] = 0xCAFEBABE;
    
    if (p[0] != 0xCAFEBABE) return 1;
    return 0;
}

static int test_mixed(void) {
    volatile unsigned int *pw = (volatile unsigned int *)(RAM_BASE + 48);
    volatile unsigned char *pb = (volatile unsigned char *)(RAM_BASE + 48);
    
    *pw = 0x44332211;
    if (pb[0] != 0x11) return 1;
    if (pb[1] != 0x22) return 2;
    if (pb[2] != 0x33) return 3;
    if (pb[3] != 0x44) return 4;
    
    pb[0] = 0xAA; pb[1] = 0xBB; pb[2] = 0xCC; pb[3] = 0xDD;
    if (*pw != 0xDDCCBBAA) return 5;
    
    return 0;
}

static int test_stack(void) {
    unsigned char a = 0x41, b = 0x42, c = 0x43, d = 0x44;
    if (a != 0x41) return 1;
    if (b != 0x42) return 2;
    if (c != 0x43) return 3;
    if (d != 0x44) return 4;
    return 0;
}

int main(void) {
    uart_puts("RAM TEST\r\n");
    int total = 0;

    if (test_bytes()) { uart_puts("Bytes  FAIL\r\n"); total++; }
    else              { uart_puts("Bytes  PASS\r\n"); }

    if (test_halfs()) { uart_puts("Halfs  FAIL\r\n"); total++; }
    else              { uart_puts("Halfs  PASS\r\n"); }

    if (test_words()) { uart_puts("Words  FAIL\r\n"); total++; }
    else              { uart_puts("Words  PASS\r\n"); }

    if (test_mixed()) { uart_puts("Mixed  FAIL\r\n"); total++; }
    else              { uart_puts("Mixed  PASS\r\n"); }

    if (test_stack()) { uart_puts("Stack  FAIL\r\n"); total++; }
    else              { uart_puts("Stack  PASS\r\n"); }

    if (total == 0)
        uart_puts("RESULT: PASS\r\n");
    else
        uart_puts("RESULT: FAIL\r\n");

    while(1);
    return 0;
}
