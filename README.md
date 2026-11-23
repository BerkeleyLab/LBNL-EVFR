# Event Fanout Receiver

Gateware and software for the ALS-U event fanout, event receiver, and kicker driver modules on the Marble FPGA carrier.

## Quick start

```sh
git submodule update --init
make APP=evfr PLATFORM=marble     # or APP=kd for the kicker driver
```

Requires Vivado and Vitis 2020.2.2 on `PATH`. The bootable image is written to `software/app/<APP>/<APP>_marble.<git-hash>.bit`.

## Documentation

📖 **[documentation/README.md](documentation/README.md)** — dependencies, build options, deployment, hardware detection, kicker driver timing, and console commands.
