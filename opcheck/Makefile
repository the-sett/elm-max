# The numerical checks of the-sett/elm-max: every operation and its gradients, built from this
# checkout's src/, checked against NumPy. See README.md.
#
#   make check-ops        on MAX (its Python API), against NumPy (FAMILIES="unary linalg" for some)
#   make check-ops-eval   the same checks run by Tensor.Eval under Node, without MAX
#   make check-bytecode   after check-ops, every graph's bytecode and generic text read back as the
#                         same IR (needs an mlir-opt on the PATH or in MLIR_OPT)

ELM       ?= elm
NODE      ?= node
# The repository's MAX venv (MAX and NumPy), shared with ../examples and ../apicheck; made by
# ../scripts/setup-max.sh when missing.
MAX_VENV  ?= $(abspath $(CURDIR)/../.venv)
PYTHON    := $(MAX_VENV)/bin/python
MLIR_OPT  ?= mlir-opt
W         := $(CURDIR)/work
FAMILIES  ?=
# MAX's documented telemetry opt-out; without it every MAX session makes an HTTPS call to Modular.
export MODULAR_TELEMETRY_ENABLED = 0

$(PYTHON):
	MAX_VENV=$(MAX_VENV) ../scripts/setup-max.sh

# OpCheck.elm, compiled to JavaScript, writes one graph per family (bytecode, generic text and a
# version for GPU 0) and a manifest of each family's inputs, checks and tolerances.
$(W)/opcheck.js: $(wildcard src/*.elm) $(shell find ../src -name '*.elm') elm.json
	mkdir -p $(W)
	$(ELM) make src/OpCheck.elm --output=$@

$(W)/opcheck/manifest.json: $(W)/opcheck.js emit.js
	$(NODE) emit.js $(W)/opcheck.js $(W)/opcheck

check-ops: $(W)/opcheck/manifest.json | $(PYTHON)
	$(PYTHON) -I ref.py $(W)/opcheck/manifest.json $(FAMILIES)

# ref.py draws the inputs, eval.js runs OpCheck with them under Node, ref.py checks the results.
check-ops-eval: $(W)/opcheck/manifest.json | $(PYTHON)
	$(PYTHON) -I ref.py --dump-inputs $(W)/opcheck/manifest.json $(W)/opcheck/inputs.json
	$(NODE) --stack-size=65500 eval.js $(W)/opcheck.js $(W)/opcheck/inputs.json $(W)/opcheck/results.json
	$(PYTHON) -I ref.py --results $(W)/opcheck/results.json $(W)/opcheck/manifest.json $(FAMILIES)

# Reads an MLIR file back in generic form. the-sett/elm-mlir's text writer prints the attributes of
# an op that has a `callee` (mo.call) as <{...}> properties, while its bytecode keeps them in the
# {...} dictionary; MAX reads both as the same op, so on those lines the two spellings are made one.
READ_BACK = $(MLIR_OPT) --allow-unregistered-dialect --mlir-print-op-generic $(1) | sed -E '/callee = /s/<\{(.*)\}>/{\1}/'

check-bytecode: $(W)/opcheck/manifest.json
	@for f in $(W)/opcheck/*.mlir; do \
	  $(call READ_BACK,$$f) > $$f.from-text && \
	  $(call READ_BACK,$${f}bc) > $$f.from-bc && \
	  cmp -s $$f.from-text $$f.from-bc || { echo "differ: $$f"; exit 1; }; \
	done; echo "op-check: bytecode and generic text read back identical ($$(ls $(W)/opcheck/*.mlir | wc -l) graphs)"

clean:
	rm -rf $(W)

.PHONY: check-ops check-ops-eval check-bytecode clean
