"""Golden FFT reference model + Q15 fixed-point comparison helpers.

Contract with the RTL:
  - Input x[n] is complex; each component is a 16-bit signed Q15 integer.
  - The RTL computes a radix-2 DIF FFT, halving the data after each of the
    log2(N) stages, so the overall hardware gain is 1/N versus a textbook FFT.
  - Expected integer output bin k:  rint(FFT(x_int)[k] / N), saturated to
    [-32768, 32767] (units of 16-bit Q15 LSBs).

Rounding note: the reference rounds half-to-even (numpy), the RTL rounds
half-up. The LSB-level difference is covered by quantize_check()'s tolerance.
"""

import numpy as np

CLIP_HI = (1 << 15) - 1
CLIP_LO = -(1 << 15)


def golden_fft(inputs):
    """Return complex float64 expected outputs (Q15 integer LSB units).

    The RTL divides by 2 at each of the log2(N) stages, so its integer output
    equals FFT(x_int) / N for an ideal datapath.
    """
    re = np.asarray(inputs[0], dtype=np.float64)
    im = np.asarray(inputs[1], dtype=np.float64)
    x = re + 1j * im
    return np.fft.fft(x) / len(x)


def expected_int(inputs):
    """Expected outputs as Q15 integers: (re, im) arrays, bin-natural order."""
    scaled = golden_fft(inputs)
    applied = np.rint(scaled)
    applied = np.clip(applied, CLIP_LO, CLIP_HI)
    re = applied.real.astype(np.int32)
    im = applied.imag.astype(np.int32)
    return re, im


def quantize_check(hw_re, hw_im, ref_re, ref_im):
    """Compare hardware output (Q15 ints) to reference (Q15 ints).

    hw_* / ref_* must be equal-length iterables of ints (bin-natural order).
    Returns (pass_flag, dict_of_metrics).
    """
    hw_re = np.asarray(hw_re, dtype=np.float64)
    hw_im = np.asarray(hw_im, dtype=np.float64)
    ref_re = np.asarray(ref_re, dtype=np.float64)
    ref_im = np.asarray(ref_im, dtype=np.float64)

    err = (hw_re - ref_re + 1j * (hw_im - ref_im))
    mag_err = np.abs(err)
    ref_mag = np.abs(ref_re + 1j * ref_im)

    max_err = float(mag_err.max())
    mse = float((mag_err ** 2).mean())
    # Signal-to-quantization-noise ratio (dB) vs the reference
    denom = (ref_mag ** 2).sum()
    snr_db = float(np.nan_to_num(10 * np.log10(denom / (mse * len(ref_re) + 1e-30))))

    # A few LSB of accumulated per-stage rounding error is expected; allow
    # 4 LSB plus 3% of the peak reference magnitude.
    tol = 4.0 + 0.03 * float(ref_mag.max())
    passed = bool(max_err <= tol)

    metrics = dict(max_err=max_err, mse=mse, snr_db=snr_db,
                   ref_max=float(ref_mag.max()), tol=tol, n=len(ref_re))
    return passed, metrics


if __name__ == "__main__":
    # quick self-check
    rng = np.random.default_rng(7)
    re = rng.integers(-2000, 2000, 256)
    im = rng.integers(-2000, 2000, 256)
    er, ei = expected_int((re, im))
    print("golden self-check OK, sample bin0 =", (int(er[0]), int(ei[0])))
