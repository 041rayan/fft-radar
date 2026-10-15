"""Compare iverilog HW output against the golden numpy reference & radar assertions.

Usage:
    python3 py/golden/check.py <case>

Reads sim/<case>_out.txt (HW) and stim/<case>_exp.hex (golden). Reports pass/fail.
"""

import json
import os
import sys

import numpy as np

BASE = os.path.join(os.path.dirname(__file__), "..", "..")
sys.path.insert(0, os.path.dirname(__file__))
from fft_ref import quantize_check  # noqa: E402


def read_out(path):
    re, im = [], []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            r, i = line.split()
            re.append(int(r))
            im.append(int(i))
    return np.asarray(re, dtype=np.int32), np.asarray(im, dtype=np.int32)


def load_expected_hex(path):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                vals.append(int(line, 16))
    re = np.asarray(vals[0::2], dtype=np.int32)
    im = np.asarray(vals[1::2], dtype=np.int32)
    # signed 16-bit reinterpret
    re = np.where(re >= 0x8000, re - 0x10000, re)
    im = np.where(im >= 0x8000, im - 0x10000, im)
    return re, im


def main():
    if len(sys.argv) != 2:
        print("usage: python3 py/golden/check.py <case>")
        return 2
    case = sys.argv[1]

    sim = os.path.join(BASE, "sim", case + "_out.txt")
    exp = os.path.join(BASE, "stim", case + "_exp.hex")
    if not os.path.exists(sim):
        print(f"[{case}] missing {os.path.relpath(sim)} — run 'make sim' first")
        return 1

    hw_re, hw_im = read_out(sim)
    ref_re, ref_im = load_expected_hex(exp)
    assert len(hw_re) == len(ref_re) == 256, \
        f"expected 256 output bins, got hw={len(hw_re)} golden={len(ref_re)}"

    passed, metrics = quantize_check(hw_re, hw_im, ref_re, ref_im)

    # Radar peak assertion (dominant bin of HW == dominant bin of golden FFT)
    meta = {}
    meta_path = os.path.join(BASE, "stim", case + "_meta.json")
    if os.path.exists(meta_path):
        with open(meta_path) as f:
            meta = json.load(f)
    hw_peak = int(np.argmax(np.hypot(hw_re, hw_im)))
    peak_ok = (meta.get("est_peak") is None) or (hw_peak == meta["est_peak"])

    ok = passed and peak_ok
    print(f"[{case}] max_err={metrics['max_err']:.2f} "
          f"tol={metrics['tol']:.2f} snr={metrics['snr_db']:.1f} dB")
    if meta.get("est_peak") is not None:
        aim = meta.get("aim_bin")
        aim_txt = f" aim={aim}" if aim is not None else ""
        print(f"[{case}] peak bin HW={hw_peak} golden={meta['est_peak']}{aim_txt} "
              f"{'OK' if peak_ok else 'MISMATCH'}")
    print(f"[{case}] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
