-- omarchy-speak keybindings
-- Add to ~/.config/hypr/bindings.lua:
--   require("omarchy-speak")     -- if on the Lua path
-- or copy these o.bind() lines directly into bindings.lua.
--
-- Verified free against `omarchy menu keybindings --print` (228 defaults).

-- Speak the highlighted text, anywhere on the system. Press again to pause,
-- again to pick up where it left off.
o.bind("SUPER + R", "Speak selection (play/pause)", "omarchy-speak-ctl playpause")

-- The voice picker: voices, speed, chunk size, and a level meter that reads the
-- output sink. This key used to force the kokoro engine, which is a no-op on any
-- machine where kokoro is already the default -- same engine, same result as
-- SUPER+R. Pass an engine to omarchy-speak-ctl explicitly if you want the other
-- one for a single utterance; a keybind is the wrong place to spend on it.
o.bind("SUPER + SHIFT + R", "Speak: voice picker", "omarchy-launch-terminal omarchy-speak-ui")

-- Read the clipboard rather than the selection.
o.bind("SUPER + ALT + R", "Speak clipboard", "omarchy-speak-ctl clipboard")

-- Queue the selection behind whatever is already speaking, rather than
-- interrupting it. Highlight, queue, highlight, queue — it reads them in turn.
o.bind("SUPER + SHIFT + BRACKETRIGHT", "Queue selection", "omarchy-speak-ctl enqueue")

-- Move through the queue. Back restarts the current clip if you are more than
-- a few seconds into it, which is the same bargain every music player makes.
o.bind("SUPER + BRACKETRIGHT", "Speak: next in queue", "omarchy-speak-ctl next")
o.bind("SUPER + BRACKETLEFT", "Speak: previous in queue", "omarchy-speak-ctl prev")

-- Render the selection to an audio file. Opens a file chooser unless
-- save_prompt is false in the config; pass a path to always skip the chooser.
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save")

-- Hard stop: silences playback and empties the queue.
o.bind("SUPER + SHIFT + ESCAPE", "Stop speaking", "omarchy-speak-ctl stop")
