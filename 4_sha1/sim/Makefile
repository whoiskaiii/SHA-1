TB	=	sha1_core_tb

all:clean elab sim

help:
	@echo "1.make elab to elaborate/compile design"
	@echo "2.make sim to simulate design"
	@echo "3.make verdi to view the waveform"
	@echo "4.make clean to clean up the current folder"

elab:
	vcs \
	-full64 \
	-debug_acc+all \
	-sverilog \
	+v2k \
	-l comp.log \
	-y /home/synopsys/syn/O-2018.06-SP1/dw/dw06/src_ver \
	-y /home/synopsys/syn/O-2018.06-SP1/dw/dw03/src_ver \
	+libext+.v \
	-f ./filelist.f \
	-timescale=1ns/1ps \
	+incdir+../sim

sim:
	./simv \
	-ucli \
	-i ./wave_gen.tcl \
	-l run.log \
	+fsdb+functions 

verdi:
	verdi \
	-y /home/synopsys/syn/O-2018.06-SP1/dw/dw06/src_ver \
	-y /home/synopsys/syn/O-2018.06-SP1/dw/dw03/src_ver \
	+libext+.v \
	-f ./filelist.f \
	-ssf ./$(TB).fsdb \
	-top $(TB) \
	&

clean:
	rm -rf \
	AN.DB DVEfiles csrc simv.* *simv inter.vpd ucli.key *.log novas* *fsdb verdiLog
