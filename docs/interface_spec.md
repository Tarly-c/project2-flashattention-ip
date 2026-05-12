# Interface Specification

## Member B Core Interface

`flash_core` is intentionally AXI-agnostic. It consumes rows and tiles from the
DMA/buffer side and returns one output row at a time.

```systemverilog
module flash_core #(
    parameter int S_LEN   = 256,
    parameter int D_MODEL = 64,
    parameter int BK      = 16,
    parameter int DATA_W  = 16,
    parameter int ACC_W   = 48,
    parameter int FRAC_W  = 8
)(...);
```

### Control

| Signal | Direction | Description |
|---|---:|---|
| `start` | input | One-cycle pulse to start a run. |
| `busy` | output | Asserted while the core state machine is active. |
| `done` | output | One-cycle completion indication after the final row is accepted. |
| `error` | output | Reserved for illegal states or downstream failures. |
| `causal_en` | input | Reserved for the Week 2 causal-mask path. |
| `neg_large` | input | Reserved mask value for future softmax. |
| `scale` | input | Reserved attention scale for future softmax. |

### Q Row Input

| Signal | Direction | Description |
|---|---:|---|
| `q_req_valid` | output | Core requests a Q row. |
| `q_req_row` | output | Requested row index. |
| `q_req_ready` | input | Producer accepts the request. |
| `q_data_valid` | input | Producer presents the requested row. |
| `q_data_ready` | output | Core can capture `q_data`. |
| `q_data[D_MODEL]` | input | Signed Q8.8 row payload. |

### K/V Tile Input

| Signal | Direction | Description |
|---|---:|---|
| `kv_req_valid` | output | Core requests a K/V tile. |
| `kv_req_start` | output | Starting K/V row index for the tile. |
| `kv_req_len` | output | Number of valid rows in the tile. |
| `kv_req_ready` | input | Producer accepts the request. |
| `kv_data_valid` | input | Producer presents the requested tile. |
| `kv_data_ready` | output | Core can capture `k_tile` and `v_tile`. |
| `k_tile[BK][D_MODEL]` | input | Signed Q8.8 K tile payload. |
| `v_tile[BK][D_MODEL]` | input | Signed Q8.8 V tile payload. |

### O Row Output

| Signal | Direction | Description |
|---|---:|---|
| `o_valid` | output | Core presents one O row. |
| `o_row` | output | Output row index. |
| `o_data[D_MODEL]` | output | Signed Q8.8 output row payload. |
| `o_ready` | input | Consumer accepts the row. |

## Member B Memory Blocks

`row_buffer` and `tile_buffer` use a simple synchronous load interface:

```text
clear       clears valid state
load_valid captures payload when asserted
load_ready is always high in the Week 1 MVP
valid      indicates the stored payload is available
```
