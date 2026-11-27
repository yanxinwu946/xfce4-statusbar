#!/usr/bin/env python3
"""用 AT-SPI 测量 XFCE 面板上每个插件的 x 坐标和宽度。"""

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402


def main() -> None:
    desktop = Atspi.get_desktop(0)
    apps = [
        desktop.get_child_at_index(i)
        for i in range(desktop.get_child_count())
    ]
    panel_app = next(a for a in apps if a and a.get_name() == "xfce4-panel")
    panel = panel_app.get_child_at_index(0).get_child_at_index(0)

    print(f"{'idx':>3}  {'role':<16} {'x':>6}  {'w':>5}")
    for i in range(panel.get_child_count()):
        child = panel.get_child_at_index(i)
        if not child:
            continue
        ext = child.get_extents(Atspi.CoordType.SCREEN)
        print(f"{i:>3}  {child.get_role_name():<16} {ext.x:>6}  {ext.width:>5}")


if __name__ == "__main__":
    main()
