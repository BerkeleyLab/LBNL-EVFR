TOP := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

GATEWARE_DIR       = $(TOP)gateware
SOFTWARE_DIR       = $(TOP)software

# Gateware

SUBMODULES_DIR     = $(GATEWARE_DIR)/submodules
MODULES_DIR        = $(GATEWARE_DIR)/modules
PLATFORM_DIR       = $(GATEWARE_DIR)/platform
GW_SCRIPTS_DIR     = $(GATEWARE_DIR)/scripts

BEDROCK_DIR        = $(SUBMODULES_DIR)/bedrock
BANTAMWEIGHT_DIR   = $(SUBMODULES_DIR)/bantamweightUDP
PLATFORM_7SERIES_DIR  = $(PLATFORM_DIR)/xilinx/7series
PLATFORM_7SERIES_COMMON_DIR  = $(PLATFORM_7SERIES_DIR)/common

GW_SYN_DIR         = $(GATEWARE_DIR)/syn

# Sofware

SW_LIBS_DIR        = $(SOFTWARE_DIR)/libs
SW_TGT_DIR         = $(SOFTWARE_DIR)/target
SW_SCRIPTS_DIR     = $(SOFTWARE_DIR)/scripts
SW_SRC_DIR     	   = $(SOFTWARE_DIR)/src
SW_APP_DIR         = $(SOFTWARE_DIR)/app
SW_SUBMODULES_DIR  = $(SOFTWARE_DIR)/submodules

SW_SPIFLASHDRIVER_DIR = $(SW_SUBMODULES_DIR)/spiflash_driver/src

include $(BEDROCK_DIR)/dir_list.mk
