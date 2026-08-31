# Omarchy bar module

A status-bar readout: the configured voice, and a level bar while speaking.

    install -Dm755 omarchy/bar/scripts/speak-status \
        ~/.config/omarchy/bar/scripts/speak-status

Then add it to `bar.layout` in `~/.config/omarchy/shell.json` — it hot-reloads
on save:

```json
{ "id": "speak", "type": "command",
  "exec": "~/.config/omarchy/bar/scripts/speak-status",
  "interval": 1,
  "onClick": "omarchy-launch-terminal omarchy-speak-ui" }
```

## What it shows

    󰖀 af_sarah      idle — the configured voice
    󰖀 af_sarah 3    idle, three clips queued
    󰖀 am_michael    speaking — whoever is actually talking

Idle it shows the configured voice; while speaking it shows the voice actually
sounding. Those are the same today, and routinely different once utterances can
choose a voice per source.

The **output sink is still checked**, but no longer drawn. "The daemon believes
it is speaking" and "sound is coming out" are different claims, and the gap
between them is a real failure: a Bluetooth speaker that is connected but asleep
swallows audio silently while the daemon reports playback. That state sets
`class` to `silent` rather than `speaking`, and the tooltip says outright:

    no audio at the sink — is the output device awake?

## Cost

Sampling the sink costs ~150ms, far too much to spend every second forever, so
it is only paid when the daemon says something is playing. An idle tick is a
config read and one loopback request — about 50ms.

## Limitation

The bar runs this on an interval, so state changes land within a second rather
than instantly. That is fine for a name; it is why the level bar this replaced
was not worth keeping, since four cells sampled once a second is not a meter.
