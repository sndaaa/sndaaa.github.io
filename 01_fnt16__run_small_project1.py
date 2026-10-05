from pathlib import Path
import csv, subprocess
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]; RTL=ROOT/'rtl'; SIM=ROOT/'sim'; RES=ROOT/'results'; SIM.mkdir(exist_ok=True); RES.mkdir(exist_ok=True)
Q=12289; N=16; ROOTW=4134; ROOTI=10984; NINV=11521
img=np.asarray(Image.open(r'C:\Users\snda\Desktop\aaa.png').convert('L'),dtype=np.int32).reshape(-1)
x=[int(v)%Q for v in img[:N]]
def fnt(values,inverse=False):
    root=ROOTI if inverse else ROOTW
    y=[sum(int(values[n])*pow(root,(k*n)%N,Q) for n in range(N))%Q for k in range(N)]
    return [(v*NINV)%Q for v in y] if inverse else y
with open(SIM/'small1_input.mem','w',newline='\n') as f:
    for v in x:f.write(f'{v:04x}\n')
iverilog=ROOT.parents[1]/'work'/'iverilog'/'bin'/'iverilog.exe'; vvp=ROOT.parents[1]/'work'/'iverilog'/'bin'/'vvp.exe'
c=subprocess.run([str(iverilog),'-g2012','-s','tb_fnt16_pipeline','-o',str(SIM/'small1.out'),str(RTL/'fnt16_pipeline.v'),str(RTL/'tb_fnt16_pipeline.v')],cwd=SIM,capture_output=True,text=True)
if c.returncode:raise SystemExit('small project 1 compile failed:\n'+c.stderr)
r=subprocess.run([str(vvp),'small1.out'],cwd=SIM,capture_output=True,text=True)
if r.returncode:raise SystemExit('small project 1 simulation failed:\n'+r.stdout+'\n'+r.stderr)
with open(SIM/'small1_results.csv',newline='') as f:rows=list(csv.DictReader(f))
assert len(rows)==2
forward=[int(rows[0][f'x{i}']) for i in range(N)]
inverse=[int(rows[1][f'x{i}']) for i in range(N)]
expected_forward=fnt(x); expected_inverse=x
if forward!=expected_forward:raise AssertionError(('forward',expected_forward,forward))
if inverse!=expected_inverse:raise AssertionError(('inverse',expected_inverse,inverse))
c2=subprocess.run([str(iverilog),'-g2012','-s','tb_fnt_butterfly','-o',str(SIM/'small1_butterfly.out'),str(RTL/'fnt_butterfly.v'),str(RTL/'tb_fnt_butterfly.v')],cwd=SIM,capture_output=True,text=True)
if c2.returncode:raise SystemExit('butterfly compile failed:\n'+c2.stderr)
r2=subprocess.run([str(vvp),'small1_butterfly.out'],cwd=SIM,capture_output=True,text=True)
if r2.returncode or 'PASS butterfly' not in r2.stdout:raise SystemExit('butterfly test failed:\n'+r2.stdout+'\n'+r2.stderr)
report=f'''# Small Project 1: Configurable Fixed-Point FNT Butterfly and 16-Point FNT Core

## Overview

Starting from a basic FNT butterfly, I built a 16-point FNT/IFNT core. The goal was to verify finite-field addition, subtraction, multiplication, twiddle factors, and butterfly connectivity before assembling these units into a four-stage radix-2 DIT structure.

## What I implemented

- An FNT butterfly unit with modulus Q=12289;
- A 16-point FNT core supporting forward and inverse transforms;
- Four butterfly stages with eight butterflies per stage, 32 butterflies logically;
- Inter-stage registers and valid delays;
- Bit-reversed input reordering;
- N-inverse normalization in the inverse transform;
- A Python reference model and an Icarus Verilog testbench;
- Point-by-point automatic comparison of forward and inverse transforms.

## Implementation process

First, I chose Q=12289 because 12289-1 is divisible by 16, so a 16th root of unity can be constructed. The forward root is 4134, the inverse root is 10984, and the modular inverse of 16 is 11521.

Second, I implemented the butterfly:

t = b x w mod Q
y0 = a + t mod Q
y1 = a - t mod Q

Third, I loaded the 16 inputs in bit-reversed order into stage 0 and passed them through four radix-2 stages. Every stage stores its butterfly results in registers, allowing different data blocks to occupy different stages at the same time.

Fourth, I used the inverse root for the inverse transform and multiplied by the modular inverse of 16 at the end. Applying the inverse transform after the forward transform therefore recovers the original 16 symbols.

## Verification

I used the first 16 grayscale values from aaa.png as input. Python computed the reference FNT results, and the RTL testbench computed the same data. The simulation output was written to small1_results.csv and compared point by point:

- Forward transform: 16/16 frequency-domain values matched;
- Inverse transform: all 16 time-domain values recovered;
- Maximum error: 0; butterfly-unit smoke test: passed.

## Results and significance

This project established the core methods needed by the later projects: choosing finite-field parameters, implementing modular arithmetic, partitioning butterfly stages, inserting inter-stage registers, and automatically comparing Python and RTL results.

The current version is a fully unrolled 16-point educational design. It can be extended to 64 or 256 points, or the butterfly schedule can be changed to a resource-shared structure.

## File list

### Core RTL

- rtl/fnt_butterfly.v: standalone butterfly unit;
- rtl/fnt16_pipeline.v: four-stage 16-point FNT/IFNT pipeline;
- rtl/tb_fnt_butterfly.v: standalone butterfly testbench;
- rtl/tb_fnt16_pipeline.v: standalone 16-point FNT/IFNT testbench.

### Python and simulation driver

- scripts/run_small_project1.py: generate test data, compile RTL, run simulation, and compare automatically;
- sim/small1_input.mem: 16 input symbols;
- sim/small1.out: Icarus Verilog 16-point FNT simulation executable;
- sim/small1_butterfly.out: Icarus Verilog butterfly smoke-test executable;
- sim/small1_results.csv: RTL output for forward and inverse transforms.

### Shared files from later projects

- rtl/fnt_chain_top.v: integrated FNT, compensation-LUT, and IFNT top level;
- rtl/tb_fnt_chain.v: integrated-chain testbench;
- scripts/run_fnt_project.py: early 16-point chain verification script;
- rtl/fnt_seq_core.v: resource-shared FNT core supporting 16, 64, and 256 points;
- rtl/fnt_configurable_top.v: configurable top level with UART, bypass, and serial interfaces.

## Current limitations

This small project verifies finite-field FNT only; it is not a complete complex FFT or a physical fiber-channel model. Its purpose is to establish a correct hardware transform core, pipeline, and verification method for the later dispersion-compensation and configurable-system projects.
'''

(RES/'small_project_1_report.md').write_text(report,encoding='utf-8')
print('small_project_1_ok','forward_points',N,'inverse_points',N,'max_error',0,'butterfly','pass')





