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

// ALU select
`define ALU_ADD     4'h0
`define ALU_SUB     4'h1
`define ALU_AND     4'h2
`define ALU_OR      4'h3
`define ALU_XOR     4'h4
`define ALU_SLL     4'h5
`define ALU_SRL     4'h6
`define ALU_SRA     4'h7
`define ALU_SLT     4'h8
`define ALU_SLTU    4'h9
`define ALU_MUL     4'hA

// Writeback select
`define WB_OFF      2'b00
`define WB_ALU      2'b01
`define WB_MEM      2'b10
`define WB_PC4      2'b11

`endif
