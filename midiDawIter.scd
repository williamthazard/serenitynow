( //<~~~ first chunk
//Boot the SuperCollider server
o = Server.default.options;
o.memSize_(2.pow(20));
o.outDevice_("BlackHole 16ch");
o.numOutputBusChannels_(16);
o.numInputBusChannels_(0);
s.reboot;

//create our effects buses
SynthDef(\source, {
	var sig;
	sig = In.ar(\in.kr(0),2);
	sig = sig*\amp.kr(1);
	Out.ar(\out.kr(0),sig);
}).add;
~setup = {
	s.newBusAllocators;
	~fxBuses = Array.fill(4, {0});
	~verBuses = Array.fill(4, {0});
	~srcs = Array.fill(4, {0});
	4.do({
		arg i;
		~fxBuses[i] = Bus.audio(s,2);
		~verBuses[i] = Bus.audio(s,2);
	});
	s.bind({
		~sourceGrp = Group.new;
		4.do({
			arg i;
			~srcs[i] = Synth(\source, [\in, i*2, \out, ~fxBuses[i]], ~sourceGrp);
		});
		~fxGrp = Group.after(~sourceGrp);
		~verbGrp = Group.after(~fxGrp);
	});
};
ServerTree.removeAll;
ServerTree.add(~setup);
)

//hit cmd+period after executing the above and before executing the next bit

( //<~~~ second chunk
//set tempo
~timer = LinkClock.new(1).latency_(Server.default.latency).quantum_(0);

//some useful arrays
~sound = Array.fill(4, {0});
~voices = [\1, \2, \3, \4, \5, \6, \7, \8];
~voiceManager = Array.fill(4, {PatternProxy(Pseq(~voices, inf)).asStream});
~durs = Array.fill(4, {0});
~notes = Array.fill(4, {0});
~panLFOs = Array.fill(64, {0});
~cutoffLFOs = Array.fill(64, {0});
~resonanceLFOs = Array.fill(64, {0});
~indexLFOs = Array.fill(64, {0});
~decayLFOs = Array.fill(64, {0});
~absorbLFOs = Array.fill(64, {0});
~modulationLFOs = Array.fill(64, {0});
~modrateLFOs = Array.fill(64, {0});
~decayLFOs = Array.fill(64, {0});
~delayLFOs = Array.fill(64, {0});

//modulators
64.do({
	arg i;
	~panLFOs.put(i,
		Ndef(i.asSymbol, {
			LFTri.kr(~timer.beatDur/rrand(2,16)).range(-1,1)
		})
	)
});
64.do({
	arg i;
	~cutoffLFOs.put(i,
		Ndef((i+64).asSymbol, {
			LFTri.kr(~timer.beatDur/rrand(2,512)).range(500,15000)
		})
	)
});
64.do({
	arg i;
	~resonanceLFOs.put(i,
		Ndef((i+128).asSymbol, {
			LFTri.kr(~timer.beatDur/rrand(2,512)).range(0,2)
		})
	)
});
64.do({
	arg i;
	~indexLFOs.put(i,
		Ndef((i+192).asSymbol, {
			LFTri.kr(~timer.beatDur/rrand(2,512)).range(-3,3)
		})
	)
});
)

( //<~~~ third chunk
//create our effects
SynthDef(\del, {
	var sig, del, filter, deftime, defdec;
	sig = In.ar(\in.kr(0),2);
	deftime = ~timer.beatDur*4;
	defdec = ~timer.beatDur*16;
	del = 2.collect({
		CombC.ar(
			sig,
			~timer.beatDur*128,
			\delay_time.kr(deftime, 0.5),
			\decay_time.kr(defdec)
		)
	}).sum;
	filter = MoogFF.ar(
		in: del,
		freq: \cutoff.kr(12000),
		gain: \resonance.kr(1)
	);
	sig = sig.blend(filter, \mix.kr(0.4));
	sig = Balance2.ar(sig[0],sig[1], \pan.kr(rrand(-1.0,1.0)), \amp.kr(1));
	Out.ar(\out.kr(0),sig);
}).add;

SynthDef(\verb, {

      //ErbeVerb emulation
      arg in, out;
      var input = In.ar(in, 1);
      var decay = \decay.kr(0.1);
      var absorb = 100 * (200 ** \absorb.kr(0.1));
      var modulation = \modulation.kr(0.01);
      var loop = LocalIn.ar(4);
      var allpassTime = [0.015, 0.007, 0.011, 0.002];
      var delayTime = \delay.kr(0.3) + [0, 0.002, 0.003, 0.005];
      var modulator = SinOsc.kr(\modrate.kr(0.05), [0, 0.5, 0.75, 1], mul:modulation);

      2.do({ arg i;
        loop[i] = loop[i] + input;
      });
      4.do({ arg i;
        var snd = loop[i];
        snd = SVF.ar(snd, absorb, 0.1, 1);
        snd = AllpassC.ar(snd, 0.015, modulator[i].madd(allpassTime[i], allpassTime[i]), 0.015);
        loop[i] = DelayC.ar(snd, 3, modulator[i].madd(delayTime[i], delayTime[i]));
      });

      ReplaceOut.ar(out, [loop[0] + loop[3], loop[1] + loop[2]]);
      loop = [loop[0] - loop[1], loop[0] + loop[1], loop[2] - loop[3], loop[2] + loop[3]];
      loop = [loop[0] - loop[2], loop[0] + loop[2], loop[1] - loop[3], loop[1] + loop[3]];
      LocalOut.ar(loop * decay);
}).add;
)

( //<~~~ fourth chunk
//add the efffects we created
~dels = Array.fill(4, {0});
4.do({
	arg i;
	~dels[i] = Synth(
		\del,
		[
			\in, ~fxBuses[i],
			\delay_time, ~timer.beatDur*[2,4,8,16,32,64,128].wchoose(
				[0.4,0.2,0.1,0.1,0.1,0.05,0.05]
			),
			\decay_time, ~timer.beatDur*[2,4,8,16,32,64,128,256].wchoose(
				[0.025,0.025,0.05,0.1,0.1,0.1,0.2,0.4]
			),
			\decay_time,
			\cutoff, ~cutoffLFOs[(i+1)*9],
			\resonance, ~resonanceLFOs[(i+1)*9],
			\pan, ~panLFOs[(i+1)*9],
			\out, ~verBuses[i],
			\mix, 0.4
		],
		~fxGrp
	);
});
~verbs = Array.fill(4, {0});
4.do({
	arg i;
	~verbs[i] = Synth(
		\verb,
		[
			\in, ~verBuses[i],
			\decay, 0.2-((i+1)/20),
			\absorb, 0.5-(i/10),
			\modulation, 0.01,
			\delay, 2-(i/2),
			\modrate, 0.05-(i/100),
			\out, i*2
		],
		~verbGrp
	);
});

//Connect our MIDI devices
MIDIClient.init;
MIDIClient.destinations;
MIDIIn.connectAll;
m = MIDIOut.new(0);
m.latency_(0.2);

//load samples
d = Dictionary.new;
d.add(\za ->
	PathName(
		thisProcess.nowExecutingPath.dirname++"/samples/zall/"
	).entries.collect(
		{
			arg sf;
			Buffer.read(
				s,
				sf.fullPath
			);
		}
	);
);

//create our synths and put them somewhere we can access
~synths = [SinSin.new,TriSin.new,Ringer.new,OneShot.new];
4.do({
	arg i;
	~sound.put(i, ~synths[i])
});
~sound;

//define what our midi messages will do
MIDIdef.noteOn(\notes, {
	arg vel, nn, chan, src, voice;
	[chan, nn, vel].postln;
	voice = ~voiceManager[chan].next;
	if(
		~sound[chan].asString.contains("OneShot"),
		{
			~sound[chan].trigger(voice,nn.linlin(0,127,0,d[\za].size).round)
		},
		{
			~sound[chan].trigger(voice,nn.midicps)
		}
	)
});

//some rhythmic ideas to choose from
~durTables = [
	[0.5,1,1.5,1,0.5,0.5,1,2],
	[0.5,0.5,1,2],
	[0.5,1,1.5,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,2,2],
	[1,1,1,1,1,1,1,1,1,1,1,1,4],
	[1,2,1,2,1,2,1,1,1,1,1,1,1],
	[1,2,1,2,1,2,1,2,2,2],
	[1,1,1,6,1,1,1,2,2],
	[1,1,1,6,1,1,1,4],
	[1,7.5,7.5],
	[1.25,1.25,2.25,2.25,1,1,1,1,0.75,0.75,0.75,0.75,0.5,0.5,0.5,0.5],
	[1.5,1.5,6,1.5,1.5,2,2],
	[2,2,0.5,0.5,1,1,0.5,0.5],
	[2.25,2.25,2.25,2.25,2,2,1.5,1.5],
	[2.5,2.5,1,1,0.25,0.25,0.25,0.25],
	[2.5,2.5,2,1],
	[3,3,3,3,2,2],
	[3,3,3,3,4],
	[3,6,3,2,2],
	[3,6,3,4],
	[3,3,6,4],
	[3,3,4,6],
	[3.5,3.5,3.5,3.5,0.5,0.5,0.5,0.5],
	[3.5,3.5,0.5,0.5,2,3,1.5,1.5],
	[3.5,3.5,7,2],
	[4,2,1,1],
	[4.5,4.5,4,3],
	[5.5,5.5,2,3],
	[5.5,5.5,0.5,0.5,0.5,0.5,1.5,1.5],
	[6,2,2,6],
	[7.5,7.5,1],
	[0.25],
	[0.5],
	[0.5,7.5],
	[1],
	[1,1,2],
	[2],
	[2,2,4],
	[4],
	[4,4,8],
	[8],
	[8,8,16],
	[16],
	[32],
	[32,16,16],
	[64],
	[64,32,32],
	[128],
	[256],
	[512]
];
~weights = Array.fill(
	~durTables.size,
	{linrand(0.01,0.02)}
).normalizeSum.sort.reverse.postln;

//update sequences
4.do({
	arg i;
	Tdef((i+4).asSymbol, {
		loop {
			~notes[i] = [32,37,39,44,49,51,56,61,63,66,68,73,75,80,85,87].scramble;
			~durs.put(
				i,
				PatternProxy(
					Pseq(
						~durTables.wchoose(
							~weights
			).scramble,inf)).asStream);
			("sequence " ++ i ++ " updated").postln;
			[16,32,64,128,256].wchoose([0.6,0.2,0.1,0.05,0.05]).wait
		}
	}).play(~timer, quant: 4)
});

//sequence delays
4.do({
	arg i;
	Tdef((i+8).asSymbol, {
		loop {
			~dels[i].set(\delay_time,
				~timer.beatDur*[2,4,8,16,32,64,128].wchoose(
				[0.4,0.2,0.1,0.1,0.1,0.05,0.05]
			));
			("delay " ++ i ++ " updated").postln;
			[0.25,0.5,1,2,4,8,16,32,64,128,256].wchoose(
				[0.15,0.15,0.15,0.15,0.1,0.1,0.1,0.025,0.025,0.025,0.025].reverse
			).wait
		}
	}).play(~timer, quant: 4)
});


//update synth params
4.do({
	arg i;
	if(
		~sound[i].asString.contains("Ringer"),
		{
			8.do({
				arg j;
				var x = (j+1).asSymbol, t = ~timer.beatDur;
				~sound[i].setParam(x,\amp, rrand(0.15,0.3));
				~sound[i].setParam(x,\index,rrand(0.5,2));
				~sound[i].setParam(x,\reverb_amount,0)
			})
		}
	);
	if(
		~sound[i].asString.contains("SinSin"),
		{
			8.do({
				arg j;
				var x = (j+1).asSymbol, t = ~timer.beatDur;
				~sound[i].setParam(x,\attack,[0,0.1,0.3,0.5,1,t].choose);
				~sound[i].setParam(x,\release,[0.5,1,t].choose);
				~sound[i].setParam(x,\amp,rrand(0.15,0.35));
				~sound[i].setParam(x,\modnum,1);
				~sound[i].setParam(x,\modeno,[1,2].choose);
				~sound[i].setParam(x,\cutoff_env,[0,1].choose);
				~sound[i].setParam(x,\cutoff,~cutoffLFOs[(i+1)*j]);
				~sound[i].setParam(x,\resonance,~resonanceLFOs[(i+1)*j]);
				~sound[i].setParam(x,\index,~indexLFOs[(i+1)*j]);
				~sound[i].setParam(x,\reverb_amount,0)
			});
		}
	);
	if(
		~sound[i].asString.contains("TriSin"),
		{
			8.do({
				arg j;
				var x = (j+1).asSymbol, t = ~timer.beatDur;
				~sound[i].setParam(x,\attack,[0,0.1,0.3,0.5,1,t].choose);
				~sound[i].setParam(x,\release,[0.5,1,t].choose);
				~sound[i].setParam(x,\amp,rrand(0.15,0.35));
				~sound[i].setParam(x,\modnum,1);
				~sound[i].setParam(x,\modeno,[1,2].choose);
				~sound[i].setParam(x,\cutoff_env,[0,1].choose);
				~sound[i].setParam(x,\cutoff,~cutoffLFOs[(i+1)*j]);
				~sound[i].setParam(x,\resonance,~resonanceLFOs[(i+1)*j]);
				~sound[i].setParam(x,\index,~indexLFOs[(i+1)*j]);
				~sound[i].setParam(x,\reverb_amount,0)
			});
		}
	);
	if(
		~sound[i].asString.contains("OneShot"),
		{
			8.do({
				arg j;
				var x = (j+1).asSymbol;
				~sound[i].setParam(x,\amp,rrand(0.15,0.35));
				~sound[i].setParam(x,\cutoff,~cutoffLFOs[(i+1)*j]);
				~sound[i].setParam(x,\resonance,~resonanceLFOs[(i+1)*j]);
				~sound[i].setParam(x,\reverb_amount,0)
			})
		}
	);
	8.do({
		arg j;
		var x = (j+1).asSymbol;
		~sound[i].setParam(x,\pan,~panLFOs[(i+1)*j]);
		~sound[i].setParam('all',\bus,i*2);
	});
});

//play
~times = [4,8,16,32,64,128,256,512];
4.do({
	arg i;
	Tdef(i.asSymbol, {
		loop {
			~notes[i].do{
				arg nn;
				m.noteOn(i,nn,rrand(90,96));
				~durs[i].next.wait;
				m.noteOff(i,nn);
				~durs[i].next.wait;
			}
		}
	}).play(~timer,
		quant: ~times[i+[1,2,3,4].wchoose(
			[0.4,0.3,0.2,0.1]
		)]
	);
});
)

//stop
(
12.do({
	arg i;
	Tdef(i.asSymbol).stop;
});
)

//midi panic
(
128.do({
	arg nn;
	8.do({
		arg i;
		m.noteOff(i,nn)
	})
})
)