# DeepSeek 余额 · KDE Plasma 桌面组件

[English](README.en.md) | 中文

在 KDE Plasma 6 桌面上直接看 DeepSeek 开放平台余额：总额、充值/赠金拆分，以及近 1 小时 / 24 小时的消耗。

![截图](assets/screenshot.png)

非官方项目，与 DeepSeek 官方无关联。只调用官方文档里的只读接口 `GET /user/balance`。

## 特性

- **桌面常驻**：Plasma 6 组件（plasmoid），可放桌面或面板；有完整形态和紧凑形态。
- **不重复调用接口**：组件每 30 秒只读本地缓存，**不发网络请求**；真正的 API 调用由 systemd 用户定时器每 5 分钟做一次，多开几个组件也不会重复打接口。
- **消耗趋势**：每次查询追加一条历史，据此算近 1 小时 / 24 小时的消耗，肉眼可见"这段对话花了多少钱"。
- **失败可见**：网络异常时沿用上一次结果并标注；数据超过 10 分钟没更新，状态点从绿 `●` 变黄 `⚠`，不会悄悄显示一个过期数字。
- **零依赖**：查询脚本只用 Python 3 标准库（`urllib`），不需要 pip 装任何东西。
- **可命令行用**：脚本本身就能跑，不做桌面组件也能用。

## 依赖

| 项 | 要求 |
| --- | --- |
| 桌面 | KDE Plasma 6.x（实测 6.3.6；Plasma 5 不可用，QML API 不同） |
| 运行时 | Python 3.8+（标准库即可） |
| 系统 | Linux + systemd（用户级定时器） |

## 安装

```bash
git clone https://github.com/Afaraster/deepseek-balance-plasmoid.git
cd deepseek-balance-plasmoid
./install.sh
```

`install.sh` 只写 `$HOME` 下的文件，不需要 root。它会：

1. 把查询脚本装到 `~/.local/bin/ds-balance`；
2. 用 `kpackagetool6` 安装 Plasma 组件；
3. 装好并启用 systemd 用户定时器（每 5 分钟一次）；
4. 立刻跑一次自检并把余额打出来。

之后右键桌面 → **添加组件** → 搜索 “DeepSeek 余额” 即可。若列表里还没出现，重启一次 shell 让它重新扫描：

```bash
systemctl --user restart plasma-plasmashell
```

## 配置 API key

按顺序找，第一个命中的生效：

1. 环境变量 `DEEPSEEK_API_KEY`；
2. `~/.config/deepseek/api_key`（文件内容就是 key）：

   ```bash
   install -Dm600 /dev/null ~/.config/deepseek/api_key
   printf '%s\n' 'sk-你的key' > ~/.config/deepseek/api_key
   ```

3. `~/.hermes/.env` 里的 `DEEPSEEK_API_KEY=`（Hermes Agent 用户可直接复用，无需额外配置）。

key 只被读取用于 `Authorization: Bearer` 请求头，不落盘、不打印、不进日志。

## 使用

命令行：

```bash
ds-balance             # 人类可读
ds-balance --widget    # 单行 JSON（组件用）
ds-balance --cached    # 只读缓存，不发网络请求
ds-balance --force     # 忽略缓存，强制请求一次
ds-balance --history   # 最近 20 条历史
```

输出示例：

```
DeepSeek 余额  ¥43.64
  充值 ¥43.64 + 赠金 ¥0.00
  近1小时消耗 ¥0.2800
  近24小时消耗 ¥0.2800
  更新 10-02 15:27（12s 前，来源 api）
```

状态与日志：

```bash
systemctl --user list-timers ds-balance.timer        # 定时器下次触发时间
systemctl --user status ds-balance.service           # 上次查询结果
tail ~/.cache/deepseek/invocations.log               # 谁在什么时候查过（含组件读取）
```

## 工作原理

```
        ┌───────────────────────────┐
        │ ds-balance.timer          │  每 5 分钟
        │ (systemd 用户定时器)       │
        └─────────────┬─────────────┘
                      │ 调 GET /user/balance
                      ▼
        ┌───────────────────────────┐
        │ ds-balance 脚本           │  写缓存 + 追加历史
        └─────────────┬─────────────┘
                      ▼
   ~/.cache/deepseek/balance.json   ← 唯一的真相来源
                      ▲
                      │ 每 30 秒 `--cached` 读一次（不发网络请求）
        ┌─────────────┴─────────────┐
        │ Plasma 组件 (QML)          │  只负责显示
        └───────────────────────────┘
```

把"取数"和"显示"拆开是刻意的：两边各自跑 5 分钟节拍会互相错开，界面最多滞后一整轮才看到新值；让定时器独占 API、组件高频读缓存之后，显示滞后压到 30 秒以内，而且不会因为多开组件而多打接口。

缓存有效期 270 秒（略短于 5 分钟），并加了 `flock` 文件锁，所以即使定时器和手动调用撞在一起，也只会发一次请求。

## 目录结构

```
bin/ds-balance                                   查询脚本（Python 3 标准库）
plasmoid/io.github.afaraster.deepseekbalance/    Plasma 组件
  ├── metadata.json
  └── contents/ui/main.qml
systemd/ds-balance.{service,timer}               用户级 service 与 5 分钟定时器
install.sh                                       安装 / 升级
```

运行期产生的文件（不进仓库）：

```
~/.cache/deepseek/balance.json       最近一次查询结果
~/.cache/deepseek/history.jsonl      每次查询追加的历史（用于算消耗）
~/.cache/deepseek/invocations.log    调用记录（排查"组件没刷新"用）
```

## 常见问题

**组件显示 ⚠ 或"更新 …（N 分钟前）"**
说明本地缓存超过 10 分钟没更新，一般是定时器没跑或网络不通。先看：

```bash
systemctl --user list-timers ds-balance.timer
tail -5 ~/.cache/deepseek/invocations.log
ds-balance --force
```

**组件一直停在旧数字**
2026-08 之前的版本里组件自己每 5 分钟打一次 API，与定时器相位错开导致最多滞后 5 分钟。现已改为组件 30 秒读一次缓存。升级后重启一次 shell：

```bash
systemctl --user restart plasma-plasmashell
```

**组件位置/大小**
拖动即可。批量改坐标要动 `~/.config/plasma-org.kde.plasma.desktop-appletsrc` 里 `ItemGeometries-<宽>x<高>` 的对应条目（形如 `Applet-<id>:x,y,w,h,0`），改完重启 shell —— 注意这个文件被运行中的 plasmashell 缓存，必须先停再改。

**改了 main.qml 但界面没变**
QML 只在组件创建时加载，改完要重启 shell：

```bash
systemctl --user restart plasma-plasmashell
```

若组件变成空白框，原因只在日志里：

```bash
journalctl --user -u plasma-plasmashell | grep 'error when loading applet'
```

**Plasma 5 能用吗**
不行。源码里 `preferredRepresentation: fullRepresentation` 这类写法是 Plasma 6 的 API；Plasma 5 需要改成 `Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation`。

## 卸载

```bash
systemctl --user disable --now ds-balance.timer
rm -f ~/.config/systemd/user/ds-balance.{service,timer} ~/.local/bin/ds-balance
rm -rf ~/.local/share/plasma/plasmoids/io.github.afaraster.deepseekbalance
rm -rf ~/.cache/deepseek
```

## 许可

MIT，见 [LICENSE](LICENSE)。
