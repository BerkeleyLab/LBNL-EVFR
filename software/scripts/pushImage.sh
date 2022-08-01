FILES="downloadEVFR.bit downloadKD.bit programFlash.sh"
scp $FILES enorum@access.als.lbl.gov:
ssh enorum@access.als.lbl.gov "scp $FILES bpm01:/usr/local/epics/R3.15.4/modules/instrument/eventFanout/head/FPGA/ ; rm $FILES"

