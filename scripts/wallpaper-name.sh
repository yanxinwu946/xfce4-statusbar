#!/bin/bash

# XFCE genmon 壁纸名字插件：显示当前壁纸文件名（去掉扩展名）
# tooltip 显示完整路径，点击用默认程序打开壁纸

# 用 UTF-8 locale：${#var} 才会按字符计数，中文/多字节壁纸名不会被截坏
export LC_ALL=C.utf8
export DISPLAY="${DISPLAY:-:0}"

MAX_LEN=24   # 状态栏可见名字的最大字符数，超出用 … 截断；tooltip 保留完整名

get_prop() {
  xfconf-query -c xfce4-desktop -p "$1" 2>/dev/null || true
}

# 当前连接的显示器（如 eDP-1），xfconf 路径里是 monitoreDP-1
monitor="$(xrandr --query 2>/dev/null | awk '$2 == "connected" {print $1; exit}')"
[ -z "$monitor" ] && monitor="0"

# 当前工作区编号（xprop 输出形如：_NET_CURRENT_DESKTOP(CARDINAL) = 0）
workspace="$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk -F'= ' '{print $2; exit}')"

path=""
if [ -n "$workspace" ]; then
  path="$(get_prop "/backdrop/screen0/monitor${monitor}/workspace${workspace}/last-image")"
fi
[ -n "$path" ] || path="$(get_prop "/backdrop/screen0/monitor${monitor}/last-image")"
[ -n "$path" ] || path="$(get_prop "/backdrop/screen0/monitor0/last-image")"
[ -n "$path" ] || path="$(get_prop "/backdrop/screen0/monitor0/image-path")"

if [ -n "$path" ] && [ -e "$path" ]; then
  name="$(basename "$path")"
  label="$(printf '%s' "$name" | sed 's/\.[^.]*$//')"   # 去掉扩展名
  if [ "${#label}" -gt "$MAX_LEN" ]; then
    label="${label:0:$((MAX_LEN - 1))}…"
  fi
  # 保留 Unicode；Pango 会处理转义
  printf "<txt><span fgcolor='#7dcfff'>󰸐 %s</span></txt>" "$label"
  printf "<tool>壁纸：%s\n路径：%s</tool>" "$name" "$path"
  printf "<txtclick>xdg-open '%s'</txtclick>" "$path"
else
  printf "<txt><span fgcolor='#7dcfff'>󰸐 无壁纸</span></txt>"
  printf "<tool>未读取到当前壁纸路径</tool>"
fi
