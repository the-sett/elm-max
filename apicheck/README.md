# apicheck: the larger API, end to end on MAX

Checks of `the-sett/elm-max`'s larger pieces on small synthetic models, built from this checkout's
`../src`, compiled by eco and run on MAX through the package's host (`../host/max_host.cpp`). No
model or dataset is downloaded. `make check-apicheck` runs all four checks:

- `cache`: a Llama-shaped model (RMS-norm, grouped-query attention with rotary positions, SwiGLU,
  tied unembedding) generates 16 tokens with a KV cache through `Infer` and again from a full-context
  graph: the logits agree within 1e-6 and the greedy tokens are the same, for both rotary pairings.
- `import`: `make_checkpoint.py` writes a safetensors file in PyTorch's layouts. `Max.Safetensors`
  reads its header, and its tensors go into resident buffers and through typed import graphs, a named
  part alone and then the whole, byte-identical to NumPy's conversion; the raw buffers are then
  dropped.
- `block`: a UNet-shaped block (convolutions, group-norm, a timestep embedding, upsampling,
  cross-attention under `vmap`) trains, and its forward pass matches `ref_block.py`'s NumPy one
  within 2.1e-6.
- `int64`: integer constants beyond 2⁵³, signed and unsigned 64-bit, go through MAX and come back
  exactly.

`make run-apicheck CHECK=cache` (or `import`, `block`, `int64`) runs one and prints its full log.

## What you need

eco 0.2.0, a C++20 compiler and GNU make, as `../examples/README.md` describes, and
[uv](https://docs.astral.sh/uv/), with which `../scripts/setup-max.sh` installs MAX 26.7 and NumPy
into the repository's `.venv` the first time the Makefile needs it (shared with `../examples` and
`../opcheck`; `MAX_VENV` for another). The Makefile sets the variables `libmax` needs itself.

## Files

- `src/ApiCheck.elm`: the four checks, as one program that talks to the host over `Max.Session`'s
  ports.
- `make_checkpoint.py`: writes `work/synthetic.safetensors` and the block's weights and inputs.
- `ref_block.py`: the block's forward pass in NumPy, compared with what the program wrote.
