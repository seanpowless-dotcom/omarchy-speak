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
- **Streaming** — both engines start speaking before synthesis finishes

## Requirements

- Wayland with `wl-clipboard` (`wl-paste`)
- An audio player: `aplay` (piper streaming) and/or `paplay`
- At least one TTS engine: [piper](https://github.com/OHF-Voice/piper1-gpl),
  [kokoro](https://huggingface.co/hexgrad/Kokoro-82M)

Installing piper and a voice:

```bash
uv tool install piper-tts
uv tool run --from piper-tts python -m piper.download_voices \
  en_US-lessac-medium --download-dir ~/.local/share/piper/voices
```

Then point `engines.piper.model` at the `.onnx` file, and set the `-r` value in
`engines.piper.play` to the voice's sample rate (read it from the sidecar
`.onnx.json` under `audio.sample_rate`). `config.example.json` is a working
piper setup you can copy.

Installing kokoro (ONNX build — CPU only, no torch):

```bash
uv venv --python 3.12 ~/.local/share/omarchy-speak/venv
uv pip install --python ~/.local/share/omarchy-speak/venv/bin/python \
  kokoro-onnx soundfile

M=~/.local/share/omarchy-speak/models; mkdir -p "$M"
BASE=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
curl -L -o "$M/kokoro-v1.0.onnx" "$BASE/kokoro-v1.0.onnx"   # 311 MB
curl -L -o "$M/voices-v1.0.bin"  "$BASE/voices-v1.0.bin"    # 27 MB

install -Dm755 bin/omarchy-speak-kokoro ~/.local/bin/omarchy-speak-kokoro
```

`bin/omarchy-speak-kokoro` wraps the library in a piper-shaped CLI, so both
engines are configured the same way. Its shebang must point at the venv python
above. `--list-voices` prints the 50-odd available voices.

Kokoro synthesises faster than realtime on a modern CPU once loaded, but pays a
fixed ~2s to load the 311MB model on each invocation. Streaming hides most of
this on longer passages — audio starts at the first sentence — but short phrases
will always feel slower to start than piper. That is the trade you are making.

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

Keys were checked against `omarchy menu keybindings --print` before choosing;
`SUPER+SHIFT+S` and the `SUPER+CTRL+R` family are Omarchy defaults, so the
whole feature lives on `R` with modifiers.
| `SUPER + SHIFT + ALT + R` | Save selection to audio |

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
