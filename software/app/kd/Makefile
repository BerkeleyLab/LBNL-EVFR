__THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_DIR := $(__THIS_DIR:/=)

PLATFORM     ?= marble
APP          ?= kd

TARGET       = $(APP)_$(PLATFORM)
GW_TGT_DIR   = $(GW_SYN_DIR)/$(TARGET)
ELF          = $(THIS_DIR)/$(TARGET).elf

BIT          ?= $(GW_TGT_DIR)/$(TARGET)_top.bit
DEPLOY_BIT   ?= $(THIS_DIR)/downloadKD.bit
MMI          ?= $(GW_TGT_DIR)/$(TARGET)_top.mmi

clean::
	rm -f *.log *.jou

include ../common/Makefile
