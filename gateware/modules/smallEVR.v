// MIT License
//
// Copyright (c) 2106 Osprey DCS
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

`timescale 1ns / 1ns

////////////////////////////////////////////////////////////////////////////////
// Somewhat larger subset of MRF event receiver
// Based on more conventional lookup table
module smallEVR #(
    parameter ACTION_WIDTH    = 1,
    parameter DEBUG           = "false",
    parameter TIMESTAMP_WIDTH = 64
    ) (
    input  wire                                            evrRxClk,

    (*mark_debug=DEBUG*) input                      [15:0] evrRxWord,
    (*mark_debug=DEBUG*) input                       [1:0] evrCharIsK,

    (*mark_debug=DEBUG*) output wire                       ppsMarker,
    (*mark_debug=DEBUG*) output wire                       timestampValid,
    (*mark_debug=DEBUG*) output wire [TIMESTAMP_WIDTH-1:0] timestamp,
    (*mark_debug=DEBUG*) output wire                 [7:0] distributedDataBus,
    (*mark_debug=DEBUG*) output wire    [ACTION_WIDTH-1:0] action,

    input                    sysClk,
    input                    sysActionWriteEnable,
    input              [7:0] sysActionAddress,
    input [ACTION_WIDTH-1:0] sysActionData);

tinyEVRcommon #(.ACTION_RAM_WIDTH(ACTION_WIDTH),
                .EVSTROBE_COUNT(0),
                .DEBUG(DEBUG),
                .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH))
  tinyEVRcommon (
    .evrRxClk(evrRxClk),
    .evrRxWord(evrRxWord),
    .evrCharIsK(evrCharIsK),
    .ppsMarker(ppsMarker),
    .timestampValid(timestampValid),
    .timestamp(timestamp),
    .distributedDataBus(distributedDataBus),
    .action(action),
    .sysClk(sysClk),
    .sysActionWriteEnable(sysActionWriteEnable),
    .sysActionAddress(sysActionAddress),
    .sysActionData(sysActionData));
endmodule
