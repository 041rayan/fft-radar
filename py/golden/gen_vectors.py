"""Generate test vectors (stimulus + expected output) as hex files for iverilog.

Each case produces two files under stim/:
  <name>_in.hex   :  512 lines, 16-bit Q15 re/im interleaved (input order)
  <name>_exp.hex  :  512 lines, 16-bit Q15 re/im interleaved (bin-natural order)

Also writes <name>_meta.json with the golden dominant bin (est_peak) and the
nominal bin the stimulus aims at (aim_bin, debug only).
"""

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from golden.fft_ref import expected_int                    # noqa: E402
from radar.signals import cw_tone, chirp, random_signal, FULL_SCALE  # noqa: E402

STIM = os.path.join(os.path.dirname(__file__), "..", "..", "stim")
N = 256


def write_hex(path, re, im):
    with open(path, "w") as f:
        for r, i in zip(re, im):
            f.write("%04X\n%04X\n" % (int(r) & 0xFFFF, int(i) & 0xFFFF))


def make_case(name, gen_fn, aim_bin=None):
    re, im = gen_fn()
    er, ei = expected_int((re, im))
    write_hex(os.path.join(STIM, name + "_in.hex"), re, im)
    write_hex(os.path.join(STIM, name + "_exp.hex"), er, ei)

    # The golden FFT's dominant bin is the ground truth the HW must reproduce;
    # aim_bin is the nominal bin the stimulus targets (debug only).
    est_peak = int(np.argmax(np.abs(er + 1j * ei)))
    meta = {"aim_bin": aim_bin, "est_peak": est_peak}
    with open(os.path.join(STIM, name + "_meta.json"), "w") as f:
        json.dump(meta, f)
    aim_txt = f" (aim={aim_bin})" if aim_bin is not None else ""
    print(f"case {name:10s} est_peak={est_peak:3d}{aim_txt}")


def impulse():
    re = [0] * N
    im = [0] * N
    re[0] = FULL_SCALE - 1
    return np.asarray(re, np.int32), np.asarray(im, np.int32)


def main():
    os.makedirs(STIM, exist_ok=True)
    make_case("random",  lambda: random_signal(seed=11))
    make_case("tone",    lambda: cw_tone(bin_k=61),           aim_bin=61)
    make_case("chirp",   lambda: chirp(f0=83, chirp_len=192), aim_bin=83)
    make_case("impulse", lambda: impulse(),                   aim_bin=0)
    print("vectors written to", STIM)


if __name__ == "__main__":
    main()
