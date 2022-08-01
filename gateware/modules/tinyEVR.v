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
// Very small subset of MRF event receiver
// Provides time stamps, event strobes and some status markers.
module tinyEVR #(
    parameter EVSTROBE_COUNT   = 126,
    parameter DEBUG            = "false",
    parameter TIMESTAMP_WIDTH  = 64
    ) (
    input  wire                                            evrRxClk,

    (*mark_debug=DEBUG*) input                      [15:0] evrRxWord,
    (*mark_debug=DEBUG*) input                       [1:0] evrCharIsK,

    (*mark_debug=DEBUG*) output wire                       ppsMarker,
    (*mark_debug=DEBUG*) output wire                       timestampValid,
    (*mark_debug=DEBUG*) output wire [TIMESTAMP_WIDTH-1:0] timestamp,
    (*mark_debug=DEBUG*) output wire                 [7:0] distributedDataBus,
    output wire [EVSTROBE_COUNT:1]                         evStrobe);

tinyEVRcommon #(.ACTION_RAM_WIDTH(0),
                .EVSTROBE_COUNT(EVSTROBE_COUNT),
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
    .action(evStrobe),
    .sysClk(1'b0),
    .sysActionWriteEnable(1'b0),
    .sysActionAddress(8'h00),
    .sysActionData(1'b0));
endmodule
