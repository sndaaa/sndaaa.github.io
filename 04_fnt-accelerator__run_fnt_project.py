from pathlib import Path
import csv, subprocess
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]; RTL=ROOT/'rtl'; SIM=ROOT/'sim'; RES=ROOT/'results'; SIM.mkdir(exist_ok=True); RES.mkdir(exist_ok=True)
Q=12289; N=16; G=11; ROOTW=pow(G,(Q-1)//N,Q); ROOTI=pow(ROOTW,-1,Q); NINV=pow(N,-1,Q); D=3; B=16
def fnt(x,inv=False):
    r=ROOTI if inv else ROOTW; out=[]
    for k in range(N): out.append(sum(int(x[n])*pow(r,(k*n)%N,Q) for n in range(N))%Q)
    if inv: out=[(v*NINV)%Q for v in out]
    return out
def hx(v): return f'{int(v):04x}'

# Derive configurable quadratic phase channel and inverse compensation LUT.
channel=[pow(ROOTW,(D*k*k)%N,Q) for k in range(N)]; comp=[pow(v,-1,Q) for v in channel]
with open(SIM/'comp_lut.mem','w',newline='\n') as f:
    for v in comp: f.write(hx(v)+'\n')

# Use 16x16 grayscale tiles from the same aaa.png used by the image pipeline.
img=np.asarray(Image.open(r'C:\Users\snda\Desktop\aaa.png').convert('L'),dtype=np.uint16)
blocks=[]; expected=[]; received=[]
for by in range(4):
    for bx in range(4):
        x=[int(v)%Q for v in img[by*4,(bx*4):(bx*4+16)]]
        # Channel impairment in the frequency domain; hardware removes it.
        y=fnt([(v) for v in x]); y=[(y[k]*channel[k])%Q for k in range(N)]; rx=fnt(y,True)
        blocks.append(sum(v<<(14*i) for i,v in enumerate(rx))); expected.append(x); received.append(rx)
with open(SIM/'chain_vectors.mem','w',newline='\n') as f:
    for v in blocks: f.write(f'{v:056x}\n')

iverilog=ROOT.parents[1]/'work'/'iverilog'/'bin'/'iverilog.exe'; vvp=ROOT.parents[1]/'work'/'iverilog'/'bin'/'vvp.exe'
c=subprocess.run([str(iverilog),'-g2012','-s','tb_fnt_chain','-o',str(SIM/'fnt_chain.out'),str(RTL/'fnt_butterfly.v'),str(RTL/'fnt16_pipeline.v'),str(RTL/'dispersion_apply.v'),str(RTL/'fnt_chain_top.v'),str(RTL/'stream_blocks.v'),str(RTL/'tb_fnt_chain.v')],cwd=SIM,capture_output=True,text=True)
if c.returncode: raise SystemExit('FNT compile failed:\n'+c.stderr)
r=subprocess.run([str(vvp),'fnt_chain.out'],cwd=SIM,capture_output=True,text=True)
if r.returncode: raise SystemExit('FNT simulation failed:\n'+r.stderr)
with open(SIM/'chain_results.csv',newline='') as f: rows=list(csv.DictReader(f))
assert len(rows)==B,len(rows); max_err=0
for bi,row in enumerate(rows):
    got=[int(row[f'y{k}']) for k in range(N)]; exp=expected[bi]; max_err=max(max_err,max(abs(a-b) for a,b in zip(got,exp)))
    if got!=exp: raise AssertionError(('block',bi,exp,got))

# Save received and recovered waveforms for inspection.
received_arr=np.asarray(received,dtype=np.int32); expected_arr=np.asarray(expected,dtype=np.int32)
np.savetxt(RES/'received_symbols.csv',received_arr,fmt='%d',delimiter=','); np.savetxt(RES/'recovered_symbols.csv',expected_arr,fmt='%d',delimiter=',')
before_err=float(np.mean(np.abs(received_arr-expected_arr))); after_err=float(np.mean(np.abs(received_arr*0)))
(RES/'fnt_report.md').write_text(f'''# FNT Dispersion-Compensation Accelerator Simulation Report

- Transform length: 16 points; modulus Q={Q}; primitive root omega={ROOTW}; inverse root omega_inverse={ROOTI}.
- Transform: four-stage radix-2 DIT with 4-bit bit-reversed input loading and natural-order output.
- Dispersion parameter: D={D}; the compensation LUT contains modular inverses of the quadratic-phase channel coefficients.
- Test data: {B} blocks of 16 symbols, taken from grayscale rows of aaa.png.
- RTL chain: FNT -> configurable frequency-domain compensation LUT -> IFNT; RTL and Python reference results match symbol by symbol for every block.
- Maximum recovery error: {max_err} in the modular integer domain.
- Mean absolute difference before compensation: {before_err:.3f}; ideal modular compensation reduces the error to 0.

## Architecture

fnt16_pipeline.v contains four register-separated butterfly stages with eight butterflies per stage, for 32 butterfly units in total. Each butterfly contains one modular multiplier, one modular adder, and one modular subtractor. dispersion_apply.v contains 16 frequency-bin multipliers whose coefficients are written through the configuration port into a BRAM/register array. fnt_chain_top.v connects the forward transform, compensation, and inverse transform; the valid signal automatically starts the inverse transform after the forward transform.

## Outputs

- received_symbols.csv: input blocks after simulated dispersion.
- recovered_symbols.csv: expected symbols after compensation.
- sim/chain_results.csv: RTL output.
''',encoding='utf-8')

# Run the two standalone small-project smoke tests as well.
for name,top,srcs in [
    ('butterfly','tb_fnt_butterfly',['fnt_butterfly.v','tb_fnt_butterfly.v']),
    ('stream','tb_stream_blocks',['stream_blocks.v','tb_stream_blocks.v'])]:
    cc=subprocess.run([str(iverilog),'-g2012','-s',top,'-o',str(SIM/(name+'.out'))]+[str(RTL/s) for s in srcs],cwd=SIM,capture_output=True,text=True)
    if cc.returncode: raise SystemExit(name+' compile failed:\n'+cc.stderr)
    rr=subprocess.run([str(vvp),name+'.out'],cwd=SIM,capture_output=True,text=True)
    if rr.returncode or ('PASS '+name not in rr.stdout): raise SystemExit(name+' simulation failed:\n'+rr.stdout+'\n'+rr.stderr)
print('fnt_simulation_ok',B,'blocks','max_error',max_err,'before_mae',round(before_err,3),'smoke_tests','butterfly,stream')

