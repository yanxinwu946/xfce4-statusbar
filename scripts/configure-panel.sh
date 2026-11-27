#!/bin/bash
set -euo pipefail

CHANNEL="xfce4-panel"
PANEL="/panels/panel-1/plugin-ids"
XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
STAMP="$(date +%Y%m%d-%H%M%S)"

set_prop() {
  local path="$1" type="$2" value="$3"
  if xfconf-query -c "$CHANNEL" -p "$path" >/dev/null 2>&1; then
    xfconf-query -c "$CHANNEL" -p "$path" -t "$type" -s "$value"
  else
    xfconf-query -c "$CHANNEL" -p "$path" --create -t "$type" -s "$value"
  fi
}

if [ -f "$XML" ]; then
  cp -a "$XML" "$XML.bak-$STAMP"
  echo "已备份：$XML.bak-$STAMP"
fi

# 15 留给 Kali 的 VPN IP；25 = 网速，24 = 内存/磁盘，26 = 壁纸名字；30/28/29/27 = 透明 separator
set_prop /plugins/plugin-25 string genmon
set_prop /plugins/plugin-25/command string "$HOME/.local/bin/net-speed.sh"
set_prop /plugins/plugin-25/update-period uint 1000
set_prop /plugins/plugin-25/use-label bool false
set_prop /plugins/plugin-25/enable-single-row bool true

set_prop /plugins/plugin-24 string genmon
set_prop /plugins/plugin-24/command string "$HOME/.local/bin/genmon-sys.sh"
set_prop /plugins/plugin-24/update-period uint 1000
set_prop /plugins/plugin-24/use-label bool false
set_prop /plugins/plugin-24/enable-single-row bool true

set_prop /plugins/plugin-26 string genmon
set_prop /plugins/plugin-26/command string "$HOME/.local/bin/wallpaper-name.sh"
set_prop /plugins/plugin-26/update-period uint 2000
set_prop /plugins/plugin-26/use-label bool false
set_prop /plugins/plugin-26/enable-single-row bool true

for id in 30 28 29 27; do
  set_prop "/plugins/plugin-$id" string separator
  set_prop "/plugins/plugin-$id/expand" bool false
  set_prop "/plugins/plugin-$id/style" uint 0
  # 4.20.7 不支持 size；如果旧配置残留就删掉，避免误导
  xfconf-query -c "$CHANNEL" -p "/plugins/plugin-$id/size" -r 2>/dev/null || true
done

# 读取现有插件顺序，去掉本方案占用的 ID
mapfile -t ids < <(xfconf-query -c "$CHANNEL" -p "$PANEL" 2>/dev/null | grep -E '^[0-9]+$' || true)
filtered=()
for id in "${ids[@]}"; do
  case "$id" in
    24|25|26|27|28|29|30) ;;
    *) filtered+=("$id") ;;
  esac
done

# 插到 VPN IP（plugin-15）后面；找不到 15 就追加到末尾
new=()
inserted=false
for id in "${filtered[@]}"; do
  new+=("$id")
  if [ "$id" = "15" ] && [ "$inserted" = false ]; then
    new+=(30 25 28 24 29 26 27)
    inserted=true
  fi
done
if [ "$inserted" = false ]; then
  new+=(30 25 28 24 29 26 27)
fi

args=()
for id in "${new[@]}"; do
  args+=(-t int -s "$id")
done
xfconf-query -c "$CHANNEL" -p "$PANEL" "${args[@]}"

echo "面板顺序已写入：$PANEL"

if command -v xfce4-panel >/dev/null 2>&1; then
  pkill -x xfce4-panel 2>/dev/null || true
  sleep 1
  DISPLAY="${DISPLAY:-:0}" setsid xfce4-panel >/tmp/xfce4-statusbar-panel.log 2>&1 < /dev/null &
  echo "面板已重启。"
fi
