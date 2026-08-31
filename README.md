# omarchy-speak

System-wide text-to-speech for [Omarchy](https://omarchy.org), driven by Hyprland keybinds.

Highlight text anywhere — browser, terminal, PDF viewer, editor — and press a key to
hear it. Speech comes from **kokoro**, 54 voices across nine languages, running
locally on CPU or CUDA.

No browser extension. On Wayland the *primary selection* is system-wide, so one keybind
covers every application at once — including terminal applications that never set a
selection, which fall back to the clipboard. See
[Terminal applications](#terminal-applications-herdr-tmux-nvim).

## Features

- **Speak the selection** — anything highlighted, in any app
- **Speak the clipboard** — for text that isn't selectable
- **Save to file** — render the selection to a wav, with a file picker or straight
  to a default location
- **Play/pause** — a second press suspends mid-word; a third picks up where it left off
- **A queue** — stack up clips as you find them and they read in turn, with
  forward and back
- **Read a document** — a `.txt` or `.md` file, markdown stripped, queued by
  section so the bracket keys become chapter navigation
- **A voice picker** — 54 kokoro voices, auditioned in place, with speed and
  chunk size adjustable and a level meter that reads the output sink
- **A voice per source** — an utterance can name a voice, or a profile the
  machine maps to one, so system, apps and agents can each sound different
- **Two engines** — `default_engine` picks the one speaking uses; a request or
  a keybind can name the other for one utterance
- **GPU** — kokoro runs on CUDA when a usable GPU is present, and falls back to
  the CPU when it isn't
- **Streaming** — both engines start speaking before synthesis finishes
- **Says when it is broken** — a stalled clip is killed and explained rather
  than left running, and `reset` writes a diagnostic report before restarting

## Requirements

- Wayland with `wl-clipboard` (`wl-paste`)
- An audio player: `aplay` and/or `paplay`
- [kokoro](https://huggingface.co/hexgrad/Kokoro-82M) and its model

`bin/omarchy-speak-kokoro` wraps the library in a CLI the daemon drives as a
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
o.bind("SUPER + R", "Speak selection (play/pause)", "omarchy-speak-ctl playpause")
o.bind("SUPER + SHIFT + R", "Speak: voice picker", "omarchy-launch-terminal omarchy-speak-ui")
o.bind("SUPER + ALT + R", "Speak clipboard", "omarchy-speak-ctl clipboard")
o.bind("SUPER + SHIFT + BRACKETRIGHT", "Queue selection", "omarchy-speak-ctl enqueue")
o.bind("SUPER + BRACKETRIGHT", "Speak: next in queue", "omarchy-speak-ctl next")
o.bind("SUPER + BRACKETLEFT", "Speak: previous in queue", "omarchy-speak-ctl prev")
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save")
o.bind("SUPER + SHIFT + ESCAPE", "Stop speaking", "omarchy-speak-ctl stop")
```

No binding names an engine: with one configured they all follow
`default_engine`. Pass one to `omarchy-speak-ctl` explicitly if you ever add a
second.

Then `hyprctl reload`. On plain Hyprland without Omarchy's Lua layer, the
equivalent `bindd =` lines go in `hyprland.conf`:

```
bindd = SUPER, R, Speak selection, exec, omarchy-speak-ctl playpause
bindd = SUPER SHIFT, R, Voice picker, exec, foot omarchy-speak-ui
```

Check for conflicts before committing to keys — on Omarchy,
`omarchy menu keybindings --print` lists what is already bound.

## Keybinds

| Key | Action |
| --- | --- |
| `SUPER + R` | Speak selection — press again to pause, again to resume |
| `SUPER + SHIFT + R` | Voice picker |
| `SUPER + ALT + R` | Speak clipboard |
| `SUPER + SHIFT + ]` | Queue the selection behind what's playing |
| `SUPER + ]` | Next clip in the queue |
| `SUPER + [` | Previous clip — or restart this one |
| `SUPER + SHIFT + ALT + R` | Save selection to audio |
| `SUPER + SHIFT + ESC` | Stop, and empty the queue |

`SUPER+SHIFT+R` used to force the kokoro engine, which is a no-op wherever
kokoro is already the default — the same engine and the same result as
`SUPER+R`, one keybind spent on nothing. It opens the picker instead. Pass an
engine to `omarchy-speak-ctl` explicitly for a one-off.

Keys were checked against `omarchy menu keybindings --print` before choosing;
`SUPER+SHIFT+S` and the `SUPER+CTRL+R` family are Omarchy defaults, so the
speaking lives on `R` with modifiers and the queue on the bracket pair next to
it (`SUPER+ALT+[`/`]` belong to the webcam overlay, hence the `SHIFT` for
queueing).

## The voice picker

    omarchy-speak-ui          # or SUPER+SHIFT+R

```
 omarchy-speak                          default af_sarah @ 1.00
 all  American  British  Spanish  French  Hindi  Italian  Japanese
 af_alloy          af_sarah
 af_aoede          American female
 af_bella
 af_heart          speed  1.00   - / +
 ...               chunk   350   [ / ]
*af_sarah          first sound  560 ms
 am_adam
 level ──────────────────────────────────────────
 enter/l audition   [ ] chunk   w save   r reset   q quit
```

| | |
|---|---|
| `↑` `↓` `j` `k` `PgUp` `PgDn` · wheel · click | move |
| `←` `→` `Tab` | filter by language |
| `Enter` / `Space` | audition a sentence |
| `l` | audition a long passage — the only way to hear chunk size |
| `+` `-` | speed |
| `[` `]` | chunk size |
| `w` | save voice, speed and chunk as the default |
| `r` | reset (see below) |
| `R` | reload the voice list |

There are no written voice descriptions. Kokoro ships none, so they would be 54
strings to write and maintain, and a sentence about a voice is worse than the
button that plays it. What is shown is what the name already encodes: first
letter language, second gender.

**The level meter reads the output sink**, not the synthesiser. A meter fed from
the engine bounces happily while a Bluetooth speaker that is connected but
asleep swallows every sample. Fed from the sink, a flat bar during playback
means no sound is reaching the world — which is worth knowing, and is also why
`first sound` is measured from the meter rather than from the engine's pipe.

**Saving restarts the daemon**, which reads its config once at startup, so a
write alone would change nothing anyone could hear.

## Reading a document

    omarchy-speak-ctl read [file] [engine]

No path opens a file chooser. `.txt` and `.md` only — PDF needs a dependency and
extraction quality varies wildly, and "it read my paper wrong" is worse than
"not supported yet".

Markdown is stripped rather than spoken: raw `.md` reads as *"hash hash
Introduction, star star important star star"*, and code fences are worse.
Headings, emphasis, bullets, blockquotes, rules, tables, images and comments go;
link text stays and the URL goes.

The file is queued **by section**, not spoken as one clip. A single utterance is
truncated at `max_chars`, so a long document would silently lose its tail;
queueing also means playback starts on section one while the rest is still being
posted, and `SUPER+[` / `SUPER+]` become document navigation.

## When something is wrong

    omarchy-speak-ctl reset

Writes a diagnostic report to `$XDG_STATE_HOME/omarchy-speak/last-reset.md`
**before** restarting the engine and daemon. A reset that only restarts destroys
the evidence for the bug it just papered over, and the failures worth reporting
here look identical from outside: a wedged engine, a sink that accepts audio
without playing it, a daemon that believes it is speaking.

The report holds `/status` and `/config`, a **timed liveness probe per engine**
(the most diagnostic line in the file — a wedged kokoro worker blocks at ~0% CPU
and is otherwise indistinguishable from a slow one), the default sink and
connected Bluetooth devices, 40 journal lines, and unit states with restart
counts.

It deliberately does not diagnose the cause or touch the audio sink. It reports
facts and lets a human read them.

## A voice per source

Utterances can name a voice, or a profile the machine maps to one:

```json
"voices": {
  "system": "af_sarah",
  "claude": "am_michael",
  "codex":  "am_fenrir",
  "herdr":  "af_heart"
}
```

The queue holds whatever mix you give it, so a conversation is just a sequence
of clips with different voices. `tools/render-conversation` renders one to a
single wav, with per-turn speed and gap:

```bash
tools/render-conversation script.json out.wav
```

Per-turn speed and gap are the only delivery controls that exist — kokoro has no
prosody, emphasis or laughter — so they carry more weight than they look like
they should. Two speakers at an identical pace read as one person doing both
parts.

## Omarchy bar module

A status-bar readout of the configured voice, or whoever is currently talking.
See [`omarchy/README.md`](omarchy/README.md). `install.sh` puts the script in
place when `~/.config/omarchy` exists; it does nothing until an entry is added
to `shell.json`.

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
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save")
o.bind("SUPER + CTRL + ALT + S", "Save selection (no prompt)", "omarchy-speak-ctl save ~/Audio/speak/quick.wav")
```

The chooser is `omarchy-speak-picker`, a GTK4 `FileDialog` that routes through
`xdg-desktop-portal` on Wayland, so it uses whatever file manager the desktop is
configured for. If GTK bindings are missing it exits 2 and the save falls back
to `save_dir` rather than failing.

## Terminal applications (herdr, tmux, nvim)

Highlighting text inside a mouse-capturing TUI does **not** set the primary selection,
so a naive `wl-paste --primary` reads whatever some other window last set, or nothing.
Two things cause it, and both have to be true:

1. **The application takes the mouse.** herdr with `mouse_capture = true`, tmux with
   `set -g mouse on`, nvim with `mouse=a` all enable mouse reporting (`\e[?1002h`,
   `\e[?1003h`, `\e[?1006h`). The terminal then forwards drags to the application
   instead of making its own selection, and only the *terminal* publishes to the
   Wayland primary selection.
2. **When they do copy, they copy elsewhere.** They use OSC 52, whose target is the
   clipboard rather than the primary selection — herdr emits `\e]52;c` and contains
   no `\e]52;p` at all.

So **speaking the selection falls back to the clipboard when there is no selection.**
An empty primary selection is a reliable signal that you are inside such an
application, and the clipboard is where its copy actually went.

The risk is speaking something stale, because "nothing is selected" and "nothing is
selected but something was copied an hour ago" look identical from outside. Two bounds:

- the fallback runs **only when the primary selection is empty**, so it can never
  override a real selection; and
- the same clipboard text is **never handed out twice**, so leaning on `SUPER+R` in a
  terminal that sets no selection reads the clipboard once and then tells you there is
  nothing to speak, rather than repeating an hour-old copy on every press.

Asking for the clipboard by name is not a fallback and is not guarded: `SUPER+ALT+R`
(`/speak/clipboard`) always speaks it, which is how you deliberately repeat something.

Every reply reports the `source` it actually used, so which path fired is visible
rather than guessed at:

```console
$ curl -s -X POST localhost:8765/speak/selection
{"ok": true, "engine": "kokoro", "chars": 214, "source": "clipboard"}
```

Set `"selection_fallback": false` in the config to switch it off and restrict
`/speak/selection` to the primary selection alone.

**Selecting with the terminal instead.** If you would rather have the real primary
selection, hold **Shift** while dragging. That overrides the application's mouse grab
and lets the terminal make the selection itself. In foot that is
`selection-override-modifiers`, which defaults to `Shift` (`man 5 foot.ini`); alacritty,
kitty and ghostty follow the same Shift convention, though check your own config if you
have rebound it.

## When nothing plays

Every keybind looks dead, both engines are silent, and the journal says nothing.
The daemon is usually fine — **check where the audio is going before suspecting
the TTS.**

The common cause is a **Bluetooth speaker that is connected but asleep.** BlueZ
reports it connected, PipeWire keeps its node alive as the default sink, and
audio is accepted by something that never plays it. Short clips vanish into the
buffer without a sound; long ones fill it and then block forever.

`Connected: yes` is not sufficient evidence that audio can flow:

```console
$ wpctl status | sed -n '/Sinks:/,/Sources:/p'
 │  *   90. JBL Xtreme 2                 ← default, and possibly asleep
 │      43. Built-in Audio Analog Stereo

$ bluetoothctl devices Connected        # BlueZ's view, not PipeWire's
```

The fix is to wake the speaker (press its power button) or move output
elsewhere:

```console
$ wpctl set-default 43
```

**Sink numbers are reassigned on every reconnect** — the same speaker was 84,
then 90, within one session. Read the current number out of `wpctl status`
rather than reusing one from earlier. WirePlumber stores the preference by node
*name*, so setting it once per device is enough to make it persist.

### What the daemon does about it

It cannot fix your sink, but it no longer hangs quietly on one.

**Stalled playback is killed and logged.** Each clip gets a budget of
`startup_grace + chars/4` — the second term is roughly three times real speech,
so a 20,000 character article has about 84 minutes before anything intervenes.
Past that, the clip is almost certainly stuck rather than slow, so the chain is
killed and the reason goes to the journal. Paused clips are exempt: pausing one
over lunch is not a stall.

`startup_grace` is **per engine** (default 30s), because it covers everything
before the first sample — process spawn, model load, warm-up. Neither shipped
engine overrides it, because measurement says neither needs to:

| | first sample |
|---|---|
| kokoro, CUDA | 0.56 s |
| kokoro, warm, i7-8550U no CUDA | 1.3 s |
| kokoro, **worker stopped**, same machine | 2.2 s |

The 30-second default covers the worst of those more than ten times over.

Resist making it large. A long grace protects nothing — it only delays
noticing a broken engine. **A request that blocks for minutes at near-zero CPU
has not gone slow, it has wedged**: kokoro's warm worker does this after long
uptimes, and `systemctl --user restart omarchy-speak-kokoro` fixes it in one
command. Check CPU usage before reaching for a bigger number.

The same budget bounds `/save` and file-mode synthesis, which the watchdog
cannot reach — they run synchronously, so a wedged engine there would hold the
request open forever rather than merely playing silence.

**Engine and player stderr reaches the journal.** Both were previously
discarded, which is why an outage could leave nothing behind but the daemon's
own start and stop lines. A non-zero exit from either now reports its output:

```console
$ journalctl --user -u omarchy-speak -f
omarchy-speak: playback stalled after 756s (budget 84s) and was killed. The audio
sink is accepting audio without draining it — a Bluetooth speaker that is
connected but asleep does exactly this. Check `wpctl status` for the default sink.
omarchy-speak: player exited 1: aplay: device busy
```

If playback stops mid-clip and the journal is empty, the sink is not the
problem and this is worth reporting as a bug.

## Configuration

`~/.config/omarchy-speak/config.json`, created on first run with `--init-config`.

Engines are defined as **command templates**, so omarchy-speak works with whatever
packaging you used — pip, AUR, a local build — without code changes. `{model}`,
`{voice}` and `{out}` are substituted from the engine's own config block.

```json
{
  "default_engine": "kokoro",
  "save_dir": "~/Audio/speak",
  "engines": {
    "kokoro": {
      "mode": "stream",
      "voice": "af_sarah",
      "speed": 1.0,
      "chunk_chars": 350,
      "speak": ["omarchy-speak-kokoro", "--voice", "{voice}",
                "--speed", "{speed}", "--chunk-chars", "{chunk_chars}",
                "--output-raw"],
      "save":  ["omarchy-speak-kokoro", "--voice", "{voice}",
                "--speed", "{speed}", "--chunk-chars", "{chunk_chars}",
                "--output-file", "{out}"],
      "play":  ["aplay", "-q", "-r", "24000", "-f", "S16_LE", "-t", "raw", "-"]
    }
  }
}
```

`mode` is either `stream` (engine writes raw audio to stdout, piped straight to the
player — speech starts before synthesis finishes) or `file` (engine renders a wav,
then it plays).

**Every tunable has to appear in the command template.** `render()` substitutes
`{placeholders}` from the engine block, so a key the template never names is
written to the config, reported as saved, and ignored by everything downstream.
That is why `{speed}` and `{chunk_chars}` are in the commands above and not just
in the block.

`selection_fallback` (default `true`) controls whether speaking the selection falls
back to the clipboard when nothing is selected — see
[Terminal applications](#terminal-applications-herdr-tmux-nvim).

`startup_grace` sits inside an **engine** block and is how long that engine may
take to produce its first sample before playback is presumed stuck. Default 30
seconds; neither shipped engine overrides it. See
[When nothing plays](#when-nothing-plays).

`chunk_chars` also sits inside an engine block and is the single biggest lever
on how long you wait before the first word of a long passage — the first chunk
*is* that wait. Measured on a CPU-only i7-8550U with 2584 characters:

| chunk | first audio |
|---|---|
| 80 | 2158 ms |
| 150 | 4167 ms |
| 250 | 7822 ms |
| 350 | 8307 ms |

The same sweep on a CUDA machine lands between 454 and 596 ms at *every* size —
noise. So a fast machine should leave it at 350 and take the fewer seams, and a
slow one should drop it. The picker's `[` and `]` adjust it, and `l` plays a long
passage so you can hear the difference rather than guess at it.

`voices` is a top-level map of profile to voice; see
[A voice per source](#a-voice-per-source).

## HTTP API

The daemon listens on `127.0.0.1:8765`. Any client can drive it — the keybinds are
just `curl` in a trenchcoat.

| Method | Path | Body | Purpose |
| --- | --- | --- | --- |
| `GET` | `/status` | | Is it speaking, paused, and where in the queue |
| `GET` | `/engines` | | Configured engines |
| `GET` | `/queue` | | The queue, and which clip is current |
| `POST` | `/speak` | `{"text":…, "engine":…, "voice":…, "profile":…, "speed":…}` | Speak literal text, replacing the queue |
| `POST` | `/speak/selection` | `{"engine":…}` | Speak the primary selection, or the clipboard if there is none |
| `POST` | `/speak/clipboard` | `{"engine":…}` | Speak the clipboard |
| `POST` | `/queue` | `{"text":…, "engine":…, "voice":…, "profile":…, "speed":…}` | Append text to the queue |
| `POST` | `/queue/selection` | `{"engine":…}` | Append the primary selection, or the clipboard if there is none |
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

**`voice`, `profile` and `speed` apply to that utterance only**, so a queue can
hold a conversation:

```bash
curl -sX POST -d '{"text":"First speaker.","voice":"af_bella"}'   .../speak
curl -sX POST -d '{"text":"And a second.","voice":"am_michael"}'  .../queue
```

Prefer `profile` to `voice` wherever the caller is a program. A caller naming a
voice has to know which voices exist on this machine, so it breaks anywhere
that one is missing or unwanted; a caller naming a profile says what it *is*
and lets the machine decide how that sounds. Unknown profiles fall back to the
configured voice rather than failing — an agent nobody has set up should still
be heard, just not distinctly.

`source` accepts `primary` or `clipboard`. Anything else is an error: it used
to fall through to the clipboard, so a request naming a source that does not
exist quietly spoke whatever happened to be copied.

Because it's plain HTTP, a status-bar widget or a browser extension can be added later
without touching the daemon.

## Why loopback HTTP and not a native messaging host

Chrome's native messaging only works from the browser. A local HTTP daemon serves the
keybinds, a future widget, and a future extension from one backend, and it's testable
with `curl`. It binds `127.0.0.1` only.

## License

MIT
