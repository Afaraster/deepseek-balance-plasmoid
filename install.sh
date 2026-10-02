#!/usr/bin/env bash
# 安装 / 升级 ds-balance 脚本、Plasma 组件与 systemd 用户定时器。
# 只写 $HOME 下的文件，不需要 root。
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="io.github.afaraster.deepseekbalance"

BIN_DIR="$HOME/.local/bin"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids"
UNIT_DIR="$HOME/.config/systemd/user"

echo "==> 安装脚本到 $BIN_DIR/ds-balance"
install -Dm755 "$SRC/bin/ds-balance" "$BIN_DIR/ds-balance"

echo "==> 安装 Plasma 组件 $PLUGIN_ID"
if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC/plasmoid/$PLUGIN_ID" >/dev/null 2>&1 \
        || kpackagetool6 --type Plasma/Applet --install "$SRC/plasmoid/$PLUGIN_ID"
else
    echo "!! 没找到 kpackagetool6，直接拷贝到 $PLASMOID_DIR"
    mkdir -p "$PLASMOID_DIR"
    cp -r "$SRC/plasmoid/$PLUGIN_ID" "$PLASMOID_DIR/"
fi

echo "==> 安装 systemd 用户定时器"
install -Dm644 "$SRC/systemd/ds-balance.service" "$UNIT_DIR/ds-balance.service"
install -Dm644 "$SRC/systemd/ds-balance.timer" "$UNIT_DIR/ds-balance.timer"
systemctl --user daemon-reload
systemctl --user enable --now ds-balance.timer

echo "==> 自检"
if "$BIN_DIR/ds-balance" >/dev/null 2>&1; then
    "$BIN_DIR/ds-balance"
else
    echo "!! 查询失败，检查 API key（见 README「配置 API key」）"
    "$BIN_DIR/ds-balance" || true
fi

cat <<'EOF'

下一步：
  1. 加组件到桌面 —— 右键桌面 → 添加组件 → 搜索 “DeepSeek 余额”
  2. 若列表里还没出现，重启一次 shell：systemctl --user restart plasma-plasmashell
  3. 移动/缩放组件 —— 直接拖动右下角，或用桌面的编辑模式

卸载：
  systemctl --user disable --now ds-balance.timer
  rm -f ~/.config/systemd/user/ds-balance.{service,timer} ~/.local/bin/ds-balance
  rm -rf ~/.local/share/plasma/plasmoids/io.github.afaraster.deepseekbalance
EOF
