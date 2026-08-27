# Maintainer: Sean Powless <249371201+seanpowless-dotcom@users.noreply.github.com>
pkgname=omarchy-speak
pkgver=0.1.0
pkgrel=1
pkgdesc="System-wide text-to-speech for Omarchy, driven by Hyprland keybinds"
arch=('any')
url="https://github.com/seanpowless-dotcom/omarchy-speak"
license=('MIT')
depends=(
  'python'          # daemon and wrappers; stdlib only
  'bash'            # omarchy-speak-ctl
  'curl'            # omarchy-speak-ctl talks to the daemon over HTTP
  'wl-clipboard'    # wl-paste, for the selection and clipboard
  'alsa-utils'      # aplay, the streaming player
)
optdepends=(
  'python-gobject: save-location file chooser'
  'gtk4: save-location file chooser'
  'xdg-desktop-portal-gtk: route the file chooser through the desktop portal'
  'libpulse: paplay, for engines configured in file mode'
  'python-onnxruntime: run kokoro against the system python instead of a venv'
)
# Neither TTS engine is packaged in the official repos. piper-tts and
# kokoro-onnx are installed from PyPI -- see the README. The daemon runs
# without either, and reports which binaries are missing when asked to speak.
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
  cd "$srcdir/$pkgname-$pkgver"

  install -Dm755 bin/omarchy-speak        "$pkgdir/usr/bin/omarchy-speak"
  install -Dm755 bin/omarchy-speak-ctl    "$pkgdir/usr/bin/omarchy-speak-ctl"
  install -Dm755 bin/omarchy-speak-picker "$pkgdir/usr/bin/omarchy-speak-picker"
  install -Dm755 bin/omarchy-speak-kokoro "$pkgdir/usr/bin/omarchy-speak-kokoro"

  # User units, not system: the daemon needs the user's Wayland session to
  # reach wl-paste and the audio server.
  install -Dm644 systemd/omarchy-speak.service \
    "$pkgdir/usr/lib/systemd/user/omarchy-speak.service"
  install -Dm644 systemd/omarchy-speak-kokoro.service \
    "$pkgdir/usr/lib/systemd/user/omarchy-speak-kokoro.service"

  install -Dm644 config.example.json \
    "$pkgdir/usr/share/$pkgname/config.example.json"
  install -Dm644 hypr/speak.lua \
    "$pkgdir/usr/share/$pkgname/speak.lua"

  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 LICENSE   "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
