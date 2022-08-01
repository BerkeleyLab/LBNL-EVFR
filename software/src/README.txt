To build EVF/EVR firmware:
    Run createVerilogIDX.sh.
    Start Vivado and open EventFanoutReceiverMarble project.
    Generate Bitstream. This will produce Workspace/EVFR/scripts/EVFR.bit.

To build Kicker Driver firmware:
    Run createVerilogIDX_KD.sh.
    Start Vivado and open EventFanoutReceiverMarble project.
    Generate Bitstream. This will produce Workspace/EVFR/scripts/KD.bit.

If the microBlaze address map has changed, export the hardware and update
the hardware specification in Vitis.
