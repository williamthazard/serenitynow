(
Task(
	{
		//Boot the SuperCollider server
		o = Server.default.options;
		o.memSize_(2.pow(20));
		o.outDevice_("BlackHole 16ch");
		o.numOutputBusChannels_(16);
		o.numInputBusChannels_(0);
		s.reboot;
		1.wait;
		"server ready".postln;
		//set tempo
		~timer = LinkClock.new(1).latency_(Server.default.latency).quantum_(0);
		1.wait;
		"clock ready".postln;
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
		1.wait;
		"modulators ready".postln;
		//Connect our MIDI devices
		MIDIClient.init;
		MIDIIn.connectAll;
		m = MIDIOut.new(0);
		m.latency_(0.2);
		1.wait;
		"midi initialized".postln;
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
		1.wait;
		"samples loaded".postln;
		//create our synths and put them somewhere we can access
		~sound = [SinSin.new,TriSin.new,Ringer.new,OneShot.new];
		1.wait;
		"synths initialized".postln;
		//define what our midi messages will do
		MIDIdef.noteOn(\notes, {
			arg vel, nn, chan, src, voice;
			[chan, nn, vel].post;
			" ".post;
			voice = ~voiceManager[chan].next;
			if(
				~sound[chan].asString.contains("OneShot"),
				{
					~sound[chan].trigger(
						voice,
						nn.linlin(0,127,0,d[\za].size).round
					);
					(~sound[chan]).post;
					" triggered".postln;
				},
				{
					~sound[chan].trigger(
						voice,
						nn.midicps
					);
					(~sound[chan]).post;
					" triggered".postln
				}
			)
		});
		1.wait;
		"midi noteOn events defined".postln;
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
		).normalizeSum.sort.reverse;
		//1.wait;
		"rhythmic ideas established".postln;
		//update sequences
		4.do({
			arg i;
			Tdef((i+4).asSymbol, {
				loop {
					~notes[i] = [
						32,37,39,44,49,51,56,61,63,66,68,73,75,80,85,87
					].scramble;
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
		1.wait;
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
		"synth params set".postln;
		1.wait;
		"ready to play!".postln;
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
	}
).play(~timer, quant: 4)
)

//stop
(
8.do({
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
