#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HOME/.local/bin"
CSS_DIR="$HOME/.config/gtk-3.0"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BIN" "$CSS_DIR"

for f in net-speed.sh genmon-sys.sh wallpaper-name.sh; do
  if [ -f "$BIN/$f" ]; then
    cp -a "$BIN/$f" "$BIN/$f.bak-$STAMP"
  fi
  install -m 0755 "$ROOT/scripts/$f" "$BIN/$f"
done

if [ -f "$CSS_DIR/gtk.css" ] && ! cmp -s "$CSS_DIR/gtk.css" "$ROOT/css/gtk.css"; then
  cp -a "$CSS_DIR/gtk.css" "$CSS_DIR/gtk.css.bak-$STAMP"
fi
install -m 0644 "$ROOT/css/gtk.css" "$CSS_DIR/gtk.css"

echo "已安装："
echo "  $BIN/net-speed.sh"
echo "  $BIN/genmon-sys.sh"
echo "  $BIN/wallpaper-name.sh"
echo "  $CSS_DIR/gtk.css"
echo
echo "下一步：运行 ./scripts/configure-panel.sh 配置面板插件，然后重启 XFCE 面板。"
