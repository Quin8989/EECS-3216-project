// ============================================================
// writeback.sv — Write-back source multiplexer
//
// Purpose:
//   Selects the value to write back to the register file.
//   Three possible sources exist:
//     WB_ALU  (wbsel == 2'b01) — ALU result (arithmetic, logic, loads addr)
//     WB_MEM  (wbsel == 2'b10) — data read from data memory (load result)
//     WB_PC4  (wbsel == 2'b11) — PC+4 (return address for JAL / JALR)
//
// Inputs:
//   wbsel_i    — from control.sv; selects which source to commit
//   alu_res_i  — from alu.sv; ALU computation result
//   dmem_rdata_i — from data bus (mem_map.sv); load instruction result
//   pc_i       — from fetch.sv; current instruction's PC
//
// Output:
//   wb_data_o — routed back to register_file.sv as wb_data_i
//
// Timing note:
//   For loads, cpu.sv asserts a load_wb flag on the cycle after
//   the load address is sent.  By that cycle dmem_rdata_i is
//   valid and wbsel is still WB_MEM, so the correct data is
//   latched into the register file.
//
// Connected to:
//   upstream  : alu.sv (alu_res_i), mem_map.sv (dmem_rdata_i),
//               fetch.sv (pc_i)
//   downstream: register_file.sv (wb_data_i / wen_i)
// ============================================================
`include "constants.svh"

module writeback (
    input  logic [1:0]  wbsel_i,      // write-back source select
    input  logic [31:0] alu_res_i,    // from alu.sv
    input  logic [31:0] dmem_rdata_i, // from data bus (load data)
    input  logic [31:0] pc_i,         // current PC, from fetch.sv

    output logic [31:0] wb_data_o     // value to write into rd
);

    always_comb begin
        unique case (wbsel_i)
            `WB_ALU: wb_data_o = alu_res_i;           // arithmetic / logic / address
            `WB_MEM: wb_data_o = dmem_rdata_i;        // load result from memory
            `WB_PC4: wb_data_o = pc_i + 32'd4;        // return address: PC+4
            default: wb_data_o = alu_res_i;
        endcase
    end

endmodule : writeback
