declare name "Tone Matrix";
declare author "Nicole Alassandro";

import("filter.lib");
import("oscillator.lib");

MATRIX_SIZE = 8; // Matrix size in columns
SCALE_NUM   = 4;
selectN(index, size, values) = values : par(i, size, *(index==i)) :> _;

// User Interface
// ===================================
trig(row) = selectN(row, 5, (
	        	selectN(osc_step, MATRIX_SIZE, (par(i, MATRIX_SIZE, checkbox("v:[1]/h:[1]/[%i]&")))),
		 		selectN(osc_step, MATRIX_SIZE, (par(i, MATRIX_SIZE, checkbox("v:[2]/h:[2]/[%i]&")))),
		 		selectN(osc_step, MATRIX_SIZE, (par(i, MATRIX_SIZE, checkbox("v:[3]/h:[3]/[%i]&")))),
		 		selectN(osc_step, MATRIX_SIZE, (par(i, MATRIX_SIZE, checkbox("v:[4]/h:[4]/[%i]&")))),
		 		selectN(osc_step, MATRIX_SIZE, (par(i, MATRIX_SIZE, checkbox("v:[5]/h:[5]/[%i]&"))))
	           )
	        );

// "Oscillator" Tab
osc_rate = tgroup("[6]", hslider("v:[1]Oscillator/h:[1]/[1]Rate[style:knob]", 5, 0.1, 10, 0.1));
osc_freq = tgroup("[6]", nentry("v:[1]Oscillator/h:[1]/[2]Frequency[unit:Hz]", 440, 0, 20000, 1));
osc_type = tgroup("[6]", nentry("v:[1]Oscillator/h:[1]/[3]Tone", 1, 1, 3, 1) - 1);
osc_scal = tgroup("[6]", nentry("v:[1]Oscillator/h:[1]/[4]Scale", 1, 1, SCALE_NUM, 1) - 1);
osc_cut  = tgroup("[6]", hslider("v:[1]Oscillator/h:[2]/[1]Cutoff[style:knob]", 100, 1, 100, 1) * 200);
osc_amp  = tgroup("[6]", hslider("v:[1]Oscillator/h:[2]/[2]Volume[style:knob][unit:%]", 100, 0, 100, 1) / 100);
osc_pan  = tgroup("[6]", hslider("v:[1]Oscillator/h:[2]/[3]Pan[style:knob]", 50, 0, 100, 1) / 100);

// "Effects" Tab
echo_togl = tgroup("[6]", checkbox("v:[2]Effects/h:[2]Echo/[1]Enable"));
echo_time = tgroup("[6]", hslider("v:[2]Effects/h:[2]Echo/[2]Delay[style:knob][unit:s]", 0.25, 0.10, 1, 0.01) / (1/SR));
echo_feed = tgroup("[6]", hslider("v:[2]Effects/h:[2]Echo/[3]Feedback[style:knob][unit:%]", 50, 0, 100, 1) / 100);
echo_amp  = tgroup("[6]", hslider("v:[2]Effects/h:[2]Echo/[4]Volume[style:knob][unit:%]", 50, 0, 100, 1) / 100);

flan_togl = tgroup("[6]", checkbox("v:[2]Effects/h:[3]Flanger/[1]Enable"));
flan_rate = tgroup("[6]", hslider("v:[2]Effects/h:[3]Flanger/[2]Rate[style:knob][unit:Hz]", 0.50, 0, 3, 0.01));
flan_dep  = tgroup("[6]", hslider("v:[2]Effects/h:[3]Flanger/[3]Depth[style:knob][unit:%]", 100, 0, 100, 1));
flan_mix  = tgroup("[6]", hslider("v:[2]Effects/h:[3]Flanger/[4]Mix[style:knob][unit:%]", 100, 0, 100, 1) / 100);

trem_togl = tgroup("[6]", checkbox("v:[2]Effects/h:[4]Tremolo/[1]Enable"));
trem_rate = tgroup("[6]", hslider("v:[2]Effects/h:[4]Tremolo/[2]Rate[style:knob][unit:Hz]", 1.0, 0, 5, 0.10));
trem_dep  = tgroup("[6]", hslider("v:[2]Effects/h:[4]Tremolo/[3]Depth[style:knob][unit:%]", 100, 0, 100, 1) / 100);



// Signal Generators
// ===================================
osc_mas(step, id) = select3(osc_type,
	      	        	osc((2^(1/12)^step) * osc_freq) * trig(id),		         // osc_type 1 = sine
						triangle((2^(1/12)^step) * osc_freq) * trig(id) : *(2),	 // osc_type 2 = triangle
						sawtooth((2^(1/12)^step) * osc_freq) * trig(id)	: *(0.5) // osc_type 3 = sawtooth
		    	    );

osc_1 = osc_mas(selectN(osc_scal, SCALE_NUM, (9, 10, 8, 4)), 0);
osc_2 = osc_mas(selectN(osc_scal, SCALE_NUM, (7,  7, 6, 3)), 1);
osc_3 = osc_mas(selectN(osc_scal, SCALE_NUM, (4,  5, 4, 2)), 2);
osc_4 = osc_mas(selectN(osc_scal, SCALE_NUM, (2,  3, 2, 1)), 3);
osc_5 = osc_mas(selectN(osc_scal, SCALE_NUM, (0,  0, 0, 0)), 4);

osc_step = lf_sawpos(((1/MATRIX_SIZE)) * osc_rate) : *(MATRIX_SIZE) : int;

osc_out = osc_1, osc_2, osc_3, osc_4, osc_5 :> *(osc_amp);


// Signal Modulators
// ===================================

// Cutoff
cutoff = lowpass(16, osc_cut);

// Echo
echo = select2(echo_togl, _, +(fdelay(1<<16, echo_time)) ~ (fdelay(1<<16, echo_time) * echo_feed));

// Flanging
flan_lfo = osc(flan_rate);
flanger = select2(flan_togl, _, +(fdelay(1<<16, abs(flan_lfo * flan_dep)) * flan_mix));

// Tremolo
trem_lfo = abs(osc(trem_rate) * trem_dep);
tremolo = select2(trem_togl, _, *(trem_lfo + (1 - trem_dep)));



// Signal Flow
// ===================================
process = osc_out <:
	  	  cutoff <:
	      tremolo <:
	  	  flanger <:
	  	  _, (echo * echo_amp) :>
	  	  _ <: *(1 - osc_pan), *(osc_pan);
