include ../../dir_list.mk
.PHONY: all
all: targets
include $(BUILD_DIR)/top_rules.mk
include rules.mk
include $(BUILD_DIR)/bottom_rules.mk

APP ?= evfr
PLATFORM ?= marble
gpioIDX.vh: $(SW_TGT_DIR)/$(APP)_$(PLATFORM)/gpio.h $(SW_TGT_DIR)/$(APP)_$(PLATFORM)/config.h
	sh $(GW_SCRIPTS_DIR)/createVerilogIDX.sh $^ > $@