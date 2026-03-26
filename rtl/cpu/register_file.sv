// ============================================================
// register_file.sv — RISC-V x0–x31 integer register file
//
// Purpose:
//   Stores the 32 general-purpose 32-bit integer registers
//   (x0–x31) defined by the RISC-V ISA.  x0 is hardwired to
//   zero — writes to it are silently discarded.
//
// Read ports (combinational):
//   rs1_o and rs2_o are valid the same cycle rs1_i/rs2_i are
//   presented; no pipeline register here.
//
// Write port (synchronous, rising edge):
//   Clocked write to registers[rd_i] with wb_data_i.
//   Write is suppressed when:
//     - wen_i is deasserted (rd has no writeback this instruction), OR
//     - rd_i == 0 (x0 hardwired-zero rule), OR
//     - any_stall_i is asserted (stall cycle — instruction has not
//       completed; writing now would corrupt state)
//
// Inputs:
//   clk, reset
//   rs1_i, rs2_i   — source register indices (from decode.sv)
//   rd_i           — destination register index (from decode.sv)
//   wb_data_i      — data to write (from writeback.sv)
//   wen_i          — write enable (regwren from control.sv)
//   any_stall_i    — global stall: suppresses write (from cpu.sv)
//
// Outputs:
//   rs1_o, rs2_o   — read data (to operand muxes in cpu.sv)
//   registers_o    — full file exposed for testbench hierarchical
//                    access (dut.u_cpu.u_rf.registers_o[3] reads x3)
// ============================================================
`include "constants.svh"

module register_file #(
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    // Read ports
    input  logic [4:0]        rs1_i,       // source 1 index
    input  logic [4:0]        rs2_i,       // source 2 index
    output logic [DWIDTH-1:0] rs1_o,       // source 1 data
    output logic [DWIDTH-1:0] rs2_o,       // source 2 data

    // Write port
    input  logic [4:0]        rd_i,        // destination index
    input  logic [DWIDTH-1:0] wb_data_i,   // value to write
    input  logic              wen_i,       // write enable from control
    input  logic              any_stall_i, // suppress write during stall

    // Full register array exposed for testbench visibility
    output logic [DWIDTH-1:0] registers_o [0:31]
);

    logic [DWIDTH-1:0] registers [0:31];

    // Expose for testbench hierarchical reference (dut.u_cpu.u_rf.registers_o)
    assign registers_o = registers;

    // Combinational read — zero-latency, no forwarding needed (single-cycle)
    assign rs1_o = registers[rs1_i];
    assign rs2_o = registers[rs2_i];

    // Gated write enable: suppress during stalls and for x0
    logic actual_wen;
    assign actual_wen = wen_i & ~any_stall_i;

    always_ff @(posedge clk) begin
        if (reset) begin
            // Clear all registers on reset (x0 stays 0 forever after)
            for (int i = 0; i < 32; i++)
                registers[i] <= '0;
        end else if (actual_wen && (rd_i != 5'd0)) begin
            // x0 is hardwired zero: the ISA requires writes to x0 be ignored
            registers[rd_i] <= wb_data_i;
        end
    end

endmodule : register_file
