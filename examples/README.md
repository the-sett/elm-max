# Examples for the-sett/elm-max

Complete programs that build typed tensor graphs in Elm with `the-sett/elm-max`, compile them with
[eco](https://github.com/eco-lang/eco-compiler) to a native shared library, and run them on
[Modular MAX](https://www.modular.com/max) through the package's host, `../host/max_host.cpp`.
They train MNIST classifiers and a small character language model. The package's own checks are
next to them: every operation and gradient against NumPy in `../opcheck`, and the larger parts of
the API, end to end on synthetic models, in `../apicheck`.

These instructions are for Linux x86_64, and were tested on Debian 12 with eco 0.2.0, GCC 12 and
MAX 26.7.0. eco and MAX also have macOS arm64 releases, which have not been tried with these
examples. The steps:

1. Install the build tools, uv and eco (once per machine).
2. Clone this repository.
3. `cd examples` and run `make`.

Python does not need to be installed: uv brings the Python that MAX runs in, and the Elm programs
run no Python themselves.

## 1. Install the prerequisites

### Build tools: a C++ compiler, make, curl and gzip

Each example is an Elm program compiled by eco to a shared library, linked by your C++ compiler
with the package's MAX host (`../host/max_host.cpp`) and MAX's `libmax` into a program. The host
needs a compiler with C++20 support (tested with GCC 12). On Debian or Ubuntu:

```sh
sudo apt update
sudo apt install build-essential curl gzip git
```

### uv

[uv](https://docs.astral.sh/uv/) installs MAX. Modular ships MAX, `libmax.so` and its C headers
included, only as a Python package, so the first `make` installs that package (`max==26.7.*`, about
700 MB) into a `.venv` at the repository's root, with a Python 3.11 that uv downloads itself if the
machine has none. Install uv with its installer:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

The installer puts `uv` in `~/.local/bin`; open a new shell, or run `source ~/.local/bin/env`, so
that it is on your `PATH`.

### eco 0.2.0

[eco](https://github.com/eco-lang/eco-compiler) compiles the Elm programs to native code. Install a
release, either from the archive, anywhere you like:

```sh
curl -LO https://github.com/eco-lang/eco-compiler/releases/download/v0.2.0/eco-0.2.0-x86_64-linux-musl.tar.gz
curl -LO https://github.com/eco-lang/eco-compiler/releases/download/v0.2.0/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
mkdir -p ~/opt/eco && tar -xzf eco-0.2.0-x86_64-linux-musl.tar.gz -C ~/opt/eco
echo 'export PATH="$HOME/opt/eco/bin:$PATH"' >> ~/.profile     # for future shells
export PATH="$HOME/opt/eco/bin:$PATH"                          # for this one
```

or, on Debian or Ubuntu, from the package, which puts `eco` in `/usr/local/bin`:

```sh
curl -LO https://github.com/eco-lang/eco-compiler/releases/download/v0.2.0/eco_0.2.0_amd64.deb
sudo apt install ./eco_0.2.0_amd64.deb
```

The Makefile finds eco's C++ headers (`eco/eco_embed.hpp`) in the `include/` next to the `bin/`
that holds `eco`; set `ECO_INCLUDE` if yours are elsewhere.

### Check

```sh
g++ --version && make --version && uv --version && eco --version
```

All four should print a version (`eco` prints `0.2.0`). Nothing else needs installing: MAX, the
MNIST data and the Elm packages are downloaded by the first `make`. Optionally, for
`make check-bytecode` only, install an `mlir-opt` that reads MLIR bytecode version 4 (it was tested
with the LLVM that MAX 26.7.0 pins, 24.0.0git; LLVM 21's should do, for example `mlir-21-tools`
from [apt.llvm.org](https://apt.llvm.org), named with `MLIR_OPT=mlir-opt-21`).

## 2. Get the examples

```sh
git clone https://github.com/the-sett/elm-max.git
cd elm-max/examples
```

## 3. Build and run

```sh
make run-mnist
```

The first time, this installs MAX into `elm-max/.venv` (`../scripts/setup-max.sh`), downloads the
MNIST data into `mnist/data` (checked against torchvision's MD5s), downloads the Elm packages the
program uses into `~/.eco`, compiles the program with eco (about a minute), links it, and trains
and evaluates the classifier. Later runs reuse all of that. Each example is one `make` target:

| Command | What it does |
|---|---|
| `make run-mnist` | trains and evaluates an MNIST classifier (the `sgd` model) |
| `make run-mnist MODEL=adamw` | the same network with AdamW; it saves its parameters in `work/checkpoints` |
| `make run-mnist MODEL=lora` | fine-tunes `adamw`'s saved network with a LoRA adapter (run `MODEL=adamw` first) |
| `make run-mnist MODEL=stack` | a deeper network with dropout |
| `make run-mnist MODEL=cnn` | a convolutional network |
| `make run-mnist-ref` | the `sgd` run in NumPy, for comparison |
| `make run-charlm` | trains a byte-level transformer language model on this package's README and sources |
| `make` | builds every example without running any |
| `make clean` | removes `build/` and `work/` |

`run-mnist` also takes `FORMAT=generic` (sends MAX the graphs as MLIR text instead of bytecode),
`RELOAD=true` (saves, reloads and re-evaluates the parameters) and `TRACE=n` (logs the first n step
losses). `run-charlm` takes `STEPS=1000`, `LAYERS=2`, `SHARED=true` (every layer as a call of one
MAX subgraph) and `CORPUS=file` (any other text). After a `run-mnist` and a
`run-mnist FORMAT=generic`, `make check-bytecode` checks that both forms of the graphs read back as
the same IR (needs `mlir-opt`).

The first run of each model spends 20 to 50 seconds while MAX compiles its graphs; MAX caches them,
so later runs start at once. Programs write their compiled graphs, checkpoints and logs under
`work/`, and builds go to `build/`. The Makefile sets the variables `libmax` needs to find its
kernels, and turns off MAX's telemetry. `MAX_VENV=dir` uses another venv that has MAX installed
instead of the repository's `.venv`.

### What to expect

Results on MAX 26.7.0's CPU, built with eco 0.2.0. The MNIST runs are deterministic, so their
numbers should match exactly:

| Run | Result |
|---|---|
| `run-mnist` (`sgd`) | 14.78% untrained, then 92.52, 94.31, 95.24, 95.60 and 95.87% over five epochs; mean train loss 0.4225 → 0.1334 |
| `run-mnist-ref` | the same model in NumPy: 95.84% after five epochs, mean train loss 0.1335 |
| `run-mnist MODEL=adamw` | 97.15% after five epochs; it saves its parameters in `work/checkpoints` |
| `run-mnist MODEL=lora` | `adamw`'s saved network, frozen, with a rank-8 LoRA adapter: 97.15% → 97.54% in one epoch. Run `MODEL=adamw` first |
| `run-mnist MODEL=stack` | 97.65% after five epochs |
| `run-mnist MODEL=cnn` | 98.57% after two epochs |
| `run-charlm` | a held-out loss of about 1.7 to 1.8 nats after 1,000 steps (1.76 when last run), against the corpus's unigram entropy of about 3.15. The default corpus is this package's README and sources, so the exact numbers change whenever they do |

## The examples

- `mnist/`: `MnistNet.elm` is a 784 → 128 → 10 network and its SGD training step; `MnistModels.elm`
  adds the other models; `Mnist.elm` loads the data and runs training and evaluation through
  `Max.Session`; `ref/numpy_ref.py` is the NumPy reference.
- `charlm/`: `CharModel.elm`, a pre-norm transformer over 64-byte windows, and `CharLm.elm`,
  which trains it and reports the held-out loss against the corpus's unigram entropy.
  `GptBench.elm` and `bench.js` build a GPT-sized training step under Node, to time graph building.

Each program run on MAX is an ordinary eco application: its `elm.json` depends on
`the-sett/elm-max`, and its main module declares the two ports `Max.Session` needs (`maxOut`,
`maxIn`) and a `logOut` whose strings the host prints. The Makefile builds it with
`eco make src/Mnist.elm --output=build/mnist.so` (for MNIST) and links that library with
`../host/max_host.cpp` and MAX's `libmax`, as the package README's "Running on MAX" describes.

## Building against this checkout

By default the examples use the published `the-sett/elm-max` named in their `elm.json` files, from
the package registry, with the host in `../host`. To build them against the package sources in this
checkout instead, for example while changing the package, add `LOCAL=1`:

```sh
make clean && make run-mnist LOCAL=1
```

## If something goes wrong

- **`no eco on the PATH`** or **`no eco headers`**: install eco as in step 1, and check that
  `eco --version` works in this shell; set `ECO_INCLUDE` to the directory that holds
  `eco/eco_embed.hpp` if it is not next to eco's `bin/`.
- **`setup-max: uv is needed`**: install uv as in step 1, and open a new shell (or
  `source ~/.local/bin/env`) so that `uv` is on the `PATH`.
- MAX reporting **"failed to resolve built-in kernel package paths"** when a program is run outside
  `make`: the Makefile sets `MODULAR_MAX_PACKAGE_ROOT`, `MODULAR_MOJO_MAX_PACKAGE_ROOT` and
  `MODULAR_MOJO_MAX_IMPORT_PATH`; run programs through `make`, or set them as it does.
