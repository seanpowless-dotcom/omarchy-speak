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

    󰖀 af_sarah          idle
    󰖀 af_sarah ▁        queued behind something
    󰖀 af_sarah █▆       speaking, audio reaching the sink
    󰖀 af_sarah          speaking, and NOTHING reaching the sink

That last one is the reason the level is read from the **output sink** rather
than from the daemon. "The daemon believes it is speaking" and "sound is coming
out" are different claims, and the gap between them is a real failure: a
Bluetooth speaker that is connected but asleep swallows audio silently, so the
daemon reports playback while the room stays quiet. A flat bar against a
`speaking` state is the interesting reading, and the tooltip says so outright.

## Cost

Sampling the sink costs ~150ms, far too much to spend every second forever, so
it is only paid when the daemon says something is playing. An idle tick is a
config read and one loopback request — about 50ms.

## Limitation

The bar runs this on an interval, so at one second it is a coarse activity
readout rather than a smooth meter. A true meter would need a streaming QML
plugin rather than a command module.
