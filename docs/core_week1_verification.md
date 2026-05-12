# Member B Week 1 Verification

This note records the local checks for the Week 1 core/memory MVP.

## Scope

- `rtl/core/dot_product_engine.sv`: serial signed dot product.
- `rtl/core/tile_scheduler.sv`: row and K/V tile traversal.
- `rtl/core/flash_core.sv`: FlashAttention core control skeleton using q/kv/o handshakes.
- `rtl/mem/row_buffer.sv`: current row buffer skeleton.
- `rtl/mem/tile_buffer.sv`: K/V tile buffer skeleton.

## Local Command

Run from the repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run_member_b_week1.ps1
```

The script compiles and runs:

- `tb/sv/tb_dot_product_engine.sv`
- `tb/sv/tb_flash_core_smoke.sv`

## Expected Result

The dot product test checks two signed examples, including a negative-result case.
The core smoke test runs `S_LEN=4`, `D_MODEL=4`, `BK=2`, drives the q/kv handshakes,
and expects one output row per query row.
