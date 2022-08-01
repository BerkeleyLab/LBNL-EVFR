/*
 * Copyright 2021, Lawrence Berkeley National Laboratory
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS
 * AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Send commands/data to Solomon-Systech display controller
 */
module solomonSystechSPI #(
    parameter CLK_RATE = 100000000
    ) (
    input        clk,
    input [15:0] TDATA,
    input        TVALID,
    input        TLAST,
    output   reg TREADY = 1,

    output reg SPI_CLK  = 1,
    output reg SPI_CSN  = 1,
    output reg SPI_D_CN = 0,
    output     SPI_DOUT,
    output reg VP_ENABLE = 0,
    output reg RESETN = 0);

function integer ns2ticks;
    input integer ns;
    begin
        ns2ticks = (((ns) * (CLK_RATE/100)) + 9999999) / 10000000;
    end
endfunction

localparam Tsetup = ns2ticks(90); // Max(Tas, Tcss)
localparam Thold = ns2ticks(90);  // Max(Tah, Tcsh)
localparam Tidle = ns2ticks(200); // Not specified -- assume Tcycle
localparam Tclkl = ns2ticks(100);
localparam Tclkh = ns2ticks(100);
localparam DELAY_MAXRELOAD = Tidle - 2;
localparam DELAYCOUNTER_WIDTH = $clog2(DELAY_MAXRELOAD+1)+1;
reg [DELAYCOUNTER_WIDTH-1:0] delayCounter = ~0;
wire delayCounterDone = delayCounter[DELAYCOUNTER_WIDTH-1];

localparam BIT_COUNT = 8;
localparam BITCOUNTER_RELOAD = BIT_COUNT - 2;
localparam BITCOUNTER_WIDTH = $clog2(BITCOUNTER_RELOAD+1)+1;
reg [BITCOUNTER_WIDTH-1:0] bitCounter = ~0;
wire bitCounterDone = bitCounter[BITCOUNTER_WIDTH-1];

reg [BIT_COUNT-1:0] shiftReg = 0;
assign SPI_DOUT = shiftReg[BIT_COUNT-1];
reg isLast = 0;

localparam ST_IDLE     = 3'd0,
           ST_START    = 3'd1,
           ST_HIGH     = 3'd2,
           ST_LOW      = 3'd3,
           ST_CSA_HOLD = 3'd4,
           ST_FINISH   = 3'd6;
reg [2:0] state = ST_IDLE;

always @(posedge clk) begin
    if (TVALID & TDATA[15]) begin
        RESETN <= !TDATA[0];
        VP_ENABLE <= TDATA[1];
    end
    else begin
        case (state)
        ST_IDLE: begin
            bitCounter <= BITCOUNTER_RELOAD;
            if (TVALID && RESETN) begin
                TREADY <= 0;
                SPI_CLK <= 0;
                SPI_CSN <= 0;
                shiftReg <= TDATA[BIT_COUNT-1:0];
                SPI_D_CN <= TDATA[BIT_COUNT];
                isLast <= TLAST;
                delayCounter <= Tsetup - 2;
                state <= ST_START;
            end
        end
        ST_START: begin
            if (delayCounterDone) begin
                SPI_CLK <= 1;
                delayCounter <= Tclkh - 2;
                state <= ST_HIGH;
            end
            else begin
                delayCounter <= delayCounter - 1;
            end
        end
        ST_HIGH: begin
            if (delayCounterDone) begin
                bitCounter <= bitCounter - 1;
                SPI_CLK <= 0;
                shiftReg <= (shiftReg << 1);
                delayCounter <= Tclkl - 2;
                state <= ST_LOW;
            end
            else begin
                delayCounter <= delayCounter - 1;
            end
        end
        ST_LOW: begin
            if (delayCounterDone) begin
                SPI_CLK <= 1;
                if (bitCounterDone) begin
                    if (isLast) begin
                        delayCounter <= Thold - 2;
                        state <= ST_CSA_HOLD;
                    end
                    else begin
                        delayCounter <= Tclkh - 2;
                        state <= ST_FINISH;
                    end
                end
                else begin
                    delayCounter <= Tclkh - 2;
                    state <= ST_HIGH;
                end
            end
            else begin
                delayCounter <= delayCounter - 1;
            end
        end
        ST_CSA_HOLD: begin
            if (delayCounterDone) begin
                SPI_CSN <= 1;
                delayCounter <= Tidle - 2;
                state <= ST_FINISH;
            end
            else begin
                delayCounter <= delayCounter - 1;
            end
        end
        ST_FINISH: begin
            if (delayCounterDone) begin
                TREADY <= 1;
                state <= ST_IDLE;
            end
            else begin
                delayCounter <= delayCounter - 1;
            end
        end
        default: ;
        endcase
    end
end
endmodule
