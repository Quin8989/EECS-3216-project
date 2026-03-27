`ifndef CONSTANTS_SVH_
`define CONSTANTS_SVH_

// Opcodes
`define OPC_RTYPE   7'b011_0011
`define OPC_ITYPE   7'b001_0011
`define OPC_LOAD    7'b000_0011
`define OPC_STORE   7'b010_0011
`define OPC_BRANCH  7'b110_0011
`define OPC_JAL     7'b110_1111
`define OPC_JALR    7'b110_0111
`define OPC_LUI     7'b011_0111
`define OPC_AUIPC   7'b001_0111
`define OPC_FENCE   7'b000_1111
`define OPC_SYSTEM  7'b111_0011

// Funct7
`define FUNCT7_ALT  7'h20
`define FUNCT7_M    7'h01

// Funct3 (R/I-type)
`define F3_ADD_SUB  3'h0
`define F3_SLL      3'h1
`define F3_SLT      3'h2
`define F3_SLTU     3'h3
`define F3_XOR      3'h4
`define F3_SRL_SRA  3'h5
`define F3_OR       3'h6
`define F3_AND      3'h7

// Funct3 (branches)
`define F3_BEQ      3'b000
`define F3_BNE      3'b001
`define F3_BLT      3'b100
`define F3_BGE      3'b101
`define F3_BLTU     3'b110
`define F3_BGEU     3'b111

// Funct3 (load/store)
`define F3_BYTE     3'b000
`define F3_HALF     3'b001
`define F3_WORD     3'b010
`define F3_BYTEU    3'b100
`define F3_HALFU    3'b101

// ALU select (5-bit to accommodate full RV32M)
`define ALU_ADD     5'h00
`define ALU_SUB     5'h01
`define ALU_AND     5'h02
`define ALU_OR      5'h03
`define ALU_XOR     5'h04
`define ALU_SLL     5'h05
`define ALU_SRL     5'h06
`define ALU_SRA     5'h07
`define ALU_SLT     5'h08
`define ALU_SLTU    5'h09
`define ALU_MUL     5'h0A
`define ALU_MULH    5'h0B
`define ALU_MULHSU  5'h0C
`define ALU_MULHU   5'h0D
`define ALU_DIV     5'h0E
`define ALU_DIVU    5'h0F
`define ALU_REM     5'h10
`define ALU_REMU    5'h11

// Writeback select
`define WB_OFF      2'b00
`define WB_ALU      2'b01
`define WB_MEM      2'b10
`define WB_PC4      2'b11

`endif
