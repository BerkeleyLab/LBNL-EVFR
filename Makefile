include dir_list.mk

CROSS_COMPILE    ?=
PLATFORM         ?= marble
APP              ?= evfr
TESTING_OPTION 	 ?=

TARGET       = $(APP)_$(PLATFORM)
GW_TGT_DIR   = $(GW_SYN_DIR)/$(TARGET)
BIT          = $(GW_TGT_DIR)/$(TARGET)_top.bit
SW_TGT_DIR   = $(SW_APP_DIR)/$(APP)

.PHONY: all bit sw

all: bit sw

bit:
	make -C $(GW_TGT_DIR) TARGET=$(TARGET) $(TARGET)_top.bit TESTING_ARGS_VIVADO=$(TESTING_OPTION)
	make -C $(GW_TGT_DIR) TARGET=$(TARGET) $(TARGET)_top.mmi TESTING_ARGS_VIVADO=$(TESTING_OPTION)

sw:
	make -C $(SW_TGT_DIR) TARGET=$(TARGET) BIT=$(BIT) all

clean:
	make -C $(GW_TGT_DIR) TARGET=$(TARGET) clean
	make -C $(SW_TGT_DIR) TARGET=$(TARGET) clean
	rm -f *.log *.jou
