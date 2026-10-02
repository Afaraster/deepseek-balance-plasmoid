import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // 组件只读本地缓存（--cached，不发网络请求），所以不会额外消耗额度；
    // 真正的 API 请求由 systemd 用户定时器 ds-balance.timer 每 5 分钟做一次。
    // 用 `sh -c` 是为了让 $HOME 展开，避免把绝对路径写死在源码里。
    readonly property string queryCommand: "sh -c \"exec $HOME/.local/bin/ds-balance --widget --cached\""

    readonly property color dimColor: Kirigami.Theme.disabledTextColor
    readonly property color warnColor: Kirigami.Theme.negativeTextColor
    readonly property color okColor: Kirigami.Theme.positiveTextColor

    property bool loaded: false
    property bool ok: false
    property bool stale: false
    property string errText: ""
    property string totalText: "—"
    property string subText: ""
    property string burnText: ""
    property string timeText: "—"

    preferredRepresentation: fullRepresentation

    function fmt(v) {
        if (v === null || v === undefined)
            return null;
        return Number(v).toFixed(4);
    }

    function refresh() {
        exec.connectSource(root.queryCommand);
    }

    function apply(stdout) {
        var j;
        try {
            j = JSON.parse(stdout);
        } catch (e) {
            root.loaded = true;
            root.ok = false;
            root.stale = true;
            root.errText = "输出解析失败: " + e;
            return;
        }
        root.loaded = true;
        root.ok = j.ok === true;
        if (!root.ok) {
            root.stale = true;
            root.errText = j.error || "查询失败";
            return;
        }
        root.errText = j.error || "";
        root.totalText = "¥" + Number(j.total).toFixed(2);
        root.subText = "充值 ¥" + Number(j.topped_up).toFixed(2) + "   赠金 ¥" + Number(j.granted).toFixed(2);
        var a = fmt(j.burn_1h);
        var b = fmt(j.burn_24h);
        var parts = [];
        if (a !== null)
            parts.push("1h ¥" + a);
        if (b !== null)
            parts.push("24h ¥" + b);
        root.burnText = parts.length > 0 ? parts.join("     ") : "消耗统计累积中";
        var age = Number(j.age) || 0;
        root.stale = age > 600;   // 超过 10 分钟没有新数据就转成警告态
        root.timeText = (j.ts_str || "?") + (age >= 90 ? "（" + Math.round(age / 60) + " 分钟前）" : "");
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var out = (data && data["stdout"]) ? String(data["stdout"]) : "";
            exec.disconnectSource(sourceName);
            root.apply(out.trim());
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    toolTipMainText: "DeepSeek 开放平台余额"
    toolTipSubText: root.loaded
                     ? (root.ok
                        ? root.totalText + "\n" + root.subText + "\n" + root.burnText + "\n更新 " + root.timeText
                        : "查询失败：" + root.errText)
                     : "查询中…"

    fullRepresentation: Item {
        implicitWidth: Math.round(Kirigami.Units.gridUnit * 13)
        implicitHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "wallet-open"
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                }
                Text {
                    text: "DeepSeek 余额"
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: root.loaded ? (root.ok ? (root.stale ? "⚠" : "●") : "⚠") : "…"
                    color: (root.ok && !root.stale) ? okColor : warnColor
                }
            }

            Text {
                text: root.loaded && root.ok ? root.totalText : (root.loaded ? "查询失败" : "查询中…")
                font.pointSize: 22
                font.bold: true
                color: (root.loaded && !root.ok) ? warnColor : Kirigami.Theme.textColor
            }

            Text {
                visible: root.ok
                text: root.subText
                color: dimColor
                font.pointSize: 8
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: root.ok
                text: root.burnText
                color: Kirigami.Theme.textColor
                font.pointSize: 9
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: root.ok
                text: "更新 " + root.timeText
                color: root.stale ? warnColor : dimColor
                font.pointSize: 8
            }

            Text {
                visible: root.errText.length > 0
                text: root.errText
                color: warnColor
                font.pointSize: 8
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.maximumWidth: col.width
            }
        }
    }

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "wallet-open"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        Text {
            text: root.ok ? root.totalText : "—"
            color: Kirigami.Theme.textColor
            font.pointSize: 9
        }
    }
}
