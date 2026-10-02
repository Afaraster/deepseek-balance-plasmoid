# DeepSeek Balance · a KDE Plasma widget

English | [中文](README.md)

Keep your DeepSeek API balance on the KDE Plasma 6 desktop: total balance, the
granted/top-up split, and how much you spent over the last hour / day.

![screenshot](assets/screenshot.png)

Unofficial project, not affiliated with DeepSeek. It only calls the read-only
endpoint documented at `GET /user/balance`.

## Features

- **Always on the desktop**: a Plasma 6 plasmoid that works on the desktop or in
  a panel, with both a full and a compact representation.
- **No wasted quota**: the widget polls the local cache every 30 seconds and makes
  **no network requests**; the actual API call is made once every 5 minutes by a
  systemd user timer.
- **Spend trend**: every query appends a history entry, which is what makes the
  "last 1h / 24h" figures possible — you can literally see what a conversation cost.
- **Failures are visible**: on network errors the last known value is kept and
  labelled; if the data is more than 10 minutes old, the status dot turns from a
  green `●` into a yellow `⚠` instead of quietly showing a stale number.
- **Zero dependencies**: the query script is Python 3 standard library only
  (`urllib`) — nothing to `pip install`.
- **Usable from the shell**: the script stands on its own; the widget is optional.

## Requirements

| Item | Requirement |
| --- | --- |
| Desktop | KDE Plasma 6.x (tested on 6.3.6; Plasma 5 will not work, the QML APIs differ) |
| Runtime | Python 3.8+ (standard library only) |
| System | Linux with systemd (user-level timer) |

## Install

```bash
git clone https://github.com/Afaraster/deepseek-balance-plasmoid.git
cd deepseek-balance-plasmoid
./install.sh
```

`install.sh` writes only inside `$HOME` and needs no root. It will:

1. install the query script to `~/.local/bin/ds-balance`;
2. install the Plasma widget with `kpackagetool6`;
3. install and enable the systemd user timer (every 5 minutes);
4. run one self-check and print your balance.

Then right-click the desktop → **Add Widgets** → search for “DeepSeek 余额”
(“DeepSeek Balance”). If it does not show up yet, restart the shell so it rescans:

```bash
systemctl --user restart plasma-plasmashell
```

## Configure the API key

Looked up in this order, first hit wins:

1. the `DEEPSEEK_API_KEY` environment variable;
2. `~/.config/deepseek/api_key` (the file content *is* the key):

   ```bash
   install -Dm600 /dev/null ~/.config/deepseek/api_key
   printf '%s\n' 'sk-your-key' > ~/.config/deepseek/api_key
   ```

3. `DEEPSEEK_API_KEY=` inside `~/.hermes/.env` (Hermes Agent users can reuse it as is).

The key is only read to build the `Authorization: Bearer` header. It is never
written to disk, printed, or logged.

## Usage

Shell:

```bash
ds-balance             # human readable
ds-balance --widget    # single-line JSON (used by the widget)
ds-balance --cached    # local cache only, no network request
ds-balance --force     # ignore the cache, query now
ds-balance --history   # last 20 history entries
```

Sample output:

```
DeepSeek 余额  ¥43.64
  充值 ¥43.64 + 赠金 ¥0.00
  近1小时消耗 ¥0.2800
  近24小时消耗 ¥0.2800
  更新 10-02 15:27（12s 前，来源 api）
```

Status and logs:

```bash
systemctl --user list-timers ds-balance.timer        # when the timer fires next
systemctl --user status ds-balance.service           # last query result
tail ~/.cache/deepseek/invocations.log               # who queried when (widget reads included)
```

## How it works

```
        ┌───────────────────────────┐
        │ ds-balance.timer          │  every 5 minutes
        │ (systemd user timer)      │
        └─────────────┬─────────────┘
                      │ GET /user/balance
                      ▼
        ┌───────────────────────────┐
        │ ds-balance script         │  writes cache + history
        └─────────────┬─────────────┘
                      ▼
   ~/.cache/deepseek/balance.json   ← single source of truth
                      ▲
                      │ every 30 s via `--cached` (no network)
        ┌─────────────┴─────────────┐
        │ Plasma widget (QML)       │  display only
        └───────────────────────────┘
```

Separating fetching from displaying is deliberate. Two independent 5-minute
clocks drift apart, so the UI can lag a full cycle behind the data; letting the
timer own the API and the widget poll the cache every 30 seconds cuts the display
lag to under 30 seconds and keeps extra widget instances from hammering the
endpoint.

The cache is valid for 270 seconds (slightly less than 5 minutes) and guarded by
an `flock` file lock, so even if the timer and a manual run overlap, only one
request goes out.

## Layout

```
bin/ds-balance                                   query script (Python 3 stdlib)
plasmoid/io.github.afaraster.deepseekbalance/    the Plasma widget
  ├── metadata.json
  └── contents/ui/main.qml
systemd/ds-balance.{service,timer}               user service + 5-minute timer
install.sh                                       install / upgrade
```

Runtime files (not in the repo):

```
~/.cache/deepseek/balance.json       last query result
~/.cache/deepseek/history.jsonl      one line per query (used for spend figures)
~/.cache/deepseek/invocations.log    call log (for "the widget is not refreshing" cases)
```

## Troubleshooting

**The widget shows ⚠ or “更新 …（N minutes ago）”**
The local cache has not been refreshed for over 10 minutes — usually the timer is
not running or the network is down. Check:

```bash
systemctl --user list-timers ds-balance.timer
tail -5 ~/.cache/deepseek/invocations.log
ds-balance --force
```

**The widget is stuck on an old number**
Versions before 2026-08 had the widget call the API itself every 5 minutes, which
drifted out of phase with the timer and could lag by a full cycle. It now reads
the cache every 30 seconds. Restart the shell after upgrading:

```bash
systemctl --user restart plasma-plasmashell
```

**Position / size**
Just drag it. To change coordinates in bulk, edit the matching
`ItemGeometries-<W>x<H>` entry (format `Applet-<id>:x,y,w,h,0`) in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` and restart the shell — note
that a running plasmashell caches this file, so stop it first.

**I edited main.qml but nothing changed**
QML is loaded when the applet is created; restart the shell:

```bash
systemctl --user restart plasma-plasmashell
```

If the widget turns into a blank box, the reason is only in the journal:

```bash
journalctl --user -u plasma-plasmashell | grep 'error when loading applet'
```

**Does it work on Plasma 5?**
No. Idioms such as `preferredRepresentation: fullRepresentation` are Plasma 6
APIs; on Plasma 5 you would need `Plasmoid.preferredRepresentation:
Plasmoid.fullRepresentation`.

## Uninstall

```bash
systemctl --user disable --now ds-balance.timer
rm -f ~/.config/systemd/user/ds-balance.{service,timer} ~/.local/bin/ds-balance
rm -rf ~/.local/share/plasma/plasmoids/io.github.afaraster.deepseekbalance
rm -rf ~/.cache/deepseek
```

## License

MIT, see [LICENSE](LICENSE).
