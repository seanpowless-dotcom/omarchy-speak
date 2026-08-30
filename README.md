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
- **Save to file** — render the selection to a wav, with a file picker or straight
  to a default location
- **Play/pause** — a second press suspends mid-word; a third picks up where it left off
- **A queue** — stack up clips as you find them and they read in turn, with
  forward and back
- **Two engines** — fast by default, high-quality on a modifier
- **GPU** — kokoro runs on CUDA when a usable GPU is present, and falls back to
  the CPU when it isn't
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

Installing kokoro (ONNX build, no torch):

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
engines are configured the same way. `--list-voices` prints the 50-odd
available voices.

The wrapper ships with a portable `#!/usr/bin/env python3` shebang. `install.sh`
retargets it at the venv above when it finds one; if you installed the package
instead, either make `kokoro-onnx` importable from the system python or point
the config at the venv directly:

```json
"speak": ["~/.local/share/omarchy-speak/venv/bin/python",
          "/usr/bin/omarchy-speak-kokoro", "--voice", "{voice}", "--output-raw"]
```

### The warm worker

Loading kokoro's 311MB model costs ~1.9s, and paying it on every utterance is
the difference between kokoro feeling usable and feeling broken. Run a warm
worker that holds the model on a unix socket:

```bash
systemctl --user enable --now omarchy-speak-kokoro
```

The CLI finds the socket and uses it automatically. With no worker running it
loads the model in-process exactly as before, so the worker is an optimisation
and never a requirement — and output is byte-identical either way.

Measured here, on a 2.07s utterance:

| | to first audio | realtime factor |
| --- | --- | --- |
| Without worker | 3.42s | 0.6x |
| With worker | **1.55s** | **1.3x** |

The cost is ~700MB resident: the model plus onnxruntime's arena allocator,
which grows over the first few utterances and then plateaus. The unit sets
`MemoryMax=2G` as a runaway guard.

Interrupting a long passage closes the client socket, which surfaces to the
worker as a broken pipe and abandons that utterance — the model does not
finish synthesising audio nobody will hear, and the next request is served
immediately.

The daemon itself is Python stdlib only — no pip install, no virtualenv.

### On the GPU

kokoro will use CUDA if it can. Swap the CPU runtime for the GPU one in the
same venv:

```bash
uv pip uninstall --python ~/.local/share/omarchy-speak/venv/bin/python onnxruntime
uv pip install --python ~/.local/share/omarchy-speak/venv/bin/python \
  'onnxruntime-gpu[cuda,cudnn]'
systemctl --user restart omarchy-speak-kokoro
```

No system CUDA toolkit is needed — the `[cuda,cudnn]` extras pull the runtime
in as pip packages. The worker prints which provider it settled on:

```
kokoro worker ready on /run/user/1000/omarchy-speak-kokoro.sock [CUDA]
```

Measured here on a Quadro RTX 3000, synthesising 8.1s of speech:

| | synthesis | realtime factor |
| --- | --- | --- |
| CPU | 3.56s | 2.3x |
| CUDA | **0.38s** | **21.5x** |

It costs ~630MB of VRAM, held for as long as the worker runs. On a card that is
also driving your display, that is the trade: `--provider cpu` declines it.

Selection is deliberately forgiving, because a GPU is not a stable fact on a
laptop — an eGPU gets unplugged, a driver gets upgraded out from under a running
system. `auto` (the default) uses CUDA when a session actually builds on it and
CPU when one doesn't, so a missing GPU costs latency rather than the voice.
Note that onnxruntime *advertises* `CUDAExecutionProvider` whenever the GPU
build is installed, even when the CUDA libraries are unreachable — the wrapper
calls `preload_dlls()` and then builds a real session rather than trusting that
list.

## Install

From source, into `~/.local/bin`:

```bash
git clone https://github.com/seanpowless-dotcom/omarchy-speak
cd omarchy-speak
./install.sh
systemctl --user enable --now omarchy-speak
```

Or build the Arch package:

```bash
makepkg -si
systemctl --user enable --now omarchy-speak
cp /usr/share/omarchy-speak/config.example.json ~/.config/omarchy-speak/config.json
```

The units are **user** units, not system ones — the daemon needs your Wayland
session to reach `wl-paste` and the audio server. Both install methods put
`omarchy-speak` on your `PATH` and the units resolve it there, so a packaged
install and a `~/.local/bin` one use the same unit files.

Neither TTS engine is in the Arch repos; both come from PyPI (below). The
daemon starts fine without them and reports which binaries are missing when
asked to speak.

Then add the keybindings. Omarchy configures Hyprland in Lua, so copy the
`o.bind(...)` lines from `hypr/speak.lua` into `~/.config/hypr/bindings.lua`
(a packaged install puts the file at `/usr/share/omarchy-speak/speak.lua`):

```lua
o.bind("SUPER + R", "Speak selection", "omarchy-speak-ctl toggle")
o.bind("SUPER + SHIFT + R", "Speak selection (kokoro)", "omarchy-speak-ctl selection kokoro")
o.bind("SUPER + ALT + R", "Speak clipboard", "omarchy-speak-ctl clipboard")
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save kokoro")
o.bind("SUPER + SHIFT + ESCAPE", "Stop speaking", "omarchy-speak-ctl stop")
```

Then `hyprctl reload`. On plain Hyprland without Omarchy's Lua layer, the
equivalent `bindd =` lines go in `hyprland.conf`:

```
bindd = SUPER, R, Speak selection, exec, omarchy-speak-ctl toggle
```

Check for conflicts before committing to keys — on Omarchy,
`omarchy menu keybindings --print` lists what is already bound.

## Keybinds

| Key | Action |
| --- | --- |
| `SUPER + R` | Speak selection — press again to pause, again to resume |
| `SUPER + SHIFT + R` | Speak selection with kokoro |
| `SUPER + ALT + R` | Speak clipboard |
| `SUPER + SHIFT + ]` | Queue the selection behind what's playing |
| `SUPER + ]` | Next clip in the queue |
| `SUPER + [` | Previous clip — or restart this one |
| `SUPER + SHIFT + ALT + R` | Save selection to audio |
| `SUPER + SHIFT + ESC` | Stop, and empty the queue |

Keys were checked against `omarchy menu keybindings --print` before choosing;
`SUPER+SHIFT+S` and the `SUPER+CTRL+R` family are Omarchy defaults, so the
speaking lives on `R` with modifiers and the queue on the bracket pair next to
it (`SUPER+ALT+[`/`]` belong to the webcam overlay, hence the `SHIFT` for
queueing).

## The queue

Speaking replaces; queueing appends. `SUPER+R` on a fresh selection throws away
whatever was queued and reads the new thing — the common case, and the old
behaviour. `SUPER+SHIFT+]` instead parks the selection behind what is already
playing, so you can skim a page, queue three paragraphs as you find them, and
let them read in order while you keep reading.

Pause is a real pause. `SUPER+R` during playback sends `SIGSTOP` to the engine
and the player rather than killing them, so resuming continues mid-word instead
of restarting the clip. The synthesiser needs no special handling: once the
player stops draining the pipe, it blocks on a full buffer by itself. ALSA may
click faintly on resume as the card refills — the cost of not re-synthesising.

Back (`SUPER+[`) restarts the current clip if you are more than three seconds
into it, and only steps to the previous one if you are not — the same bargain
every music player makes, and for the same reason: the common use of "back" is
"say that again".

`SUPER+SHIFT+ESC` is the hard stop, and empties the queue with it.

## Audio files

Speaking writes **nothing to disk**. Both engines run in `stream` mode, so audio
is piped from the engine straight into the player and never lands in a file.
There is no cache to purge and nothing accumulates from normal use.

Engines configured in `file` mode do use a scratch file, under
`$XDG_RUNTIME_DIR/omarchy-speak/`. It is removed when playback ends, when
playback is interrupted, and when synthesis fails partway through. Anything
orphaned by a crash is swept at daemon startup. `XDG_RUNTIME_DIR` is tmpfs and
cleared at logout, so a leak there costs RAM until reboot rather than disk.

The only files kept are the ones you deliberately save.

### Where saves go

`save_prompt` in the config decides:

- `true` (default) — a file chooser opens, starting in `save_dir` with a
  timestamped name filled in. Cancelling saves nothing and is not an error.
- `false` — writes straight to `save_dir` with no dialog.

Passing an explicit path to `omarchy-speak-ctl save` skips the chooser either
way, so you can bind one key that asks and another that does not:

```lua
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save kokoro")
o.bind("SUPER + CTRL + ALT + S", "Save selection (no prompt)", "omarchy-speak-ctl save kokoro ~/Audio/speak/quick.wav")
```

The chooser is `omarchy-speak-picker`, a GTK4 `FileDialog` that routes through
`xdg-desktop-portal` on Wayland, so it uses whatever file manager the desktop is
configured for. If GTK bindings are missing it exits 2 and the save falls back
to `save_dir` rather than failing.

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
| `GET` | `/status` | | Is it speaking, paused, and where in the queue |
| `GET` | `/engines` | | Configured engines |
| `GET` | `/queue` | | The queue, and which clip is current |
| `POST` | `/speak` | `{"text":…, "engine":…}` | Speak literal text, replacing the queue |
| `POST` | `/speak/selection` | `{"engine":…}` | Speak the primary selection |
| `POST` | `/speak/clipboard` | `{"engine":…}` | Speak the clipboard |
| `POST` | `/queue` | `{"text":…, "engine":…}` | Append text to the queue |
| `POST` | `/queue/selection` | `{"engine":…}` | Append the primary selection |
| `POST` | `/queue/clipboard` | `{"engine":…}` | Append the clipboard |
| `POST` | `/queue/clear` | | Drop everything except what is playing |
| `POST` | `/playpause` | `{"engine":…}` | Resume, or pause, or start on the selection |
| `POST` | `/pause` | | Suspend playback |
| `POST` | `/resume` | | Continue a suspended clip |
| `POST` | `/next` | | Skip to the next clip |
| `POST` | `/prev` | | Restart this clip, or step back |
| `POST` | `/save` | `{"engine":…, "path":…}` | Render to a file |
| `POST` | `/stop` | | Stop playback and empty the queue |
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
