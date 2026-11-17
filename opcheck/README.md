# opcheck: every operation and gradient against NumPy

The numerical checks of `the-sett/elm-max`. `src/OpCheck.elm` builds one graph per family of
operations, 20 in all (unary and binary arithmetic, integers, reductions, linear algebra, shapes,
network operations and layers, convolutions, control flow, `vmap`, transforms, random numbers,
dtypes and selection, plus pinned edge cases), each with its gradients, from this checkout's
`../src`. Each
family is checked against NumPy in two ways:

- `make check-ops` runs the graphs on MAX, through MAX's Python API, and compares values and
  gradients with NumPy's, the gradients by central differences in f64.
- `make check-ops-eval` runs the same graphs with `Tensor.Eval`, the package's pure-Elm evaluator,
  under Node, with no MAX, and compares them with the same references and tolerances.

`make check-bytecode`, after `check-ops`, reads every graph's bytecode and generic text back with
`mlir-opt` and requires the same IR.

## What you need

Stock Elm 0.19.1 (`elm`), Node.js 18 or later, and [uv](https://docs.astral.sh/uv/), with which
`../scripts/setup-max.sh` installs MAX 26.7 and NumPy into the repository's `.venv` the first time
the Makefile needs it (shared with `../examples` and `../apicheck`; `MAX_VENV` for another).
`mlir-opt` is needed only for `check-bytecode` (any LLVM build that reads MLIR bytecode version 4;
`MLIR_OPT` to name it). No eco and no C++ compiler are needed: the graphs are written by Elm
compiled to JavaScript.

```sh
make check-ops                              # every family on MAX
make check-ops FAMILIES="unary linalg"      # some families
make check-ops-eval                         # the same checks in Elm, without MAX
```

On MAX 26.7.0's CPU, `check-ops` passes 405 checks and `check-ops-eval` 402, with the `pins64`
family refused under Node because its integer inputs are not exact as JavaScript numbers.

## Files

- `src/OpCheck.elm`: the families, each a graph with its inputs' domains and its checks.
- `emit.js`: runs the compiled `OpCheck` under Node and writes each family's graph (bytecode,
  generic text and a version for GPU 0) and `manifest.json` to `work/opcheck/`.
- `ref.py`: draws each family's inputs, runs the graphs on MAX or reads `eval.js`'s results, and
  checks them against NumPy.
- `eval.js`: runs `OpCheck` with the drawn inputs under Node, evaluating every graph with
  `Tensor.Eval`.
- `mo-inventory.md`: how MAX's own graph API spells each operation in the `mo` and `rmo` dialects,
  the reference the package's lowering and these checks follow.
