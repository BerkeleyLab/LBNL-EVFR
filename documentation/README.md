# Event Fanout, Receiver, and Kicker Driver — Firmware Documentation

This folder documents the **gateware and µBlaze software** for the ALS-U event fanout, event receiver, and kicker driver modules, all built on the Marble FPGA carrier.

| Document | What's inside |
|---|---|
| 💾 [Firmware](Firmware.md) | Images and hardware detection, front panel and display, per-module features, kicker gate driver timing, network services, console commands, building and deploying |

## Getting started

### Dependencies

| Needed for | Tool |
|---|---|
| Gateware | GNU Make |
| Gateware | [Xilinx Vivado](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html) 2020.2.2 (tested) |
| Gateware and software | [Xilinx Vitis](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vitis.html) 2020.2.2 (tested) |
| Software | `mb-gcc` µBlaze toolchain, bundled with Vitis |

Make sure `vivado` and `vitis` are on your `PATH`, and fetch the submodules after cloning:

```sh
git submodule update --init
```

### Building

```sh
MB_TOOLCHAIN_LOCATION=/media/Xilinx/Vivado/2020.2.2/Vitis/2020.2/gnu/microblaze/lin
(time make CROSS_COMPILE=${MB_TOOLCHAIN_LOCATION}/bin/mb- APP=evfr PLATFORM=marble \
  && notify-send 'Compilation SUCCESS' || notify-send 'Compilation ERROR'; date) 2>&1 | tee make_output
```

| `APP` / `PLATFORM` | `marble` |
|:---:|:---:|
| `evfr` (event fanout/receiver) | ✓ |
| `kd` (kicker driver) | ✓ |

Add `GW_VARIANT=USE_QSFP_FANOUT` to also fan the event stream out through QSFP2. This is a test feature: the fanout latency isn't fully deterministic and can vary by about one clock period.

The bootable image is written to `software/app/<APP>/<APP>_marble.<git-hash>.bit`.

### Deploying

For development, load the image over JTAG:

```sh
cd scripts
./deploy.sh ../software/app/<APP>/<APP>_marble.<git-hash>.bit
```

To make it permanent, write it to flash with `software/scripts/programFlash.sh`; see [Deploying](Firmware.md#deploying).

## Reference documents

| Document | Contents |
|---|---|
| [GateDrivers.svg](GateDrivers.svg) | Kicker gate driver firmware blocks (source: `GateDrivers.graffle`) |
| [CableSketch.svg](CableSketch.svg) | Kicker driver cabling sketch (source: `CableSketch.graffle`) |
| [ALSU-Kicker_r1.pdf](Schematics/ALSU-Kicker_r1.pdf) | Kicker driver schematics |
| [UTIO_RevA_schem.pdf](UTIO_RevA_schem.pdf) | UTIO FMC card schematics |

`make` in this folder regenerates the SVG figures from PDFs exported from OmniGraffle (requires `pdf2svg`).

## Related projects

| Project | Documentation |
|---|---|
| **[siocEventClient](https://git.als.lbl.gov/alsu/epics/iocs/siocEventClient)** — EPICS support module and IOCs for these modules: records, kicker timing control, event receiver outputs, `console.py` | [EPICS Support ↗](https://git.als.lbl.gov/alsu/epics/iocs/siocEventClient/-/blob/HEAD/documentation/EPICSnotes.md) |
| **[dual-evg](https://gitlab.lbl.gov/alsu-instrumentation/dual-evg)** — the dual event generator, which shares the Marble platform and drives the event links | [Hardware ↗](https://gitlab.lbl.gov/alsu-instrumentation/dual-evg/-/blob/HEAD/documentation/Hardware.md) |
