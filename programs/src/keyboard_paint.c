#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

#define TIMER_COUNT (*(volatile unsigned int *)0x20000000)

#define KBD_DATA    (*(volatile unsigned int *)0x40000000)
#define KBD_STATUS  (*(volatile unsigned int *)0x40000004)

#define FB_BASE     ((volatile unsigned int *)0x80000000)
#define FB_WIDTH    320
#define FB_HEIGHT   240
#define FB_WORDS    (FB_WIDTH / 4)

#define TILE_SIZE   8
#define GRID_W      (FB_WIDTH / TILE_SIZE)
#define GRID_H      (FB_HEIGHT / TILE_SIZE)

#define SC_Q        0x15
#define SC_W        0x1D
#define SC_A        0x1C
#define SC_S        0x1B
#define SC_D        0x23
#define SC_E        0x24
#define SC_C        0x21
#define SC_X        0x22

static unsigned char board[GRID_H][GRID_W];
static const signed char burst_dx[8] = { 1, -1, 0, 0, 1, -1, 1, -1 };
static const signed char burst_dy[8] = { 0, 0, 1, -1, 1, 1, -1, -1 };

static unsigned char rgb332(unsigned int r, unsigned int g, unsigned int b) {
    return (unsigned char)(((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3));
}

static void uart_putc(char c) {
    while (!(UART_STATUS & 1)) {
    }
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

static void clear_screen(unsigned char color) {
    unsigned int packed = (unsigned int)color;
    int index;

    packed |= packed << 8;
    packed |= packed << 16;

    for (index = 0; index < FB_WORDS * FB_HEIGHT; index++) {
        FB_BASE[index] = packed;
    }
}

static void plot(int x, int y, unsigned char color) {
    int word_index = y * FB_WORDS + (x >> 2);
    int shift = (x & 3) << 3;
    unsigned int word = FB_BASE[word_index];
    unsigned int mask = 0xFFu << shift;

    word = (word & ~mask) | ((unsigned int)color << shift);
    FB_BASE[word_index] = word;
}

static void render_tile(int tile_x, int tile_y, int cursor_on, unsigned char cursor_color) {
    int px;
    int py;
    int x0 = tile_x * TILE_SIZE;
    int y0 = tile_y * TILE_SIZE;
    unsigned char fill = board[tile_y][tile_x];
    unsigned char border = cursor_on ? rgb332(7, 7, 3) : fill;

    if (cursor_on && fill == 0) {
        fill = cursor_color;
    }

    for (py = 0; py < TILE_SIZE; py++) {
        for (px = 0; px < TILE_SIZE; px++) {
            int border_pixel = (px == 0) || (px == TILE_SIZE - 1) || (py == 0) || (py == TILE_SIZE - 1);
            plot(x0 + px, y0 + py, border_pixel ? border : fill);
        }
    }
}

static void paint_tile(int tile_x, int tile_y, unsigned char color) {
    board[tile_y][tile_x] = color;
}

static void burst(int tile_x, int tile_y, unsigned char base_color) {
    int index;
    unsigned int timer = TIMER_COUNT;

    for (index = 0; index < 8; index++) {
        int nx = tile_x + burst_dx[index];
        int ny = tile_y + burst_dy[index];
        unsigned char color;

        if (nx < 0 || nx >= GRID_W || ny < 0 || ny >= GRID_H) {
            continue;
        }

        color = (unsigned char)(base_color + ((timer >> (index + 1)) & 0x07));
        if (color == 0) {
            color = rgb332(1, 1, 1);
        }

        paint_tile(nx, ny, color);
        render_tile(nx, ny, 0, base_color);
    }
}

int main(void) {
    static const unsigned char palette[] = {
        0,
        0xE0,
        0x1C,
        0x03,
        0xFC,
        0x9F,
        0x67,
        0xFF
    };
    int cursor_x = GRID_W / 2;
    int cursor_y = GRID_H / 2;
    int brush = 1;
    int release_next = 0;

    clear_screen(0x00);
    paint_tile(cursor_x, cursor_y, palette[brush]);
    render_tile(cursor_x, cursor_y, 1, palette[brush]);

    uart_puts("Keyboard!\r\n");
    uart_puts("WASD QE XC\r\n");

    while (1) {
        unsigned int code;
        int next_x;
        int next_y;

        if (!(KBD_STATUS & 1)) {
            continue;
        }

        code = KBD_DATA;

        if (code == 0xF0) {
            release_next = 1;
            continue;
        }

        if (release_next) {
            release_next = 0;
            continue;
        }

        next_x = cursor_x;
        next_y = cursor_y;

        if (code == SC_Q) {
            brush--;
            if (brush < 1) {
                brush = 7;
            }
            uart_putc('Q');
        } else if (code == SC_E) {
            brush++;
            if (brush > 7) {
                brush = 1;
            }
            uart_putc('E');
        } else if (code == SC_C) {
            int x;
            int y;
            for (y = 0; y < GRID_H; y++) {
                for (x = 0; x < GRID_W; x++) {
                    board[y][x] = 0;
                }
            }
            clear_screen(0x00);
            paint_tile(cursor_x, cursor_y, palette[brush]);
            uart_putc('C');
        } else if (code == SC_X) {
            burst(cursor_x, cursor_y, palette[brush]);
            uart_putc('X');
        } else {
            if (code == SC_W && cursor_y > 0) {
                next_y--;
                uart_putc('W');
            } else if (code == SC_S && cursor_y + 1 < GRID_H) {
                next_y++;
                uart_putc('S');
            } else if (code == SC_A && cursor_x > 0) {
                next_x--;
                uart_putc('A');
            } else if (code == SC_D && cursor_x + 1 < GRID_W) {
                next_x++;
                uart_putc('D');
            }

            if (next_x != cursor_x || next_y != cursor_y) {
                render_tile(cursor_x, cursor_y, 0, palette[brush]);
                cursor_x = next_x;
                cursor_y = next_y;
                paint_tile(cursor_x, cursor_y, palette[brush]);
            }
        }

        render_tile(cursor_x, cursor_y, 1, palette[brush]);
    }

    return 0;
}