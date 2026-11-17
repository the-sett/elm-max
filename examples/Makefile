# Builds and runs the-sett/elm-max's examples on Modular MAX. See README.md for what to install.
# The first run makes the repository's MAX venv (../scripts/setup-max.sh) and downloads MNIST.
#
#   make run-mnist        train and evaluate an MNIST model (MODEL=sgd|adamw|stack|cnn|lora,
#                         FORMAT=bytecode|generic, TRACE=n, RELOAD=true: save, reload, re-evaluate)
#   make run-mnist-ref    the same SGD model in NumPy, for comparison
#   make run-charlm       train a byte-level language model (LAYERS=2, SHARED=false, STEPS=1000)
#   make check-bytecode   MNIST's bytecode and generic text read back as the same IR (needs an
#                         mlir-opt on the PATH or in MLIR_OPT)
#
# Elm programs are built with an installed eco: `eco make` writes a shared library (.so) that the
# C++ host links. The package's checks are in ../opcheck (every operation against NumPy) and
# ../apicheck (the larger API on synthetic models).

ECO       ?= eco
# eco's headers sit in include/ next to the bin/ that holds eco (/usr/local/include for the .deb).
ECO_PREFIX = $(abspath $(dir $(realpath $(shell command -v $(ECO))))/..)
ECO_INCLUDE ?= $(ECO_PREFIX)/include
# The Python venv MAX comes in (its wheel carries libmax.so, its C headers and its kernels), shared
# with ../opcheck and ../apicheck; made by ../scripts/setup-max.sh when missing.
MAX_VENV  ?= $(abspath $(CURDIR)/../.venv)
PYTHON    := $(MAX_VENV)/bin/python
# Asked of the venv when needed, as it may not exist when make starts.
MAX_SITE   = $(shell $(PYTHON) -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])' 2>/dev/null)
MAX_LIB    = $(MAX_SITE)/modular/lib
CXX       ?= g++
CXXFLAGS   = -std=c++20 -O2 -Wall -Wextra -I$(ECO_INCLUDE) -I$(MAX_SITE)/max/include
# libmax finds its built-in kernel packages only through these variables (MAX's Python wrapper sets
# them itself); the last is MAX's documented telemetry opt-out.
export MODULAR_MAX_PACKAGE_ROOT = $(MAX_SITE)/modular
export MODULAR_MOJO_MAX_PACKAGE_ROOT = $(MAX_SITE)/modular
export MODULAR_MOJO_MAX_IMPORT_PATH = $(MAX_SITE)/modular/lib/mojo
export MODULAR_TELEMETRY_ENABLED = 0
B         := $(CURDIR)/build
MLIR_OPT  ?= mlir-opt
# Reads an MLIR file back in generic form. the-sett/elm-mlir's text writer prints the attributes of
# an op that has a `callee` (mo.call) as <{...}> properties, while its bytecode keeps them in the
# {...} dictionary; MAX reads both as the same op, so on those lines the two spellings are made one.
READ_BACK = $(MLIR_OPT) --allow-unregistered-dialect --mlir-print-op-generic $(1) | sed -E '/callee = /s/<\{(.*)\}>/{\1}/'

# The apps depend on the published the-sett/elm-max (each elm.json names its version), which eco
# fetches from the package registry. LOCAL=1 builds them against this checkout's src/ instead.
ifeq ($(LOCAL),1)
LOCAL_PKGS := --local-package the-sett/elm-max=$(abspath $(CURDIR)/..)
endif
# The package's generic MAX host (the C++ side of Max.Session); each *_bridge is it linked with one
# app.
MAX_HOST  := $(abspath $(CURDIR)/../host/max_host.cpp)

all: $(B)/max_bridge $(B)/charlm_bridge

$(PYTHON):
	MAX_VENV=$(MAX_VENV) ../scripts/setup-max.sh

check-eco:
	@command -v $(ECO) > /dev/null || { echo "no $(ECO) on the PATH: install eco (README.md)"; exit 1; }
	@test -f $(ECO_INCLUDE)/eco/eco_embed.hpp || { echo "no eco headers in $(ECO_INCLUDE): set ECO_INCLUDE"; exit 1; }

# An Elm program in project directory $(1), module $(2), as $(B)/$(3).so
define elm_so
	mkdir -p $(B)
	cd $(1) && $(ECO) make src/$(2).elm --output=$(B)/$(3).so $(LOCAL_PKGS)
endef

# -- MNIST

$(B)/mnist.so: $(wildcard mnist/src/*.elm) mnist/elm.json | check-eco
	$(call elm_so,mnist,Mnist,mnist)

$(B)/max_bridge: $(MAX_HOST) $(B)/mnist.so | $(PYTHON) check-eco
	$(CXX) $(CXXFLAGS) $< $(B)/mnist.so -L$(MAX_LIB) -lmax -lm -pthread -Wl,-rpath,$(B):$(MAX_LIB) -o $@

# FORMAT: bytecode (MLIR bytecode) or generic (the same ops as MLIR generic text). Graphs land in
# work/<FORMAT>/graph-<id>.mlir[bc]. TRACE=n logs the first n step losses of epoch 1.
FORMAT ?= bytecode
TRACE ?= 0
MODEL ?= sgd
RELOAD ?= false
run-mnist: $(B)/max_bridge mnist/data/t10k-labels-idx1-ubyte
	mkdir -p work/$(FORMAT) work/checkpoints
	$(B)/max_bridge $(CURDIR)/work/$(FORMAT) '{"dataDir": "$(CURDIR)/mnist/data", "format": "$(FORMAT)", "trace": $(TRACE), "variant": "$(MODEL)", "checkpoints": "$(CURDIR)/work/checkpoints", "reload": $(RELOAD)}'

run-mnist-ref: mnist/data/t10k-labels-idx1-ubyte | $(PYTHON)
	$(PYTHON) -I mnist/ref/numpy_ref.py mnist/data

# MNIST, downloaded once and checked against torchvision's MD5s (mnist/mnist.md5).
MNIST_URL := https://ossci-datasets.s3.amazonaws.com/mnist
mnist/data/t10k-labels-idx1-ubyte:
	mkdir -p mnist/data
	cd mnist/data && for f in train-images-idx3-ubyte train-labels-idx1-ubyte t10k-images-idx3-ubyte t10k-labels-idx1-ubyte; do \
	  curl -sSfL --retry 2 -o $$f.gz $(MNIST_URL)/$$f.gz || exit 1; \
	done && md5sum -c ../mnist.md5 && gunzip -f ./*.gz

# Each graph's bytecode and generic text, from runs with FORMAT=bytecode and FORMAT=generic, must read
# back as the same IR.
check-bytecode:
	@for g in 1 2; do \
	  $(call READ_BACK,work/bytecode/graph-$$g.mlirbc) > work/graph-$$g.from-bc.mlir && \
	  $(call READ_BACK,work/generic/graph-$$g.mlir) > work/graph-$$g.from-text.mlir && \
	  cmp work/graph-$$g.from-bc.mlir work/graph-$$g.from-text.mlir && \
	  echo "graph $$g: bytecode and generic text read back identical ($$(wc -l < work/graph-$$g.from-bc.mlir) lines)" || exit 1; \
	done

# -- The char model

$(B)/charlm.so: $(wildcard charlm/src/*.elm) charlm/elm.json | check-eco
	$(call elm_so,charlm,CharLm,charlm)

$(B)/charlm_bridge: $(MAX_HOST) $(B)/charlm.so | $(PYTHON) check-eco
	$(CXX) $(CXXFLAGS) $< $(B)/charlm.so -L$(MAX_LIB) -lmax -lm -pthread -Wl,-rpath,$(B):$(MAX_LIB) -o $@

# The corpus: this package's README and Elm sources, concatenated (CORPUS=file for any other text).
CORPUS ?= work/charlm/corpus.txt
work/charlm/corpus.txt:
	mkdir -p work/charlm
	cat ../README.md $$(find ../src -name '*.elm' | sort) > $@

LAYERS ?= 2
SHARED ?= false
STEPS ?= 1000
run-charlm: $(B)/charlm_bridge $(CORPUS)
	$(B)/charlm_bridge $(CURDIR)/work/charlm '{"corpus": "$(abspath $(CORPUS))", "layers": $(LAYERS), "shared": $(SHARED), "steps": $(STEPS), "trace": $(TRACE)}'

clean:
	rm -rf $(B) work

.PHONY: all check-eco run-mnist run-mnist-ref check-bytecode run-charlm clean
