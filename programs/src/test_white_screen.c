// Minimal white-screen test — no UART, no test framework.
// Writes 0xFFFFFFFF (white) to every framebuffer word, then loops forever.
// If the screen shows solid white, CPU + FB + VGA path all work.

#define FB_BASE  ((volatile unsigned int *)0x80000000)
#define FB_WORDS 19200  // 320*240/4

int main(void) {
    volatile unsigned int *fb = FB_BASE;
    for (int i = 0; i < FB_WORDS; i++)
        fb[i] = 0xFFFFFFFF;
    while (1) ;
    return 0;
}
