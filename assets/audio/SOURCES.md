# Audio provenance

Everything in `sfx/` except `engine_sample.wav` is synthesized by
`tools/gen_sfx.py` (ours, no license concerns). External assets, all
CC0 (public domain, no attribution required — credited anyway):

| File | Source | Author | License |
|---|---|---|---|
| music/chill_loop.ogg | [Chill lofi inspired [loop edit]](https://opengameart.org/content/chill-lofi-inspired-loop-edit) (chilllofir-loop.ogg) | omfgdude, loop edit by qubodup | CC0 |
| sfx/engine_sample.wav | [racing car engine sound loops](https://opengameart.org/content/racing-car-engine-sound-loops) (loop_0.wav) | domasx2 | CC0 |

`engine_sample.wav` is the A/B candidate against the synth engine —
toggle `use_sampled_engine` on the Car's CarAudio node, keep the
winner, delete the loser (and this row if the sample loses).
