# MMI and BIT obtained from Vivado project, thus no need
# to include the bitfile in the Vivado export.
EVFR_MMI = EVFR.mmi
EVFR_BIT = EVFR.bit
KD_MMI   = KD.mmi
KD_BIT   = KD.bit
ELF      = ../Release/EVFR.elf

.PHONY: srcCheck elfCheck

all: srcCheck elfCheck downloadEVFR.bit downloadKD.bit

downloadEVFR.bit: $(EVFR_MMI) $(EVFR_BIT) $(ELF)
	rm -f updatemem.jou updatemem.log
	updatemem -force -meminfo $(EVFR_MMI) -bit $(EVFR_BIT) \
		-data $(ELF) -proc bd_i/microblaze_0 \
		-out downloadEVFR.bit

downloadKD.bit: $(KD_MMI) $(KD_BIT) $(ELF)
	rm -f updatemem.jou updatemem.log
	updatemem -force -meminfo $(KD_MMI) -bit $(KD_BIT) \
		-data $(ELF) -proc bd_i/microblaze_0 \
		-out downloadKD.bit

srcCheck:
	cd ../src ; make

elfCheck:
	cd ../Release ; make all

clean:
	rm -f chk.bit vitis_pid*.str *.jou *.log eeprom*.bin

realclean: clean
	rm -f downloadEVFR.bit downloadKD.bit
