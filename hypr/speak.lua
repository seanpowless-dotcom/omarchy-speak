-- omarchy-speak keybindings
-- Add to ~/.config/hypr/bindings.lua:
--   require("omarchy-speak")     -- if on the Lua path
-- or copy these o.bind() lines directly into bindings.lua.
--
-- Verified free against `omarchy menu keybindings --print` (228 defaults).

-- Speak the highlighted text, anywhere on the system. Press again to stop.
o.bind("SUPER + R", "Speak selection", "omarchy-speak-ctl toggle")

-- Same text, better voice, slower to start.
o.bind("SUPER + SHIFT + R", "Speak selection (kokoro)", "omarchy-speak-ctl selection kokoro")

-- Read the clipboard rather than the selection.
o.bind("SUPER + ALT + R", "Speak clipboard", "omarchy-speak-ctl clipboard")

-- Render the selection to an audio file. Opens a file chooser unless
-- save_prompt is false in the config; pass a path to always skip the chooser.
o.bind("SUPER + SHIFT + ALT + R", "Save selection as audio", "omarchy-speak-ctl save kokoro")

-- Hard stop, without needing to re-select.
o.bind("SUPER + SHIFT + ESCAPE", "Stop speaking", "omarchy-speak-ctl stop")
