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
report=f'''# 第一个小项目：可配置定点 FNT 蝶形运算单元与 16 点 FNT 核

## 项目概述

我从一个最基本的 FNT 蝶形开始，逐步搭建了一个 16 点 FNT/IFNT 核。我的目标不是一开始就做完整光通信系统，而是先把有限域加法、减法、乘法、旋转因子和蝶形连接关系验证清楚，再把这些小单元组织成 4 级 radix-2 DIT 结构。

## 我实现了什么

- 一个模数为 Q=12289 的 FNT 蝶形运算单元；
- 支持正变换和逆变换的 16 点 FNT 核；
- 4 个蝶形级，每级 8 个蝶形，逻辑上共 32 个蝶形；
- 级间寄存器和 valid 延迟；
- bit-reverse 输入重排；
- 逆变换中的 N⁻¹ 归一化；
- Python 参考模型和 Icarus Verilog testbench；
- 正变换和逆变换的逐点自动比对。

## 我的实现过程

第一步，我选了 Q=12289，因为它满足 12289-1 可以被 16 整除，能够构造 16 阶单位根。得到的正变换根是 4134，逆根是 10984，16 的模逆是 11521。

第二步，我先实现蝶形：

t = b × w mod Q
y0 = a + t mod Q
y1 = a - t mod Q

第三步，我把 16 个输入按 bit-reverse 顺序装载到第 0 级，然后依次经过 4 个 radix-2 级。每一级的蝶形结果都保存到寄存器中，因此不同数据块可以在不同级同时存在。

第四步，我把逆根用于逆变换，并在最后乘以 16 的模逆。这样正变换后的数据再经过逆变换，能够恢复原始 16 个符号。

## 验证方法

我从 aaa.png 的灰度数据取出前 16 个值作为输入。Python 先计算参考 FNT 结果，RTL testbench 再计算同一组数据。仿真输出写入 small1_results.csv，脚本逐点比较：

- 正变换：16/16 个频域结果一致；
- 逆变换：16/16 个时域结果恢复；
- 最大误差：0；蝶形单元 smoke test：通过。

## 结果和意义

这个项目让我掌握了后续中项目需要的几个核心方法：如何选择有限域参数，如何写模运算，如何拆分蝶形级，如何在级间插入寄存器，以及如何用 Python 和 RTL 做自动比对。

当前版本是 16 点、完全展开的教学版。后续可以继续扩展到 64/256 点，或者把蝶形调度改成资源复用结构。

## 文件清单

### 核心 RTL

- rtl/fnt_butterfly.v：独立蝶形运算单元；
- rtl/fnt16_pipeline.v：4 级 16 点 FNT/IFNT 流水线；
- rtl/tb_fnt_butterfly.v：蝶形单元独立测试平台；
- rtl/tb_fnt16_pipeline.v：16 点 FNT/IFNT 独立测试平台。

### Python 与仿真驱动

- scripts/run_small_project1.py：生成测试数据、编译 RTL、运行仿真、自动比较；
- sim/small1_input.mem：16 个输入符号；
- sim/small1.out：Icarus Verilog 16 点 FNT 仿真可执行文件；
- sim/small1_butterfly.out：Icarus Verilog 蝶形单元 smoke test 可执行文件；
- sim/small1_results.csv：正变换和逆变换的 RTL 输出。

### 与后续中项目共享、但不属于本小项目核心的文件

- rtl/fnt_chain_top.v：FNT、补偿 LUT、IFNT 的集成顶层；
- rtl/tb_fnt_chain.v：集成链路测试平台；
- scripts/run_fnt_project.py：中项目早期的 16 点链路验证脚本；
- rtl/fnt_seq_core.v：支持 16/64/256 点的资源复用 FNT 核；
- rtl/fnt_configurable_top.v：带 UART、旁路和串行接口的中项目顶层。

## 当前限制

这个小项目只验证有限域 FNT，不等同于完整复数 FFT 或真实光纤信道模型。它的价值是先把硬件变换核、流水线和验证方法做正确，为后面的色散补偿和可配置系统打基础。
'''
(RES/'small_project_1_report.md').write_text(report,encoding='utf-8')
print('small_project_1_ok','forward_points',N,'inverse_points',N,'max_error',0,'butterfly','pass')




