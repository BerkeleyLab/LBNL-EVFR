Event Fanout Receiver
=====================

Gateware/Software for Event Fanout/Receiver

### Building

This repository contains both gateware and software
for the Event Fanout/Receiver

#### Gateware Dependencies

To build the gateware the following dependencies are needed:

* GNU Make
* Xilinx Vivado (2020.2.2 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html)
* Xilinx Vitis (2020.2.2 tested), available [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vitis.html)

Make sure `vivado` and `vitis` are in PATH.

#### Software Dependencies

To build the software the following dependencies are needed:

* mb-gcc toolchain, bundled within Vitis

#### Building Instructions

With the dependencies in place a simple `make` should be able to generate
both gateware and software:

```bash
make
```

A suggestion in running the `make` command is to measure the time
and redirect stdout/stderr to a file so you can inspect it later:

```bash
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2020.2.2/Vitis/2020.2/gnu/microblaze/lin
(time make CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/mb- APP=evfr PLATFORM=marble && notify-send 'Compilation SUCCESS' || notify-send 'Compilation ERROR'; date) 2>&1 | tee make_output
```

For now the following combinations of PLATFORM and APP are supported:

| APP / PLATFORM | marble |
|:--------------:|:------:|
|       evfr     |    x   |
|       kd       |    x   |

So, for example, to generate the EVFR application for the Marble board:

```bash
ARM_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2020.2.2/Vitis/2020.2/gnu/microblaze/lin
(time make CROSS_COMPILE=${ARM_TOOLCHAIN_LOCATION}/bin/mb- APP=evfr PLATFORM=marble && notify-send 'Compilation SUCCESS' || notify-send 'Compilation ERROR'; date) 2>&1 | tee make_output
```

### Deploying

To deploy the gateware and the software we can use a variety of
methods. For development, JTAG is being used.

####

The following script can download the gateware/software via JTAG:

```bash
cd scripts
./deploy.sh software/app/<APP>/download<APP_UPPERCASE>.bit
```

Usually, APP=evfr or APP=kd depending on the desired target.
