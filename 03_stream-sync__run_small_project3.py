from pathlib import Path
import csv
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
SIM = ROOT / "sim"
SIM.mkdir(exist_ok=True)
iverilog = ROOT.parents[1] / "work" / "iverilog" / "bin" / "iverilog.exe"
vvp = ROOT.parents[1] / "work" / "iverilog" / "bin" / "vvp.exe"

def run_case(name, tb_name):
    out = SIM / f"{name}.out"
    cmd = [str(iverilog), "-g2012", "-s", tb_name, "-o", str(out), str(RTL / "stream_blocks.v"), str(RTL / f"{tb_name}.v")]
    c = subprocess.run(cmd, cwd=SIM, capture_output=True, text=True)
    if c.returncode:
        raise SystemExit(f"{name} compile failed:\n{c.stderr}")
    r = subprocess.run([str(vvp), out.name], cwd=SIM, capture_output=True, text=True)
    log = SIM / f"{name}.log"
    log.write_text(r.stdout + r.stderr, encoding="utf-8")
    if r.returncode or "PASS" not in r.stdout:
        raise SystemExit(f"{name} simulation failed:\n{r.stdout}\n{r.stderr}")
    return r.stdout

run_case("stream_blocks_test", "tb_stream_blocks")
run_case("stream_roundtrip", "tb_stream_blocks_roundtrip")
rows = list(csv.DictReader((SIM / "stream_roundtrip.csv").open(encoding="utf-8")))
if len(rows) != 16 or any(int(r["input"]) != int(r["output"]) for r in rows):
    raise AssertionError("stream roundtrip mismatch")
print("small_project3_ok", "basic_block", "pass", "roundtrip_samples", len(rows), "max_error", 0)
