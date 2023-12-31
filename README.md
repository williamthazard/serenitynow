# serenitynow
<em>generative ambient on demand</em>
<br>
<br>
to play, first make sure the "samples" folder (and the "za" folder within it) is saved in the same place as the main .scd file and that the documents in the "classes" folder have been saved to your SuperCollider extensions folder (which you can locate by navigating to file > user support directory from within SuperCollider's IDE). Then use Blackhole 16ch as the input for your DAW or other recording software of choice. You can also sync the tempo of your DAW with this script's output by enabling your DAW to join Ableton Link. When syncing tempo, you may have to adjust for latency. The default server latency for SuperCollider is 2ms, so setting your DAW's latency setting for midi and audio to 2ms is a good place to start.
<br>
<br>
set up your DAW to receive audio on channels 1 through 8. These are four stereo pairs, so if your DAW allows for stereo audio tracks, you can use them that way. You can also set up your DAW with midi tracks for channels 1 through 4. These correspond to stereo pairs 1 & 2, 3 & 4, 5 & 6, and 7 & 8, respectively. Personally, I like to set these up in alternating pairs (i.e., midi channel 1 track, stereo audio track for channels 1 & 2, midi channel 2 track, stereo audio track for channels 3 & 4, etc.), but of course, you should set it up in a way that makes sense to you.
<br>
<br>
once your DAW's all set up, execute the code chunk at the top of the SuperCollider script (starting on line 1, with the parenthesis before "Task"). To stop, execute the code chunk that begins at line 299. You might get some stuck midi notes when you stop; if that happens, execute the "midi panic" code chunk that begins at line 307.
