THIS_DIR := $(__THIS_DIR:/=)

CROSS_COMPILE ?= mb-
CC = $(CROSS_COMPILE)gcc
SIZE = $(CROSS_COMPILE)size
XSCT ?= xsct -norlwrap

include ../../../dir_list.mk

GIT_COMMIT   = $(shell git rev-parse --short=8 --verify HEAD || echo "NOCOMMIT")

APP         ?= evfr
PLATFORM    ?= marble
TARGET      = $(APP)_$(PLATFORM)
GW_TGT_DIR  = $(GW_SYN_DIR)/$(TARGET)
BIT         ?= $(GW_TGT_DIR)/$(TARGET)_top.bit
DEPLOY_BIT  ?= $(THIS_DIR)/$(TARGET).$(GIT_COMMIT).bit
MMI         ?= $(GW_TGT_DIR)/$(TARGET)_top.mmi
ELF 	    ?= $(THIS_DIR)/$(TARGET).elf

SW_APP_TGT_DIR = $(SW_APP_DIR)/$(APP)
SW_COMMON_SCRIPTS_DIR = $(SW_APP_DIR)/common/scripts

CPU_NAME   = microblaze_0
TARGET_DIR = $(SW_TGT_DIR)/$(TARGET)
BSP_DIR   = $(SW_APP_TGT_DIR)/$(TARGET)/bd/$(CPU_NAME)/standalone_domain/bsp/$(CPU_NAME)

all: $(TARGET) $(TARGET).elf $(TARGET).elf.size $(DEPLOY_BIT)

__SRC_FILES = \
	bootFlash.c \
	console.c \
	display.c \
	drawEventLog.c \
	epics.c \
	eventMonitor.c \
	evio.c \
	evrio.c \
	eyescan.c \
	frontPanelSwitches.c \
	iicChunk.c \
	iicEVIO.c \
	iicFMC2.c \
	iicProc.c \
	kdGateDriver.c \
	main.c \
	mgt.c \
	mgtClkSwitch.c \
	mmcMailbox.c \
	platform.c \
	systemParameters.c \
	tftp.c \
	user_mgt_refclk.c \
	util.c \
	xadc.c
SRC_FILES = $(addprefix $(SW_SRC_DIR)/, $(__SRC_FILES))

__HDR_FILES = \
	ad9520Tables.h \
	bootFlash.h \
	console.h \
	display.h \
	drawEventLog.h \
	epics.h \
	eventMonitor.h \
	evfrProtocol.h \
	evio.h \
	evrio.h \
	eyescan.h \
	frontPanelSwitches.h \
	iicChunk.h \
	iicEVIO.h \
	iicFMC2.h \
	iicProc.h \
	kdGateDriver.h \
	mgtClkSwitch.h \
	mgt.h \
	mmcMailbox.h \
	platform_config.h \
	platform.h \
	systemParameters.h \
	tftp.h \
	user_mgt_refclk.h \
	util.h \
	xadc.h
HDR_FILES = $(addprefix $(SW_SRC_DIR)/, $(__HDR_FILES))

__SRC_BANTAMWEIGHTUDP_FILES = \
	badger.c \
	bwudp.c
SRC_BANTAMWEIGHTUDP_FILES = $(addprefix $(BANTAMWEIGHT_DIR)/, $(__SRC_BANTAMWEIGHTUDP_FILES))

SRC_FILES += $(SRC_BANTAMWEIGHTUDP_FILES)

__HDR_BANTAMWEIGHTUDP_FILES = \
	bwudp_config.h \
	bwudp.h
HDR_BANTAMWEIGHTUDP_FILES = $(addprefix $(BANTAMWEIGHT_DIR)/, $(__HDR_BANTAMWEIGHTUDP_FILES))

HDR_FILES += $(HDR_BANTAMWEIGHTUDP_FILES)

__SRC_SPIFLASHDRIVER_FILES = \
	spiflash.c
SRC_SPIFLASHDRIVER_FILES = $(addprefix $(SW_SPIFLASHDRIVER_DIR)/, $(__SRC_SPIFLASHDRIVER_FILES))

SRC_FILES += $(SRC_SPIFLASHDRIVER_FILES)

__HDR_SPIFLASHDRIVER_FILES = \
	spiflash.h
HDR_SPIFLASHDRIVER_FILES = $(addprefix $(SW_SPIFLASHDRIVER_DIR)/, $(__HDR_SPIFLASHDRIVER_FILES))

HDR_FILES += $(HDR_SPIFLASHDRIVER_FILES)

__HDR_GEN_FILES = \
	softwareBuildDate.h
HDR_GEN_FILES = $(addprefix $(SW_SRC_DIR)/, $(__HDR_GEN_FILES))

__STP_FILES = \
	ad9520.stp
STP_FILES = $(addprefix $(SW_COMMON_SCRIPTS_DIR)/, $(__STP_FILES))

ST7789V_DIR = $(SW_LIBS_DIR)/st7789v
__ST7789V_SRC_FILES = \
	systemFont.c \
	st7789v.c
__ST7789V_HDR_FILES = \
	lv_font.h \
	st7789v.h

ST7789V_SRC_FILES = $(addprefix $(ST7789V_DIR)/, $(__ST7789V_SRC_FILES))
ST7789V_HDR_FILES = $(addprefix $(ST7789V_DIR)/, $(__ST7789V_HDR_FILES))
SRC_FILES += $(ST7789V_SRC_FILES)
HDR_FILES += $(ST7789V_HDR_FILES)

include $(TARGET_DIR)/$(TARGET).mk

OBJ_FILES = $(SRC_FILES:.c=.o)
LINKER_FILES = $(SW_SRC_DIR)/lscript.ld

CFLAGS = -Wall -O2 -mlittle-endian -mxl-barrel-shift -mno-xl-soft-div -mcpu=v11.0 -mno-xl-soft-mul -ffunction-sections -fdata-sections
LD_FLAGS = -Wl,-T -Wl,$(LINKER_FILES) -Wl,--no-relax
USER_FLAGS = -D__BAREMETAL__ -DBWUDP_ENDPOINT_CAPACITY=5 -DBWUDP_ENABLE_CLIENT_SUPPORT -DBWUDP_USE_REAL_GPIO_H
LIB_DIRS = $(BSP_DIR)/lib
LIB_FLAGS = $(addprefix -L, $(LIB_DIRS))
LIBS = -Wl,--start-group,-lxil,-lgcc,-lc,--end-group

INCLUDE_DIRS = \
	$(SW_SRC_DIR) \
	$(TARGET_DIR) \
	$(SW_SPIFLASHDRIVER_DIR) \
	$(BANTAMWEIGHT_DIR) \
	$(BSP_DIR)/include \
	$(ST7789V_DIR)
INCLUDE_FLAGS = $(addprefix -I, $(INCLUDE_DIRS))

.PHONY: all clean bsp

vpath *.c $(SW_SRC_DIR) $(TARGET_DIR) $(ST7789V_DIR)
vpath *.h $(SW_SRC_DIR) $(TARGET_DIR) $(ST7789V_DIR)
vpath *.o $(SW_SRC_DIR) $(ST7789V_DIR)
vpath *.mmi $(GW_TGT_DIR)

%softwareBuildDate.h: $(SRC_FILES) $(HDR_FILES)
	sh $(SW_COMMON_SCRIPTS_DIR)/setSoftwareBuildDate.sh > $@

%ad9520Tables.h: $(STP_FILES)
	bash $(SW_COMMON_SCRIPTS_DIR)/createPLLtables.sh $^ > $@

# FIXME: We are considering BSP done if the directory exists. This
# could lead to mismatches!
$(TARGET):
	$(XSCT) $(SW_SCRIPTS_DIR)/gen_vitis_platform.tcl $@ $(GW_TGT_DIR)/bd.xsa $(CPU_NAME)

$(TARGET).elf: $(HDR_FILES) $(HDR_GEN_FILES) $(OBJ_FILES) $(LINKER_FILES)
	$(CC) $(CFLAGS) $(USER_FLAGS) $(INCLUDE_FLAGS) $(LIB_FLAGS) $(LD_FLAGS) -o $@ $(filter %.o, $^) $(LIBS)

$(TARGET).elf.size: $(TARGET).elf
	$(SIZE) $< | tee $@

$(DEPLOY_BIT): $(MMI) $(BIT) $(ELF)
	rm -f updatemem.jou updatemem.log
	updatemem -force -meminfo $< -bit $(BIT) \
		-data $(ELF) -proc bd_i/$(CPU_NAME) \
		-out $@

# Pull in dependency info for *existing* .o files and don't complain if the
# corresponding .d file is not found
-include $(OBJ_FILES:.o=.d)

%.o: %.c
	$(CC) -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" $(CFLAGS) $(USER_FLAGS) $(INCLUDE_FLAGS) -c $*.c -o $@

clean::
	$(RM) -rf $(TARGET).elf $(TARGET).elf.size $(DEPLOY_BIT) $(HDR_GEN_FILES) \
		$(OBJ_FILES) $(OBJ_FILES:.o=.d) $(TARGET)
