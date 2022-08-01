// simple stub for iverilog
module OSERDESE2 (
  output OFB,
  output OQ,
  output SHIFTOUT1,
  output SHIFTOUT2,
  output TBYTEOUT,
  output TFB,
  output TQ,

  input CLK,
  input CLKDIV,
  input D1,
  input D2,
  input D3,
  input D4,
  input D5,
  input D6,
  input D7,
  input D8,
  input OCE,
  input RST,
  input SHIFTIN1,
  input SHIFTIN2,
  input T1,
  input T2,
  input T3,
  input T4,
  input TBYTEIN,
  input TCE
);

  parameter DATA_RATE_OQ = "DDR";
  parameter DATA_RATE_TQ = "DDR";
  parameter integer DATA_WIDTH = 4;

  parameter SERDES_MODE = "MASTER";
  parameter [0:0] SRVAL_OQ = 1'b0;
  parameter [0:0] SRVAL_TQ = 1'b0;
  parameter TBYTE_CTL = "FALSE";
  parameter TBYTE_SRC = "FALSE";
  parameter integer TRISTATE_WIDTH = 4;

  endmodule
