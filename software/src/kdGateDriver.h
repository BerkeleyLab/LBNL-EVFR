/*
 * Copyright 2020, Lawrence Berkeley National Laboratory
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
 * Kicker gate driver control
 */

#ifndef _KD_GATE_DRIVER_H_
#define _KD_GATE_DRIVER_H_

/*
 * Kicker clock definitions
 */
#define KD_CLOCK_CSR_GROUP_IDELAY_STEP_SIZE     1
#define KD_CLOCK_CSR_GROUP_IDELAY_STEP_SHIFT    16
#define KD_CLOCK_CSR_GROUP_IDELAY_STEP          REG_GEN_MASK(KD_CLOCK_CSR_GROUP_IDELAY_STEP_SHIFT, KD_CLOCK_CSR_GROUP_IDELAY_STEP_SIZE)

#define KD_CLOCK_CSR_GROUP_IDELAY_INC_SIZE      1
#define KD_CLOCK_CSR_GROUP_IDELAY_INC_SHIFT     17
#define KD_CLOCK_CSR_GROUP_IDELAY_INC           REG_GEN_MASK(KD_CLOCK_CSR_GROUP_IDELAY_INC_SHIFT, KD_CLOCK_CSR_GROUP_IDELAY_INC_SIZE)

#define KD_CLOCK_CSR_GROUP_IDELAY_RST_SIZE      1
#define KD_CLOCK_CSR_GROUP_IDELAY_RST_SHIFT     23
#define KD_CLOCK_CSR_GROUP_IDELAY_RST           REG_GEN_MASK(KD_CLOCK_CSR_GROUP_IDELAY_RST_SHIFT, KD_CLOCK_CSR_GROUP_IDELAY_RST_SIZE)

#define KD_CLOCK_CSR_GROUP_VALUE_SIZE           8
#define KD_CLOCK_CSR_GROUP_VALUE_SHIFT          24
#define KD_CLOCK_CSR_GROUP_VALUE                REG_GEN_MASK(KD_CLOCK_CSR_GROUP_VALUE_SHIFT, KD_CLOCK_CSR_GROUP_VALUE_SIZE)

/*
 * Kicker gate definitions
 */
#define KD_GATE_CSR_GROUP_DELAY_SIZE            12
#define KD_GATE_CSR_GROUP_DELAY_SHIFT           0
#define KD_GATE_CSR_GROUP_DELAY_MASK            REG_GEN_MASK(KD_GATE_CSR_GROUP_DELAY_SHIFT, KD_GATE_CSR_GROUP_DELAY_SIZE)
#define KD_GATE_CSR_GROUP_DELAY_W(value)        REG_GEN_WRITE(value, KD_GATE_CSR_GROUP_DELAY_SHIFT, KD_GATE_CSR_GROUP_DELAY_SIZE)

#define KD_GATE_CSR_GROUP_SET_DELAY_SIZE        1
#define KD_GATE_CSR_GROUP_SET_DELAY_SHIFT       15
#define KD_GATE_CSR_GROUP_SET_DELAY             REG_GEN_MASK(KD_GATE_CSR_GROUP_SET_DELAY_SHIFT, KD_GATE_CSR_GROUP_SET_DELAY_SIZE)

#define KD_GATE_CSR_GROUP_VALUE_SIZE            8
#define KD_GATE_CSR_GROUP_VALUE_SHIFT           24
#define KD_GATE_CSR_GROUP_VALUE                 REG_GEN_MASK(KD_GATE_CSR_GROUP_VALUE_SHIFT, KD_GATE_CSR_GROUP_VALUE_SIZE)

/*
 * Kicker driver definitions
 */
#define KD_CSR_CONFIG_SIZE     24
#define KD_CSR_CONFIG_SHIFT    0
#define KD_CSR_CONFIG_MASK     REG_GEN_MASK(KD_CSR_CONFIG_SHIFT, KD_CSR_CONFIG_SIZE)
#define KD_CSR_CONFIG_W(value) REG_GEN_WRITE(value, KD_CSR_CONFIG_SHIFT, KD_CSR_CONFIG_SIZE)

#define KD_CSR_ADDRESS_SIZE     8
#define KD_CSR_ADDRESS_SHIFT    24
#define KD_CSR_ADDRESS_MASK     REG_GEN_MASK(KD_CSR_ADDRESS_SHIFT, KD_CSR_ADDRESS_SIZE)
#define KD_CSR_ADDRESS_W(value) REG_GEN_WRITE(value, KD_CSR_ADDRESS_SHIFT, KD_CSR_ADDRESS_SIZE)


void kdGateDriverUpdate(unsigned int idx, uint32_t *driverControl);
int kdGateDriverGetMonitorStatus(uint32_t *driverStatus);
void kdGateDriverInitMonitorStatus(void);

#endif /* _KD_GATE_DRIVER_H_ */
