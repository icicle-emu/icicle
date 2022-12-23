**DISCLAIMER: This repository is provided to support the paper: "Icicle: A Re-Designed Emulator for Grey-Box Firmware Fuzzing" and must not be used for purposes other than review. Post-publication this repository will be re-released under an open-source licence.**

---

# Icicle

## Quickstart

First, ensure that the required dependencies are installed including:

* [rustup](https://rustup.rs/)
* Docker
* gcc
* libssl-dev

Next, clone the repository:

```
git clone https://github.com/icicle-emu/icicle.git
```

Then perform a full build (this step includes initializing and updating all submodules):

```bash
./build_all.sh
```

For further details in using Icicle to fuzz new targets, or extending Icicle, see the `icicle-emu` submodule: [./icicle-emu](https://github.com/icicle-emu/icicle-emu).


## Reproducing benchmarks

After performing the initial build, all benchmarks reported in the paper can be reproduced in one of two ways:

* For most benchmarks `cd bench-harness` and follow: [bench-harness/README.md](https://github.com/icicle-emu/bench-harness/blob/main/README.md)

* For Fuzzware benchmarks install Fuzzware-icicle from: [Fuzzware-icicle](https://github.com/icicle-emu/fuzzware) then follow the benchmarking procedure in: [fuzzware-experiments](https://github.com/icicle-emu/fuzzware-experiments/tree/main/02-comparison-with-state-of-the-art)


## Crash analysis

* [MSP430 crash analysis](./crash-analysis/msp430/README.md)
* [ARM crash analysis](./crash-analysis/fuzzware/README.md)
