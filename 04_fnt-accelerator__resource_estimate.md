# FNT Project Resource Estimate

This is an architecture-level estimate derived from the RTL structure, not a final Vivado or Quartus synthesis report. Final LUT, FF, BRAM, and Fmax values must be confirmed with the target FPGA, constraints, and synthesis tool.

| Section | Main hardware structure | Quantity / scale |
|---|---|---:|
| One time-multiplexed FNT core | Modular multiplier, accumulator, control counter | One modular-multiply datapath |
| FNT storage | Input, intermediate, and output arrays | Approximately 2×256×14 bits |
| Forward + inverse transforms | Two time-multiplexed FNT cores | Two modular-multiply datapaths |
| Compensation LUT | 256×14-bit coefficient array | 3584 bits, suitable for one small BRAM or register array |
| Serial/parallel buffers | 256×14-bit block registers | Approximately 3584 bits each |
| UART configuration | Receiver state machine and five-byte packet parser | A small number of FFs/LUTs |

The current generic core uses time multiplexing to save resources, at the cost of lower 256-point throughput. `fnt16_pipeline.v` provides another option: a fully unrolled 16-point, four-stage pipeline with 32 parallel butterflies. It offers higher throughput with more multipliers and combinational logic. The choice captures the engineering trade-off among resources, throughput, and latency.

