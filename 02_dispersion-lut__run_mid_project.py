from pathlib import Path
import csv, subprocess, time
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]; RTL=ROOT/'rtl'; SIM=ROOT/'sim'; RES=ROOT/'results'; SIM.mkdir(exist_ok=True); RES.mkdir(exist_ok=True)
Q=12289; G=11; D=3; modes=[16,64,256]; total=sum(modes); total_with_bypass=total+16
def roots(N):
    r=pow(G,(Q-1)//N,Q); return r,pow(r,-1,Q),pow(N,-1,Q)
def fnt(x,N,inv=False):
    r,ri,ni=roots(N); w=ri if inv else r
    y=[sum(int(x[n])*pow(w,(k*n)%N,Q) for n in range(N))%Q for k in range(N)]
    return [(v*ni)%Q for v in y] if inv else y
flat=np.asarray(Image.open(r'C:\Users\snda\Desktop\aaa.png').convert('L'),dtype=np.int32).reshape(-1)%Q
input_values=[]; expected_values=[]; coeff_values=[]; received_blocks=[]; offset=0; metrics=[]
for N in modes:
    x=[int(v) for v in flat[offset:offset+N]]; offset+=N
    r,ri,ni=roots(N); h=[pow(r,(D*k*k)%N,Q) for k in range(N)]; c=[pow(v,-1,Q) for v in h]
    tx=fnt(x,N); rx=fnt([(tx[k]*h[k])%Q for k in range(N)],N,True)
    input_values.extend(rx); expected_values.extend(x); coeff_values.extend(c); received_blocks.append(rx)
    cycles=2*N*N+2*N+4; metrics.append((N,cycles,N*100_000_000/cycles/1_000_000,cycles/100_000_000*1e6))
input_values.extend(received_blocks[0]); expected_values.extend(received_blocks[0])
def hx(v): return f'{int(v):04x}'
for path,vals in [(SIM/'mid_input.mem',input_values),(SIM/'mid_expected.mem',expected_values),(SIM/'mid_coeff.mem',coeff_values)]:
    with open(path,'w',newline='\n') as f:
        for v in vals: f.write(hx(v)+'\n')

iverilog=ROOT.parents[1]/'work'/'iverilog'/'bin'/'iverilog.exe'; vvp=ROOT.parents[1]/'work'/'iverilog'/'bin'/'vvp.exe'
sources=['fnt_seq_core.v','dispersion_lut256.v','uart_regfile.v','uart_rx_8n1.v','stream_cfg.v','fnt_configurable_top.v','tb_mid_project.v']
c=subprocess.run([str(iverilog),'-g2012','-s','tb_mid_project','-o',str(SIM/'mid_project.out')]+[str(RTL/s) for s in sources],cwd=SIM,capture_output=True,text=True)
if c.returncode: raise SystemExit('mid-project compile failed:\n'+c.stderr)
r=subprocess.run([str(vvp),'mid_project.out'],cwd=SIM,capture_output=True,text=True)
if r.returncode: raise SystemExit('mid-project simulation failed:\n'+r.stdout+'\n'+r.stderr)
with open(SIM/'mid_results.csv',newline='') as f: rows=list(csv.DictReader(f))
assert len(rows)==total_with_bypass,len(rows); errors=[]
for i,row in enumerate(rows):
    if int(row['got'])!=int(row['expected']): errors.append((i,row))
if errors: raise AssertionError(('first_error',errors[0]))

def ref_bench(N,reps=3):
    x=[int(v) for v in flat[:N]]; t0=time.perf_counter()
    for _ in range(reps): fnt(fnt(x,N),N,True)
    return (time.perf_counter()-t0)/reps
lines=['# 可配置 FNT 色散补偿中项目报告','','- RTL 链路：串行输入 → 串并转换 → FNT → 可配置补偿 LUT → IFNT → 并串转换。','- UART 包格式：A5, address_hi, address_lo, data_low, data_high；FF/FE 选择点数，FF/FD 控制旁路。','- 验证点数：16、64、256；每种点数各一个色散块，另加一个 16 点旁路块。','- 结果：所有输出符号与 Python 参考值一致，最大误差为 0。','']
lines.append('| N | 资源复用模型周期/块 | 100 MHz 理论符号率 | 单块理论延迟 |')
lines.append('|---:|---:|---:|---:|')
for N,cyc,rate,lat in metrics: lines.append(f'| {N} | {cyc} | {rate:.4f} Msym/s | {lat:.3f} μs |')
lines += ['', '上述通用核使用一个模乘器按时间复用，适合学习和资源受限设计。已有 fnt16_pipeline.v 仍是完全展开的高吞吐 16 点版本。资源/频率最终必须用目标 FPGA 综合工具确认。', '', '## Python 参考时间（仅用于方法演示）']
for N in modes: lines.append(f'- N={N}: {ref_bench(N):.6f} s/block（纯 Python 参考实现）')
(RES/'mid_project_report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('mid_project_ok','rows',len(rows),'max_error',0,'modes','16,64,256','bypass','pass')


