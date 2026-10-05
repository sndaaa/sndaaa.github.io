# FNT Dispersion-Compensation Accelerator Simulation Report

- Transform length: 16 points; modulus `Q=12289`; primitive root `ω=4134`; inverse root `ω⁻¹=10984`.
- Transform: four-stage radix-2 DIT with 4-bit bit-reversed input loading and natural-order output.
- Dispersion parameter: `D=3`; the compensation LUT contains modular inverses of the quadratic-phase channel coefficients.
- Test data: 16 blocks of 16 symbols, taken from grayscale rows of `aaa.png`.
- RTL chain: FNT → configurable frequency-domain compensation LUT → IFNT; RTL and Python reference results match symbol by symbol for every block.
- Maximum recovery error: `0` in the modular integer domain.
- Mean absolute difference before compensation: `6481.199`; ideal modular compensation reduces the error to `0`.

## Architecture

`fnt16_pipeline.v` contains four register-separated butterfly stages with eight butterflies per stage, for 32 butterfly units in total. Each butterfly contains one modular multiplier, one modular adder, and one modular subtractor. `dispersion_apply.v` contains 16 frequency-bin multipliers whose coefficients are written through the configuration port into a BRAM/register array. `fnt_chain_top.v` connects the forward transform, compensation, and inverse transform; the `valid` signal automatically starts the inverse transform after the forward transform.

## Outputs

- `received_symbols.csv`: input blocks after simulated dispersion.
- `recovered_symbols.csv`: expected symbols after compensation.
- `sim/chain_results.csv`: RTL output.

