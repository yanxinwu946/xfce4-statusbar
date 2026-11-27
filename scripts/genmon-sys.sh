#!/bin/bash

# XFCE genmon 系统占用插件（抽屉模式）
# 循环切换：内存/磁盘 → 天气 → 运行时间
# 点击文本执行 --cycle 切换到下一个模式并强制刷新
#
# Tokyo Night Storm: 内存紫 #bb9af7，磁盘绿 #9ece6a，警告橙 #e0af68，高危红 #f7768e
# 天气用浅蓝 #7dcfff，运行时间用紫 #bb9af7

export LC_ALL=C
export DISPLAY="${DISPLAY:-:0}"

MODE_DIR="$HOME/.cache/xfce4-statusbar"
MODE_FILE="$MODE_DIR/drawer-24"
WEATHER_CACHE="$MODE_DIR/weather.txt"      # 缓存：城市/温度/天气/体感/湿度/风（tab 分隔）
mkdir -p "$MODE_DIR"

WEATHER_TTL=600   # 天气缓存 10 分钟

# --- 抽屉切换：写入新状态并触发 genmon 刷新 ---
if [ "${1:-}" = "--cycle" ]; then
  # 防抖：genmon 按钮在按下/释放时会触发两次，500ms 内的重复点击忽略
  ts_now="$(date +%s%N)"
  ts_file="$MODE_FILE.ts"
  if [ -f "$ts_file" ]; then
    ts_last="$(cat "$ts_file" 2>/dev/null || echo 0)"
    if [ $(( ts_now - ts_last )) -lt 500000000 ]; then
      exit 0
    fi
  fi
  printf '%s' "$ts_now" > "$ts_file"

  current="$(cat "$MODE_FILE" 2>/dev/null || echo sys)"
  case "$current" in
    sys)     next="weather" ;;
    weather) next="uptime" ;;
    *)       next="sys" ;;
  esac
  printf '%s' "$next" > "$MODE_FILE.tmp"
  mv "$MODE_FILE.tmp" "$MODE_FILE"
  xfce4-panel --plugin-event=genmon-24:refresh:bool:true 2>/dev/null
  exit 0
fi

mode="$(cat "$MODE_FILE" 2>/dev/null || echo sys)"
self="$(readlink -f "$0")"

# 统一收尾：点击循环切换
emit_click() {
  printf "<txtclick>%s --cycle</txtclick>" "$self"
}

# 天气描述 → Nerd Font 图标（MDI 字形，不用 emoji 以免字体回退尺寸不一致）
# 百度天气返回中文描述；组合词把更具体的排在前面
weather_icon() {
  case "$1" in
    *多云*)     printf '󰖕' ;;  # partly cloudy
    *晴*)       printf '󰖙' ;;  # sunny
    *阴*)       printf '󰖐' ;;  # cloudy
    *雾*|*霾*)  printf '󰖑' ;;  # fog
    *雷*)       printf '󰖓' ;;  # thunder
    *雪*)       printf '󰖘' ;;  # snow
    *雨*)       printf '󰖗' ;;  # rain
    *风*)       printf '󰖝' ;;  # wind
    *)          printf '󰖕' ;;  # 默认多云
  esac
}

# 运行时间统一格式
uptime_short() {
  uptime -p | sed 's/up //; s/ days/d/g; s/ day/d/g; s/ hours/h/g; s/ hour/h/g; s/ minutes/m/g; s/ minute/m/g; s/ seconds/s/g; s/,//g' | tr -d ' '
}

# --- 各模式显示（各自完整输出 <txt> 和 <tool>） ---

display_sys() {
  local mem memt pct mcolor disk diskt diskpct dcolor up
  mem=$(free -h | awk 'NR==2 {print $3}')
  memt=$(free -h | awk 'NR==2 {print $2}')
  pct=$(free | awk 'NR==2 {printf "%.0f", $3/$2*100}')
  if [ "$pct" -gt 80 ]; then mcolor='#f7768e'; elif [ "$pct" -gt 60 ]; then mcolor='#e0af68'; else mcolor='#bb9af7'; fi

  disk=$(df -h / | awk 'NR==2 {print $3}')
  diskt=$(df -h / | awk 'NR==2 {print $2}')
  diskpct=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  if [ "$diskpct" -gt 80 ]; then dcolor='#f7768e'; elif [ "$diskpct" -gt 60 ]; then dcolor='#e0af68'; else dcolor='#9ece6a'; fi

  up=$(uptime_short)

  printf "<txt>"
  printf "<span fgcolor='%s'>󰍛 %s</span> " "$mcolor" "$mem"
  printf "<span fgcolor='%s'>󰋊 %s</span>" "$dcolor" "$disk"
  printf "</txt>"
  printf "<tool>内存: %s / %s (%s%%)\n磁盘: %s / %s (%s%%)\n运行时间: %s\n点击切换显示内容</tool>" \
    "$mem" "$memt" "$pct" "$disk" "$diskt" "$diskpct" "$up"
}

display_weather() {
  local line city temp desc feel humidity wind icon
  # 缓存过期则重新拉：国内站 myip.ipip.net 拿出口城市 → 百度天气按城市查（不走 IP 定位）
  if [ ! -f "$WEATHER_CACHE" ] || [ "$(( $(date +%s) - $(stat -c %Y "$WEATHER_CACHE") ))" -ge "$WEATHER_TTL" ]; then
    city="$(timeout 8 curl -s --max-time 6 https://myip.ipip.net 2>/dev/null \
            | sed -n 's/.*来自于：[^ ]* [^ ]* \([^ ]*\).*/\1/p' | head -1)"
    [ -z "$city" ] && city="北京"
    timeout 10 curl -sL --max-time 8 \
      "https://weathernew.pae.baidu.com/weathernew/pc?query=${city}%E5%A4%A9%E6%B0%94&srcid=4982" 2>/dev/null \
      | python3 -c "
import json,sys,re
s=sys.stdin.read(); m=re.search(r'window\.tplData\s*=\s*(\{.*?\});',s,re.S)
w=json.loads(m.group(1)).get('weather',{}) if m else {}
print('\t'.join([sys.argv[1], w.get('temperature','?'), w.get('weather','?'),
      w.get('real_feel_temperature',''), w.get('humidity',''),
      (w.get('wind_direction','') or '')+(w.get('wind_power','') or '')]))
" "$city" > "$WEATHER_CACHE.tmp" 2>/dev/null
    [ -s "$WEATHER_CACHE.tmp" ] && mv "$WEATHER_CACHE.tmp" "$WEATHER_CACHE"
  fi
  line="$(cat "$WEATHER_CACHE" 2>/dev/null)"
  [ -z "$line" ] && { printf "<txt><span fgcolor='#e0af68'>󰖪 无网络</span></txt><tool>天气获取失败</tool>"; return 0; }

  IFS=$'\t' read -r city temp desc feel humidity wind <<< "$line"
  icon="$(weather_icon "$desc")"
  printf "<txt><span fgcolor='#7dcfff'>%s %s° %s</span></txt>" "$icon" "$temp" "$desc"
  printf "<tool>%s\n天气: %s\n温度: %s°C（体感 %s°C）\n湿度: %s\n%s\n点击切换显示内容</tool>" \
    "$city" "$desc" "$temp" "$feel" "$humidity" "$wind"
}

display_uptime() {
  local up
  up=$(uptime_short)
  printf "<txt><span fgcolor='#bb9af7'>󰥔 %s</span></txt>" "$up"
  printf "<tool>运行时间: %s\n点击切换显示内容</tool>" "$up"
}

# --- 输出 ---
case "$mode" in
  weather) display_weather ;;
  uptime)  display_uptime ;;
  *)       display_sys ;;
esac
emit_click
