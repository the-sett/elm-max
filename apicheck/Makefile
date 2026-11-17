# End-to-end checks of the-sett/elm-max's larger API on synthetic models, built from this
# checkout's src/ and run on MAX through the package's host. See README.md.
#
#   make check-apicheck        all four checks, and the block's NumPy reference
#   make run-apicheck CHECK=x  one check: cache, import, block or int64

ECO       ?= eco
# eco's headers sit in include/ next to the bin/ that holds eco (/usr/local/include for the .deb).
ECO_PREFIX = $(abspath $(dir $(realpath $(shell command -v $(ECO))))/..)
ECO_INCLUDE ?= $(ECO_PREFIX)/include
# The repository's MAX venv (MAX and NumPy), shared with ../examples and ../opcheck; made by
# ../scripts/setup-max.sh when missing.
MAX_VENV  ?= $(abspath $(CURDIR)/../.venv)
PYTHON    := $(MAX_VENV)/bin/python
# Asked of the venv when needed, as it may not exist when make starts.
MAX_SITE   = $(shell $(PYTHON) -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])' 2>/dev/null)
MAX_LIB    = $(MAX_SITE)/modular/lib
CXX       ?= g++
CXXFLAGS   = -std=c++20 -O2 -Wall -Wextra -I$(ECO_INCLUDE) -I$(MAX_SITE)/max/include
B         := $(CURDIR)/build
W         := $(CURDIR)/work
MAX_HOST  := $(abspath $(CURDIR)/../host/max_host.cpp)
CHECK     ?= cache

# libmax finds its built-in kernel packages only through these variables (MAX's Python wrapper sets
# them itself); the last is MAX's documented telemetry opt-out.
export MODULAR_MAX_PACKAGE_ROOT = $(MAX_SITE)/modular
export MODULAR_MOJO_MAX_PACKAGE_ROOT = $(MAX_SITE)/modular
export MODULAR_MOJO_MAX_IMPORT_PATH = $(MAX_SITE)/modular/lib/mojo
export MODULAR_TELEMETRY_ENABLED = 0

$(PYTHON):
	MAX_VENV=$(MAX_VENV) ../scripts/setup-max.sh

check-eco:
	@command -v $(ECO) > /dev/null || { echo "no $(ECO) on the PATH: install eco (../examples/README.md)"; exit 1; }
	@test -f $(ECO_INCLUDE)/eco/eco_embed.hpp || { echo "no eco headers in $(ECO_INCLUDE): set ECO_INCLUDE"; exit 1; }

# ApiCheck.elm, compiled by eco to a shared library, linked with the package's host and libmax.
$(B)/apicheck.so: $(wildcard src/*.elm) $(shell find ../src -name '*.elm') elm.json | check-eco
	mkdir -p $(B)
	$(ECO) make src/ApiCheck.elm --output=$@

$(B)/apicheck_bridge: $(MAX_HOST) $(B)/apicheck.so | $(PYTHON) check-eco
	$(CXX) $(CXXFLAGS) $< $(B)/apicheck.so -L$(MAX_LIB) -lmax -lm -pthread -Wl,-rpath,$(B):$(MAX_LIB) -o $@

# A checkpoint in PyTorch's layouts, and the block's weights and NumPy reference inputs.
$(W)/synthetic.safetensors: make_checkpoint.py | $(PYTHON)
	mkdir -p $(W)/block
	$(PYTHON) -I $< $(W)

run-apicheck: $(B)/apicheck_bridge $(W)/synthetic.safetensors
	$(B)/apicheck_bridge $(W) '{"check": "$(CHECK)", "dir": "$(W)"}'

check-apicheck: $(B)/apicheck_bridge $(W)/synthetic.safetensors
	@for c in cache import block int64; do \
	  $(B)/apicheck_bridge $(W) '{"check": "'$$c'", "dir": "$(W)"}' > $(W)/$$c.log 2>&1; \
	  grep -h -E '"(PASS|FAIL)|HOST residents' $(W)/$$c.log | sed 's/^\[[^]]*\] //'; \
	  if grep -q '"FAIL' $(W)/$$c.log || ! grep -q '"PASS' $(W)/$$c.log; then echo "apicheck $$c failed ($(W)/$$c.log)"; exit 1; fi; \
	done
	@grep -q 'HOST residents: 11 buffers' $(W)/import.log || { echo "import: raw buffers left resident"; exit 1; }
	$(PYTHON) -I ref_block.py $(W)

clean:
	rm -rf $(B) $(W)

.PHONY: check-eco run-apicheck check-apicheck clean
