# omarchy-speak

System-wide text-to-speech for [Omarchy](https://omarchy.org), driven by Hyprland keybinds.

Highlight text anywhere — browser, terminal, PDF viewer, editor — and press a key to
hear it. Two engines: **piper** for instant playback, **kokoro** when the voice matters
more than the latency.

No browser extension. On Wayland the *primary selection* is system-wide, so one keybind
covers every application at once.

## Features

- **Speak the selection** — anything highlighted, in any app
- **Speak the clipboard** — for text that isn't selectable
- **Save to file** — render the selection to a wav in a configurable location
- **Interrupt** — a second press stops playback; a new utterance replaces the old one
- **Two engines** — fast by default, high-quality on a modifier

## Requirements

- Wayland with `wl-clipboard` (`wl-paste`)
- An audio player: `aplay` (piper streaming) and/or `paplay`
- At least one TTS engine: [piper](https://github.com/OHF-Voice/piper1-gpl),
  [kokoro](https://huggingface.co/hexgrad/Kokoro-82M)

The daemon itself is Python stdlib only — no pip install, no virtualenv.

## Install

```bash
git clone https://github.com/YOURNAME/omarchy-speak
cd omarchy-speak
./install.sh
systemctl --user enable --now omarchy-speak
```

Then source the keybinds from `~/.config/hypr/hyprland.conf`:

```
source = ~/projects/omarchy-speak/hypr/speak.conf
```

## Keybinds

| Key | Action |
| --- | --- |
| `SUPER + R` | Speak selection (press again to stop) |
| `SUPER + SHIFT + R` | Speak selection with kokoro |
| `SUPER + ALT + R` | Speak clipboard |
| `SUPER + SHIFT + ESC` | Stop |
| `SUPER + SHIFT + S` | Save selection to audio |

## Configuration

`~/.config/omarchy-speak/config.json`, created on first run with `--init-config`.

Engines are defined as **command templates**, so omarchy-speak works with whatever
packaging you used — pip, AUR, a local build — without code changes. `{model}`,
`{voice}` and `{out}` are substituted from the engine's own config block.

```json
{
  "default_engine": "piper",
  "save_dir": "~/Audio/speak",
  "engines": {
    "piper": {
      "mode": "stream",
      "model": "/path/to/en_US-lessac-medium.onnx",
      "speak": ["piper", "--model", "{model}", "--output-raw"],
      "save":  ["piper", "--model", "{model}", "--output_file", "{out}"],
      "play":  ["aplay", "-q", "-r", "22050", "-f", "S16_LE", "-t", "raw", "-"]
    }
  }
}
```

`mode` is either `stream` (engine writes raw audio to stdout, piped straight to the
player — speech starts before synthesis finishes) or `file` (engine renders a wav,
then it plays).

## HTTP API

The daemon listens on `127.0.0.1:8765`. Any client can drive it — the keybinds are
just `curl` in a trenchcoat.

| Method | Path | Body | Purpose |
| --- | --- | --- | --- |
| `GET` | `/status` | | Is it speaking, and with what |
| `GET` | `/engines` | | Configured engines |
| `POST` | `/speak` | `{"text":…, "engine":…}` | Speak literal text |
| `POST` | `/speak/selection` | `{"engine":…}` | Speak the primary selection |
| `POST` | `/speak/clipboard` | `{"engine":…}` | Speak the clipboard |
| `POST` | `/save` | `{"engine":…, "path":…}` | Render to a file |
| `POST` | `/stop` | | Stop playback |
| `POST` | `/toggle` | `{"engine":…}` | Stop if speaking, else speak selection |

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"text":"the daemon is listening"}' \
  http://127.0.0.1:8765/speak
```

Because it's plain HTTP, a status-bar widget or a browser extension can be added later
without touching the daemon.

## Why loopback HTTP and not a native messaging host

Chrome's native messaging only works from the browser. A local HTTP daemon serves the
keybinds, a future widget, and a future extension from one backend, and it's testable
with `curl`. It binds `127.0.0.1` only.

## License

MIT
