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
(RES/'fnt_report.md').write_text(f'''# FNT 色散补偿加速器仿真报告

- 模长：16 点，模数 `Q={Q}`，原根 `ω={ROOTW}`，逆根 `ω⁻¹={ROOTI}`。
- 变换：4 级 radix-2 DIT，输入按 4 位 bit-reverse 装载，输出自然顺序。
- 色散参数：`D={D}`；补偿 LUT 为二次相位通道系数的模逆。
- 测试块：{B} 个，每块 16 个符号，符号来自桌面 `aaa.png` 的灰度行。
- RTL：FNT → 可配置频域补偿 LUT → IFNT；仿真结果与 Python 参考逐块逐符号一致。
- 最大恢复误差：`{max_err}`（模域整数误差）。
- 补偿前接收序列平均绝对差：`{before_err:.3f}`；理想模域补偿后误差为 `0`。

## 结构

`fnt16_pipeline.v` 内含 4 个寄存器隔开的蝶形级，每级 8 个蝶形，共 32 个蝶形计算核；每个蝶形包含 1 个模乘、1 个模加和 1 个模减。`dispersion_apply.v` 含 16 个频点模乘核，系数由配置写口写入 BRAM/寄存器阵列。`fnt_chain_top.v` 将正变换、补偿和逆变换串起来，正变换和逆变换之间通过 `valid` 自动启动。

## 输出

- `received_symbols.csv`：经过模拟色散后的输入块。
- `recovered_symbols.csv`：补偿后的期望符号。
- `sim/chain_results.csv`：RTL 输出。
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
