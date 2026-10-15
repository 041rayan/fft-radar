"""Radar test stimuli for the FFT core.

These mimic the signals a radar range/Doppler FFT encounters after
down-conversion / IF sampling of a point target:

  cw_tone        -- a complex exponential exactly on an FFT bin. Models the
                    Doppler beat of a moving target after stretch/dechirp.
                    Expected: one sharp peak at bin = bin_k.

  chirp          -- a linear-FM (LFM) range chirp, Hamming-windowed over its
                    active samples. Models the compressed IF echo of a point
                    target. Expected: a main band starting at bin f0 and
                    spreading by ~bw*chirp_len bins, with a clear peak.

  random_signal  -- uniform random input, for noise/regression coverage.

All generators return (re, im) int32 arrays of length N (Q15 units).
"""

import numpy as np

N = 256
FULL_SCALE = 1 << 15


def _to_q15(samples):
    """Quantize float samples in [-1,1) to Q15 integer LSBs."""
    v = np.rint(np.clip(samples * FULL_SCALE, -FULL_SCALE, FULL_SCALE - 1))
    return v.astype(np.int32)


def cw_tone(bin_k=61, amp=0.8):
    """Complex tone exactly on-bin: x[n] = amp*exp(j*2*pi*bin_k*n/N)."""
    n = np.arange(N)
    x = amp * np.exp(2j * np.pi * bin_k * n / N)
    return _to_q15(x.real), _to_q15(x.imag)


def chirp(f0=83, chirp_len=192, bw=0.04, amp=0.9, windowed=True):
    """LFM chirp windowed (Hamming) to a point-target-like range echo.

    f0        : start frequency as an FFT bin (0..N-1)
    chirp_len : number of active samples (rest of the frame is zero)
    bw        : chirp bandwidth, normalized sweep per sample
    """
    n = np.arange(N)
    phase = 2 * np.pi * (f0 * n / N) + 2 * np.pi * bw * (n ** 2) / (2 * N)
    x = np.zeros(N, dtype=np.complex128)
    active = np.zeros(N, dtype=bool)
    active[:chirp_len] = True
    win = np.hamming(chirp_len) if windowed else np.ones(chirp_len)
    x[active] = amp * win * np.exp(1j * phase[active])
    return _to_q15(x.real), _to_q15(x.imag)


def random_signal(seed=7, low=-2000, high=2000):
    """Uniform random input with bounded amplitude (quiet, Q15-safe)."""
    rng = np.random.default_rng(seed)
    x = (rng.integers(low, high, N) + 1j * rng.integers(low, high, N)) / FULL_SCALE
    return _to_q15(x.real), _to_q15(x.imag)
