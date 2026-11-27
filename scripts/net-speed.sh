#!/bin/bash

# XFCE genmon 网速插件：下载蓝 / 上传橙（Tokyo Night Storm）
# 用法：net-speed.sh [iface]
# 不传 iface 时自动选择第一个非 lo/docker0 的 IPv4 网卡。

IFACE="${1:-}"
if [ -z "$IFACE" ]; then
  IFACE="$(ip -o -4 addr show 2>/dev/null | awk '$2!="lo" && $2!="docker0" {print $2; exit}')"
fi
[ -z "$IFACE" ] && IFACE="wlan0"

DIR="/tmp/genmon-net-speed"
[ -d "$DIR" ] || mkdir -p "$DIR"
STAMP="$DIR/$(printf '%s' "$IFACE" | tr -cd 'a-zA-Z0-9')"

now_ns="$(date +%s%N)"
rx_now="$(cat "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)"
tx_now="$(cat "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)"

if [ -f "$STAMP" ]; then
  read old_ns old_rx old_tx < "$STAMP" 2>/dev/null
  dt=$(( (now_ns - old_ns) / 1000000 ))
  if [ "$dt" -gt 0 ]; then
    rx_s=$(( (rx_now - old_rx) * 1000 / dt ))
    tx_s=$(( (tx_now - old_tx) * 1000 / dt ))
  else
    rx_s=0; tx_s=0
  fi
else
  rx_s=0; tx_s=0
fi
echo "$now_ns $rx_now $tx_now" > "$STAMP"

format_speed() {
    awk -v b="$1" 'BEGIN{
        if (b > 1048576) s=sprintf("%.1f MB/s", b/1048576);
        else if (b > 1024) s=sprintf("%.0f KB/s", b/1024);
        else s=sprintf("%d B/s", b);
        printf "%9s", s}'
}

format_total() {
    awk -v b="$1" 'BEGIN{
        if (b > 1099511627776) s=sprintf("%.2f TiB", b/1099511627776);
        else if (b > 1073741824) s=sprintf("%.2f GiB", b/1073741824);
        else if (b > 1048576) s=sprintf("%.1f MiB", b/1048576);
        else if (b > 1024) s=sprintf("%.0f KiB", b/1024);
        else s=sprintf("%d B", b);
        printf "%s", s}'
}

DOWN="$(format_speed "$rx_s")"
UP="$(format_speed "$tx_s")"
TOTAL_DOWN="$(format_total "$rx_now")"
TOTAL_UP="$(format_total "$tx_now")"


# Tokyo Night Storm: 下载蓝 #7aa2f7  上传橙 #ff9e64
printf "<txt>"
printf "<span fgcolor='#7aa2f7'>↓%s</span> " "$DOWN"
printf "<span fgcolor='#ff9e64'>↑%s</span>" "$UP"
printf "</txt>"
printf "<tool>下载：%s（总 %s）\n上传：%s（总 %s）</tool>" "$DOWN" "$TOTAL_DOWN" "$UP" "$TOTAL_UP"
printf "<txtclick>nm-connection-editor</txtclick>"
