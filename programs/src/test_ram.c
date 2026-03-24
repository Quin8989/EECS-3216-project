// RAM byte/half/word access test
// Reports results via VGA ONLY (no UART to avoid blocking)

#define RAM_BASE    ((volatile unsigned char *)0x02000100)
#define VRAM        ((volatile unsigned int *)0x30000000)

static void vga_puts(int row, const char *s) {
    volatile unsigned int *p = VRAM + row * 80;
    while (*s) *p++ = *s++;
}

static void vga_putc(int row, int col, char c) {
    VRAM[row * 80 + col] = c;
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
    // Show banner immediately (test that we even reach main)
    vga_putc(0, 0, 'R');
    vga_putc(0, 1, 'A');
    vga_putc(0, 2, 'M');
    vga_putc(0, 3, ' ');
    vga_putc(0, 4, 'T');
    vga_putc(0, 5, 'E');
    vga_putc(0, 6, 'S');
    vga_putc(0, 7, 'T');
    
    int total = 0;
    
    // Test bytes
    if (test_bytes()) { vga_putc(2, 0, 'B'); vga_putc(2, 1, 'F'); total++; }
    else { vga_putc(2, 0, 'B'); vga_putc(2, 1, 'P'); }
    
    // Test halfs
    if (test_halfs()) { vga_putc(3, 0, 'H'); vga_putc(3, 1, 'F'); total++; }
    else { vga_putc(3, 0, 'H'); vga_putc(3, 1, 'P'); }
    
    // Test words
    if (test_words()) { vga_putc(4, 0, 'W'); vga_putc(4, 1, 'F'); total++; }
    else { vga_putc(4, 0, 'W'); vga_putc(4, 1, 'P'); }
    
    // Test mixed
    if (test_mixed()) { vga_putc(5, 0, 'M'); vga_putc(5, 1, 'F'); total++; }
    else { vga_putc(5, 0, 'M'); vga_putc(5, 1, 'P'); }
    
    // Test stack
    if (test_stack()) { vga_putc(6, 0, 'S'); vga_putc(6, 1, 'F'); total++; }
    else { vga_putc(6, 0, 'S'); vga_putc(6, 1, 'P'); }
    
    // Summary
    if (total == 0) {
        vga_putc(8, 0, 'O');
        vga_putc(8, 1, 'K');
    } else {
        vga_putc(8, 0, 'E');
        vga_putc(8, 1, 'R');
        vga_putc(8, 2, 'R');
    }
    
    while(1);
    return 0;
}
