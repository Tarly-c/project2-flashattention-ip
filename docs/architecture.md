# Architecture Notes

## Member B Core And Memory MVP

The Week 1 core implementation is an integration-ready skeleton. It does not
yet implement online softmax, value accumulation, or final FlashAttention
normalization. Its purpose is to freeze the core handshakes, prove that the
core can compile locally, and provide a verified serial dot-product block for
the next integration step.

### Core Control Flow

`flash_core` owns the compute-side sequencing and never accesses AXI directly.
It talks to the DMA/top layer through three handshake groups:

- Q row request: `q_req_valid`, `q_req_row`, `q_req_ready`, then `q_data_valid`.
- K/V tile request: `kv_req_valid`, `kv_req_start`, `kv_req_len`, `kv_req_ready`, then `kv_data_valid`.
- O row output: `o_valid`, `o_row`, `o_data`, `o_ready`.

The MVP state machine loads one Q row, walks all K/V tiles with
`tile_scheduler`, runs the serial dot-product engine on the first K row of each
tile as a smoke compute path, then emits one placeholder O row. This keeps the
baseline interface stable while leaving the online softmax/value path to land
in Week 2.

### Tile Scheduler

`tile_scheduler` emits `(row_index, kv_start, kv_len)` tuples. With the default
`S_LEN=256` and `BK=16`, it walks each query row across sixteen K/V tiles. The
final tile length is clamped for non-divisible configurations, which makes the
block usable for small tests such as `S_LEN=4`, `BK=2`.

### Dot Product

`dot_product_engine` is a serial signed MAC:

```text
dot = sum(q_vec[d] * k_vec[d]), d = 0 .. D_MODEL-1
```

Inputs and outputs are fixed-point containers, but the module treats them as
signed integers and leaves scaling interpretation to the caller. The product is
sign-extended into a 48-bit accumulator by default.

### Buffers

`row_buffer` and `tile_buffer` are synchronous load/hold buffers. They provide
the minimum storage shell needed for Q row and K/V tile data while the DMA and
core contracts are still being integrated.
