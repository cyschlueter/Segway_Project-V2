all: synth clean

synth:
	@design_vision -shell dc_shell -f segway.dc

clean:
	@rm -rf *.pvl *.mr *.syn
