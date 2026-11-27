# XFCE 状态栏：Tokyo Night Storm 网速 + 系统占用

一套用于 Kali / Debian XFCE 4.20.7 的 genmon 状态栏配置：

- 实时上传 / 下载网速（下载蓝、上传橙），tooltip 里带本次启动以来的累计流量
- 内存 / 根分区磁盘占用（内存紫、磁盘绿，阈值变色）
- 运行时间只放在 tooltip，不占用状态栏宽度
- 当前壁纸名字（超过 24 字符自动截断，tooltip 保留完整名和路径）
- genmon 插件统一胶囊背景（Tokyo Night 蓝，半透明 + 圆角），内容为空时胶囊自动隐藏
- 无竖线，插件之间有自然空隙
- 避开 Kali 登录脚本会重置的 `plugin-15`

配色来自 Tokyo Night Storm：

| 内容 | 颜色 |
| --- | --- |
| 下载 | `#7aa2f7` |
| 上传 | `#ff9e64` |
| 内存 | `#bb9af7` / `#e0af68` / `#f7768e` |
| 磁盘 | `#9ece6a` / `#e0af68` / `#f7768e` |
| 运行时间 | tooltip 内 |

## 目录结构

```text
.
├── css/gtk.css                 # 通用胶囊样式（空内容自动隐藏）
├── scripts/net-speed.sh        # 网速 genmon 脚本
├── scripts/genmon-sys.sh       # 抽屉插件：内存/磁盘 → 天气 → 运行时间（点击循环切换）
├── scripts/wallpaper-name.sh   # 当前壁纸名字 genmon 脚本
├── scripts/install.sh          # 安装脚本和 CSS（会备份原文件）
├── scripts/configure-panel.sh  # 写入 xfconf 面板配置并重启面板
└── scripts/measure-panel.py    # 用 AT-SPI 测量插件宽度，便于验证
```

## 快速安装

```bash
git clone https://github.com/yanxinwu946/xfce4-statusbar.git
cd xfce4-statusbar

./scripts/install.sh
./scripts/configure-panel.sh
```

`install.sh` 会：

- 安装脚本到 `~/.local/bin/`
- 安装 CSS 到 `~/.config/gtk-3.0/gtk.css`（通用胶囊规则，空内容自动隐藏）
- 如果目标文件已存在，先备份成 `*.bak-<timestamp>`

`configure-panel.sh` 会：

- 备份 `xfce4-panel.xml`
- 创建/配置 `plugin-25`（网速）、`plugin-24`（系统占用）、`plugin-26`（壁纸名字）
- 创建/配置四个透明 separator：`30 / 28 / 29 / 27`
- 把这组插件插到 `plugin-15`（VPN IP）后面
- 重启面板

如果面板没有自动回来，手动执行：

```bash
xfce4-panel
```

## 面板布局

最终顺序是：

```text
... 15(VPN IP) 30(sep) 25(网速) 28(sep) 24(系统占用) 29(sep) 26(壁纸) 27(sep) 13(CPU) ...
```

对应 xfconf：

```bash
xfconf-query -c xfce4-panel -p /plugins/plugin-25
# genmon
xfconf-query -c xfce4-panel -p /plugins/plugin-25/command
# /home/<user>/.local/bin/net-speed.sh

xfconf-query -c xfce4-panel -p /plugins/plugin-24
# genmon
xfconf-query -c xfce4-panel -p /plugins/plugin-24/command
# /home/<user>/.local/bin/genmon-sys.sh

xfconf-query -c xfce4-panel -p /plugins/plugin-26
# genmon
xfconf-query -c xfce4-panel -p /plugins/plugin-26/command
# /home/<user>/.local/bin/wallpaper-name.sh
```

所有 separator 都是 `style=0`（透明）：

```bash
for id in 2 8 10 12 20 21 27 28 29 30; do
  xfconf-query -c xfce4-panel -p /plugins/plugin-$id/style
done
```

## 为什么间距这样做

这是本仓库最关键的坑，踩过之后才定下来：

1. **XFCE 4.20.7 的 separator 固定 8px。**  
   源码里只有 `style` 和 `expand`，没有 `size` 属性。  
   新版 master 加了 `size`，但 4.20.7 没有；在 xfconf 里手动建 `size` 也会被插件忽略。

2. **CSS 改不动 separator 宽度。**  
   `#separator-30` 这类选择器能匹配到插件，但 `min-width`、`padding`、`margin`、`border` 都不改变它的分配宽度。

3. **GTK3 CSS 不支持 `!important`。**  
   写了会导致 `GTK_DEBUG=all` 报：

   ```text
   Theme parsing error: gtk.css:1:38: Junk at end of value for min-width
   ```

   所以规则里不要写 `!important`。

4. **最终方案：背景画在 .genmon_imagebox 上，padding 画在可见子元素上。**
   genmon 给每个实例的容器挂 `.genmon_plugin`、内容行挂 `.genmon_imagebox`，
   所以通用选择器能覆盖所有 genmon 插件（含 `plugin-15`），新增插件也自动生效，不用写死 ID：

   ```css
   .genmon_plugin {
     background-color: transparent;
     padding-left: 0;
     padding-right: 0;
   }

   .genmon_imagebox {
     background-color: rgba(122, 162, 247, 0.16);  /* Tokyo Night 蓝 */
     border-radius: 12px;
   }

   /* 可点击文本用按钮渲染；图标按钮和文本按钮共用一个胶囊 */
   .genmon_imagebox > button.genmon_valuebutton {
     padding-left: 12px;
     padding-right: 12px;
   }
   .genmon_imagebox > button.genmon_imagebutton {
     padding-left: 12px;
     padding-right: 2px;
   }

   /* 无 <txtclick> 时用 label；空文本宽度为 0，胶囊随之消失 */
   .genmon_imagebox > label.genmon_value {
     padding-left: 0;
     padding-right: 0;
   }
   ```

   关键点：GTK3 CSS 没有 `:empty` 伪类（实测 `:empty` 直接报
   `Invalid name of pseudo-class`），所以不能靠选择器判断文本是否为空。这里改成
   「**背景跟着可见子元素的尺寸走**」：有内容时子元素带 12px 左右 padding，撑出圆角胶囊；
   没内容时（例如 Kali 的 VPN IP 脚本输出 `<txt></txt>`，genmon 会隐藏按钮、只显示一个
   空 label）label 宽度为 0，`.genmon_imagebox` 也缩成 0 宽，胶囊自然消失，不再留下空圈。

   实测：VPN 断线（空 `<txt>`）时该插件宽度为 0、截图无胶囊；VPN 恢复后胶囊立刻回来，
   网速 / 天气 / 壁纸等插件不受影响。插件之间仍约为
   `12(右 padding) + 8(separator) + 12(左 padding) = 32px` 的空隙。

   曾经试过给容器 `.genmon_plugin` 直接加背景 + padding：简单，但断线的 VPN 会留下一个
   24px 宽的空胶囊。也试过 genmon 4.2+ 的脚本内嵌 `<css>` 标签，但样式分散在脚本里且
   只能作用于内部控件、改不到父容器背景，因此最终统一收敛到 `gtk.css` 的通用规则。


## Kali 特别注意

Kali 的登录脚本：

```text
/usr/share/kali-themes/fix-old-genmon-config.sh
```

会把 `plugin-15` 强制改回：

```text
/usr/share/kali-themes/xfce4-panel-genmon-vpnip.sh
```

所以：

- 不要把网速脚本放到 `plugin-15`
- VPN IP 继续留在 `plugin-15`
- 网速用新的 `plugin-25`
- 系统占用用 `plugin-24`

这也是本仓库固定使用这些 ID 的原因。

## 验证

安装后可以量一下每个插件的宽度：

```bash
python3 scripts/measure-panel.py
```

典型输出（宽度会随网速文本长度变化）：

```text
idx  role             x      w
 12  filler         671    144   # VPN IP（胶囊）
 13  panel          815      8   # 透明 separator
 14  filler         823    173   # 网速（胶囊）
 15  panel          996      8   # 透明 separator
 16  filler        1004    120   # 系统占用（胶囊）
 17  panel        1124      8   # 透明 separator
 18  filler        1132    210   # 壁纸名字（胶囊，截断到 24 字符）
 19  panel        1342      8   # 透明 separator
 20  filler        1350    178   # CPU 图（无胶囊）
```

直接看脚本输出：

```bash
~/.local/bin/net-speed.sh
~/.local/bin/genmon-sys.sh
```

`genmon-sys.sh` 是抽屉插件：默认显示内存 / 磁盘，点击文本循环切换  
内存/磁盘 → 天气 → 运行时间 → 内存/磁盘（状态存在 `~/.cache/xfce4-statusbar/drawer-24`）。  
`net-speed.sh` 的 tooltip 除了实时速度，还有本次启动以来的累计下载 / 上传流量；点击打开「高级网络配置」（`nm-connection-editor`）。  
`wallpaper-name.sh` 的状态栏文本截断到 24 字符，tooltip 里有完整文件名和路径；点击用默认程序打开壁纸。

## 点击行为

| 插件 | 点击效果 |
| --- | --- |
| 网速 | 打开「高级网络配置」（`nm-connection-editor`） |
| 系统占用（抽屉） | 循环切换 内存/磁盘 → 天气 → 运行时间 |
| 壁纸名字 | 用默认程序打开当前壁纸 |

天气数据来自 `wttr.in`（按 IP 定位），缓存 10 分钟存在 `~/.cache/xfce4-statusbar/weather.json`，断网时用旧缓存兜底。

## 自定义

### 改胶囊样式 / 间距

只改 `css/gtk.css` 一处即可，所有 genmon 插件会一起变。例如把背景调淡、padding 改小：

```css
.genmon_plugin {
  background-color: rgba(122, 162, 247, 0.10);
  border-radius: 10px;
  padding-left: 8px;
  padding-right: 8px;
}
```

然后重新安装并重启面板：

```bash
./scripts/install.sh
pkill xfce4-panel
sleep 1
DISPLAY=:0 setsid xfce4-panel >/tmp/xfce4-panel.log 2>&1 < /dev/null &
```

### 改配色

- 网速：`scripts/net-speed.sh` 里的 `#7aa2f7` / `#ff9e64`
- 内存/磁盘：`scripts/genmon-sys.sh` 里的 `mcolor` / `dcolor`

`genmon-sys.sh` 的图标全部用 Nerd Font 的 Material Design Icons 字形（`󰍛` 内存、`󰋊` 磁盘、`󰖑` 天气、`󰥔` 运行时间、`󰖪` 无网络），不用 emoji——emoji（如 `☀` U+2600、`⏱` U+23F1）会走字体回退，尺寸和颜色跟其他图标不一致。如果没有 Nerd Font，可以换成普通字符，例如 `MEM` / `DISK`。

### 改壁纸名字长度

`scripts/wallpaper-name.sh` 里的 `MAX_LEN` 控制可见名字长度（默认 24 字符），tooltip 始终是完整名。

### 指定网卡

默认自动选第一个非 `lo`、`docker0` 的 IPv4 网卡。手动指定：

```bash
/root/.local/bin/net-speed.sh wlan0
```

或在面板配置里把命令改成：

```bash
~/.local/bin/net-speed.sh wlan0
```

## 依赖

- XFCE 4.20.x
- `xfce4-genmon-plugin`（本机 4.3.0；胶囊样式用全局 CSS，老版本也可用）
- `xfconf-query`
- `bash`、`awk`、`ip`
- 可选：`python3-gi` + `gir1.2-atspi-2.0`（仅 `measure-panel.py` 需要）

## 参考

- XFCE 4.20 面板主题文档：<https://docs.xfce.org/xfce/xfce4-panel/4.20/theming>
- Genmon 文档：<https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin/start>
- Genmon CSS 类说明：<https://gitlab.xfce.org/panel-plugins/xfce4-genmon-plugin/-/raw/master/CSS%20Styling.txt>
- Genmon 内嵌 `<css>` 标签文档（备用方案）：<https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin/start>
- XFCE 面板主题 CSS 选择器：<https://docs.xfce.org/xfce/xfce4-panel/theming>
- XFCE 4.20.7 separator 源码（无 `size`）：<https://gitlab.xfce.org/xfce/xfce4-panel/-/raw/xfce4-panel-4.20.7/plugins/separator/separator.c>
- 新版 master separator 源码（新增 `size`，但 4.20.7 没有）：<https://gitlab.xfce.org/xfce/xfce4-panel/-/raw/master/plugins/separator/separator.c>
- 论坛：separator 无 style class，需用插件 ID 定位：<https://forum.xfce.org/viewtopic.php?id=16288>
