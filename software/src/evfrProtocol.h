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

#ifndef _EVENT_FANOUT_PROTOCOL_
#define _EVENT_FANOUT_PROTOCOL_

#include <stdint.h>

#define EVF_PROTOCOL_UDP_EPICS_PORT     58765
#define EVF_PROTOCOL_MAGIC              0xBD008428
#define EVF_PROTOCOL_MAGIC_SWAPPED      0x288400BD
#define EVF_PROTOCOL_ARG_CAPACITY       350
#define EVF_PROTOCOL_EVF_COUNT          2

struct evfPacket {
    uint32_t    magic;
    uint32_t    nonce;
    uint32_t    command;
    uint32_t    args[EVF_PROTOCOL_ARG_CAPACITY];
};

struct evfStatusPacket {
    uint32_t    magic;
    uint32_t    pkNumber;
    uint32_t    posixSeconds;
    uint32_t    ntpFraction;
    uint32_t    sequencerStatus[EVF_PROTOCOL_EVF_COUNT];
};

#define EVF_PROTOCOL_SIZE_TO_ARG_COUNT(s) (EVF_PROTOCOL_ARG_CAPACITY - \
                    ((sizeof(struct evfPacket)-(s))/sizeof(uint32_t)))
#define EVF_PROTOCOL_ARG_COUNT_TO_SIZE(a) (sizeof(struct evfPacket) - \
                        ((EVF_PROTOCOL_ARG_CAPACITY - (a)) * sizeof(uint32_t)))
#define EVF_PROTOCOL_ARG_COUNT_TO_U32_COUNT(a) \
                    ((sizeof(struct evfPacket) / sizeof(uint32_t)) - \
                                            (EVF_PROTOCOL_ARG_CAPACITY - (a)))
#define EVF_PROTOCOL_U32_COUNT_TO_ARG_COUNT(u) (EVF_PROTOCOL_ARG_CAPACITY - \
                    (((sizeof(struct evfPacket)/sizeof(uint32_t)))-(u)))

#define EVF_PROTOCOL_CMD_MASK_HI             0xF000
#define EVF_PROTOCOL_CMD_MASK_LO             0x0F00
#define EVF_PROTOCOL_CMD_MASK_IDX            0x00FF

#define EVF_PROTOCOL_CMD_HI_LONGIN           0x0000
#define EVF_PROTOCOL_CMD_LONGIN_LO_GENERIC      0x000
# define EVF_PROTOCOL_CMD_LONGIN_IDX_FIRMWARE_BUILD_DATE 0x00
# define EVF_PROTOCOL_CMD_LONGIN_IDX_SOFTWARE_BUILD_DATE 0x01
#define EVF_PROTOCOL_CMD_LONGIN_LO_EVENT_LOG    0x100

#define EVF_PROTOCOL_CMD_HI_LONGOUT          0x1000
# define EVF_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE   0x000
#  define EVF_PROTOCOL_CMD_LONGOUT_NV_IDX_CLEAR_POWERUP_STATUS  0x00
# define EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_ACTION 0x100
# define EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_MODE   0x200
# define EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_DELAY  0x300
# define EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_WIDTH  0x400
# define EVF_PROTOCOL_CMD_LONGOUT_LO_GENERIC    0xF00
#  define EVF_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_REBOOT           0x00
#  define EVF_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_SET_LOOPBACK     0x01

#define EVF_PROTOCOL_CMD_HI_SYSMON           0x2000
# define EVF_PROTOCOL_CMD_SYSMON_LO_INT32       0x000
# define EVF_PROTOCOL_CMD_SYSMON_LO_UINT16_LO   0x100
# define EVF_PROTOCOL_CMD_SYSMON_LO_UINT16_HI   0x200
# define EVF_PROTOCOL_CMD_SYSMON_LO_INT16_LO    0x300
# define EVF_PROTOCOL_CMD_SYSMON_LO_INT16_HI    0x400

#define EVF_PROTOCOL_CMD_HI_PATTERN          0x3000
# define EVF_PROTOCOL_CMD_PATTERN_LO_WRITE      0x000

/*
 * Additions for kicker driver FPGA
 * The 'set group delay' is the only command actually sent to the FPGA.  The
 * others are addresses of records used internally by the IOC to hold values
 * until pushed by the 'set group delay' command.
 * Although several 'IDX' values are the same there is no conflict since
 * the records in question have different DTYP field values.
 */
#define EVF_PROTOCOL_CMD_HI_KICKER_DRIVER    0x5000
# define EVF_PROTOCOL_CMD_LO_KICKER_DRIVER      0x000
#  define EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_GROUP_DELAY    0x00
#  define EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_GROUP_WIDEN    0x01
#  define EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_DRIVER_ENABLES 0x00
#  define EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_DRIVER_DELAYS  0x00
#  define EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_DRIVER_WIDTHS  0x01
#endif /* _EVENT_FANOUT_PROTOCOL_ */
