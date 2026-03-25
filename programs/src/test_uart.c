// UART peripheral test
//
// Verifies the TX status register and basic transmit path.
// Since we use UART to report results, this is partly a self-test — if
// you can read the output, the UART is at least partially working.

#include "soc.h"

// TX should be ready when idle (no ongoing transmission).
static int test_tx_ready_idle(void) {
    // Wait for any in-flight byte to finish
    while (!(UART_STATUS & 1))
        ;
    unsigned int status = UART_STATUS;
    test_assert(status & 1, "tx_ready not set when idle");
    return 0;
}

// After sending a byte, TX should briefly go not-ready, then return ready.
static int test_tx_busy_then_ready(void) {
    // Ensure idle first
    while (!(UART_STATUS & 1))
        ;
    // Send a character
    UART_TX = 'X';
    // Immediately check — should be busy (not ready).
    // Note: at 25 MHz / 115200 baud, one bit = 217 cycles, full byte ~2170 cycles.
    // A single read takes ~4 cycles, so we should catch it busy.
    unsigned int busy = UART_STATUS;
    test_assert(!(busy & 1), "tx_ready still set immediately after write");

    // Now wait for it to become ready again
    int timeout = 100000;
    while (!(UART_STATUS & 1) && --timeout > 0)
        ;
    test_assert(timeout > 0, "tx never became ready again");
    return 0;
}

// Send a known string and verify we don't hang (tx_ready always eventually set).
static int test_tx_string(void) {
    const char *msg = "UART OK\r\n";
    const char *p = msg;
    while (*p) {
        int timeout = 100000;
        while (!(UART_STATUS & 1) && --timeout > 0)
            ;
        test_assert(timeout > 0, "tx stalled mid-string");
        UART_TX = (unsigned int)*p++;
    }
    return 0;
}

int main(void) {
    test_begin("UART TEST");
    test_run(test_tx_ready_idle);
    test_run(test_tx_busy_then_ready);
    test_run(test_tx_string);
    return test_end();
}
