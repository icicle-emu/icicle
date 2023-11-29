# Icicle

<a href="https://dl.acm.org/doi/10.1145/3597926.3598039"><img alt="Paper preview" align="right" width="266" src="https://raw.githubusercontent.com/icicle-emu/icicle/e09d40c796392f23ba0a6cb218e9a72a807e2419/paper-preview.png"></a>

Code and benchmarks for <a href="https://dl.acm.org/doi/10.1145/3597926.3598039">"Icicle: A Re-designed Emulator for Grey-Box Firmware Fuzzing"</a>. 

This repository contains submodules corresponding to the exact versions of the various components used for the paper. However, it is highly recommended you use the latest version of the emulator available at: [icicle-emu](https://github.com/icicle-emu/icicle-emu)

**Cite as:**

```
@inproceedings{icicle2023,
  title     = {Icicle: A Re-Designed Emulator for Grey-Box Firmware Fuzzing},
  author    = {Chesser, Michael and Nepal, Surya and Ranasinghe, Damith C},
  booktitle = {{ACM} {SIGSOFT} International Symposium on Software Testing and Analysis},
  series    = {ISSTA},
  year      = {2023}
}
```



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
