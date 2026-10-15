# FFT Radar

A 256-point fixed-point FFT core in Verilog, plus the verification harness
that keeps it honest: iverilog simulation, a NumPy golden reference, a
butterfly unit test, Verilator lint, and Yosys synthesis — all behind a
single `make regression`.

The core is the signal-processing front end of a range/Doppler radar chain:
you load complex IF samples, it hands you the frequency bins back.

## Quick start

```sh
make regression
```

Requires `iverilog`, `verilator`, `yosys`, `python3` (with NumPy) and GNU
make. GTKWave is optional and only used by `make waves`.

## The core

- Q15 fixed-point complex I/Q data (16-bit signed per component).
- Radix-2 decimation-in-frequency (DIF) FFT, all stages folded onto a single
  complex butterfly, so the datapath cost is one `cplx_mult` regardless of N.
- Samples load in natural order; bins stream out in natural order.
- The butterfly halves the data every stage, so a full transform has an
  overall gain of 1/N relative to a textbook FFT (outputs stay in Q15).
- 256-point, single clock; one butterfly per cycle.

Interface (`rtl/fft_core.v`):

| Signal | Dir | Description |
|---|---|---|
| `clk`, `rst_n` | in | clock; active-low async reset |
| `load_en`, `din_re`, `din_im` | in | write one complex sample per cycle |
| `fft_start` | in | pulse after N samples are loaded |
| `busy` | out | high from `fft_start` until the last output |
| `fft_done` | out | one-cycle pulse when processing completes |
| `out_valid`, `out_idx`, `dout_re`, `dout_im` | out | N-cycle output stream, bins 0..N-1 |

Protocol: reset, load N samples (natural order), pulse `fft_start`, wait for
`fft_done`, then capture N cycles of `out_valid` starting the following cycle.
Latency from `fft_start` is N/2·log2(N) + N + 1 cycles (~1281 at N=256).

## Repository layout

```
rtl/            FFT core: butterfly, complex multiplier, twiddle ROM, RAM, top
tb/             iverilog testbenches (full FFT + butterfly unit test)
py/golden/      NumPy golden model, checker, hex vector generator
py/radar/       radar-style stimulus generators (tone, chirp, random)
stim/           generated test vectors (hex in/expected + meta JSON, committed)
sim/            simulation outputs (generated, git-ignored)
synth/          synthesis output (generated, git-ignored)
```

The twiddle table in `rtl/twiddle_rom.v` is generated for N=256; supporting a
different N means regenerating that table.

## Make targets

| Target | What it does |
|---|---|
| `make regression` | sim + golden check + unit test + lint + synthesis |
| `make sim` | run every stimulus case through iverilog |
| `make check` | compare `sim/*_out.txt` against the golden model |
| `make unit` | butterfly unit test against fixed vectors |
| `make lint` | Verilator lint (kept warning-clean) |
| `make synth` | Yosys gate-level synthesis of `fft_core` |
| `make vectors` | regenerate `stim/` from the Python model |
| `make waves` | open the tone capture in GTKWave |
| `make clean` | remove generated sim/synth outputs |

## How verification works

For each case (`tone`, `chirp`, `random`, `impulse`):

1. `py/radar/signals.py` builds the stimulus; `py/golden/fft_ref.py` computes
   expected outputs with a NumPy FFT scaled by 1/N, then rounds and saturates
   to Q15 integers.
2. Hex vectors drive the RTL through `tb/fft_tb.v` (with a watchdog timeout).
3. `py/golden/check.py` fails the case unless the magnitude error stays under
   a tolerance (4 LSB + 3% of the peak bin) and the dominant output bin
   matches the golden FFT's dominant bin.

The tolerance covers the per-stage rounding the fixed-point datapath
accumulates. The butterfly unit test additionally checks exact equality
against precomputed vectors.

## License

MIT — see [LICENSE](LICENSE).
