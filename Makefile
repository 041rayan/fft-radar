# FFT Radar verification harness — one command:  make regression
#
# Targets:
#   make regression   -- full stack: unit + integration + lint + synth
#   make sim          -- iverilog simulation of all stimulus cases
#   make unit         -- butterfly unit self-check (built-in vectors)
#   make check        -- compare sim outputs vs numpy golden reference
#   make lint         -- Verilator lint (synthesizability smoke check)
#   make synth        -- Yosys gate-level synthesis of fft_core
#   make vectors      -- regenerate stim/ test vectors from the Python model
#   make waves        -- open GTKWave on the tone capture
#   make clean

RTL      := $(wildcard rtl/*.v)
CASES    := tone chirp random impulse
STIM     := $(wildcard stim/*.hex)
OUTS     := $(addprefix sim/,$(addsuffix _out.txt,$(CASES)))
PY       := python3
VVP      := sim/work.vvp

.PHONY: all regression sim unit check lint synth vectors waves clean

all: regression

regression: sim check unit lint synth
	@echo "================== REGRESSION COMPLETE =================="

# ------------------------------------------------------------------------- #
# Each case needs its own compile (the CURRENT_CASE define selects the
# stimulus), so the out file is the target: a case re-runs only when it is
# missing or its inputs changed.
sim: $(OUTS)
	@echo ">> simulation done (see sim/*_out.txt)"

sim/%_out.txt: $(RTL) tb/fft_tb.v $(STIM)
	@mkdir -p sim
	@echo ">> simulating $*"
	@rm -f $@
	@iverilog -g2012 -D CURRENT_CASE=\"$*\" -o $(VVP) $(RTL) tb/fft_tb.v
	@vvp $(VVP)

check: sim
	@echo ">> golden reference comparison"
	@fail=0; for c in $(CASES); do \
		$(PY) py/golden/check.py $$c || fail=1; \
	done; \
	if [ $$fail -ne 0 ]; then echo "!!! CHECK FAILED"; exit 1; fi

unit: tb/bfly_unit_tb.v rtl/cplx_mult.v rtl/cplx_butterfly.v
	@echo ">> butterfly unit self-check"
	@mkdir -p sim
	@iverilog -g2012 -o sim/unit.vvp rtl/cplx_mult.v rtl/cplx_butterfly.v tb/bfly_unit_tb.v
	@vvp sim/unit.vvp | tee sim/unit.log | grep -q "UNIT OK" || { echo "!!! UNIT FAILED"; exit 1; }
	@echo ">> UNIT OK"

lint:
	@echo ">> Verilator lint"
	@verilator --lint-only -Wall -Wno-fatal -Wno-DECLFILENAME $(RTL)

synth:
	@echo ">> Yosys gate-level synthesis"
	@mkdir -p synth
	@rm -f synth/synth.log
	@yosys -q -p "read_verilog -sv rtl/*.v; \
		prep -top fft_core; \
		proc; opt; memory; opt; \
		techmap; opt; \
		tee -o synth/synth.log stat -top fft_core"
	@sed -n '/^=== design hierarchy ===/,$$p' synth/synth.log
	@echo ">> synthesis OK (see synth/synth.log)"

vectors:
	$(PY) py/golden/gen_vectors.py

waves:
	gtkwave sim/tone_wave.vcd &

clean:
	rm -rf sim/*.vvp sim/*.log sim/*_out.txt sim/*_wave.vcd synth/*
