$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Build = Join-Path $Root "sim_build"
New-Item -ItemType Directory -Force -Path $Build | Out-Null

function Assert-LastExit {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE"
    }
}

function Invoke-CheckedVvp {
    param([string]$Path)
    $Output = & vvp $Path 2>&1
    $Output
    $Text = $Output | Out-String
    if (($LASTEXITCODE -ne 0) -or ($Text -match "FAIL|FATAL")) {
        throw "Simulation failed: $Path"
    }
}

$DotOut = Join-Path $Build "tb_dot_product_engine.vvp"
iverilog -g2012 -Wall `
    -o $DotOut `
    (Join-Path $Root "rtl/core/dot_product_engine.sv") `
    (Join-Path $Root "tb/sv/tb_dot_product_engine.sv")
Assert-LastExit "dot_product_engine compile"
Invoke-CheckedVvp $DotOut

$SchedulerOut = Join-Path $Build "tb_tile_scheduler_bitexact.vvp"
iverilog -g2012 -Wall `
    -o $SchedulerOut `
    (Join-Path $Root "rtl/core/tile_scheduler.sv") `
    (Join-Path $Root "tb/sv/tb_tile_scheduler_bitexact.sv")
Assert-LastExit "tile_scheduler bit-exact compile"
Invoke-CheckedVvp $SchedulerOut

$BufferOut = Join-Path $Build "tb_buffers_bitexact.vvp"
iverilog -g2012 -Wall `
    -o $BufferOut `
    (Join-Path $Root "rtl/mem/row_buffer.sv") `
    (Join-Path $Root "rtl/mem/tile_buffer.sv") `
    (Join-Path $Root "tb/sv/tb_buffers_bitexact.sv")
Assert-LastExit "buffer bit-exact compile"
Invoke-CheckedVvp $BufferOut

$CoreOut = Join-Path $Build "tb_flash_core_smoke.vvp"
iverilog -g2012 -Wall `
    -o $CoreOut `
    (Join-Path $Root "rtl/include/flash_attn_pkg.sv") `
    (Join-Path $Root "rtl/core/tile_scheduler.sv") `
    (Join-Path $Root "rtl/mem/row_buffer.sv") `
    (Join-Path $Root "rtl/mem/tile_buffer.sv") `
    (Join-Path $Root "rtl/core/dot_product_engine.sv") `
    (Join-Path $Root "rtl/core/causal_mask_unit.sv") `
    (Join-Path $Root "rtl/core/online_softmax_engine.sv") `
    (Join-Path $Root "rtl/core/value_accumulator.sv") `
    (Join-Path $Root "rtl/core/quantize_saturate.sv") `
    (Join-Path $Root "rtl/core/normalizer.sv") `
    (Join-Path $Root "rtl/core/flash_core.sv") `
    (Join-Path $Root "tb/sv/tb_flash_core_smoke.sv")
Assert-LastExit "flash_core smoke compile"
Invoke-CheckedVvp $CoreOut

$Matrix16Out = Join-Path $Build "tb_flash_core_matrix16_bitexact.vvp"
iverilog -g2012 -Wall `
    -o $Matrix16Out `
    (Join-Path $Root "rtl/include/flash_attn_pkg.sv") `
    (Join-Path $Root "rtl/core/tile_scheduler.sv") `
    (Join-Path $Root "rtl/mem/row_buffer.sv") `
    (Join-Path $Root "rtl/mem/tile_buffer.sv") `
    (Join-Path $Root "rtl/core/dot_product_engine.sv") `
    (Join-Path $Root "rtl/core/causal_mask_unit.sv") `
    (Join-Path $Root "rtl/core/online_softmax_engine.sv") `
    (Join-Path $Root "rtl/core/value_accumulator.sv") `
    (Join-Path $Root "rtl/core/quantize_saturate.sv") `
    (Join-Path $Root "rtl/core/normalizer.sv") `
    (Join-Path $Root "rtl/core/flash_core.sv") `
    (Join-Path $Root "tb/sv/tb_flash_core_matrix16_bitexact.sv")
Assert-LastExit "flash_core matrix16 bit-exact compile"
Invoke-CheckedVvp $Matrix16Out

Write-Host "Member B core RTL checks passed."
