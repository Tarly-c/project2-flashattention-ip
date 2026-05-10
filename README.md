# project2-flashattention-ip
# Project2 FlashAttention Hardware Accelerator IP

本项目为课程 Project2 的 FlashAttention-style 硬件加速器 IP 设计。

目标是使用 Verilog/SystemVerilog 实现一个可验证、可综合、可扩展的 FlashAttention 加速器。Baseline 固定为单 batch、单 head，`S=256`，`d=64`，输入输出数据格式为 Q8.8 定点数。

项目重点包括：

- FlashAttention-style attention 计算
- online softmax
- K/V tiling
- causal mask 支持
- AXI4-Lite 控制接口
- AXI4 Master / DMA 数据搬运
- RTL 仿真验证
- FP32 golden model 对比
- 综合脚本与设计报告

---

## 1. Project Baseline

当前 baseline 配置如下：

```text
S = 256
D = 64
Batch = 1
Head = 1
BQ = 1
BK = 16
Q/K/V/O = Q8.8 signed fixed-point
Dot-product accumulator = 40-bit 或 48-bit
支持 causal mask
禁止存储完整 attention score/probability matrix