
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 64
    exclusiveZone: 64
    color: "transparent"

    property bool triggerHovered: false
    property bool panelHovered: false
    property bool menuVisible: false
    property bool settingsVisible: false
    property string settingsPage: "Appearance"
    property var selectedWifiNetwork: null
    property string wifiPassword: ""
    property real controlCentreProgress: 0

    onMenuVisibleChanged: controlCentreProgress = menuVisible ? 1 : 0

    Behavior on controlCentreProgress {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    readonly property color background: "#E9171B29"
    readonly property color surface: "#252A3B"
    readonly property color surfaceAlt: "#30364B"
    readonly property color accent: "#8179C9"
    readonly property color accentSoft: "#34314F"
    readonly property color textMain: "#E8EAF5"
    readonly property color textMuted: "#A6ACCA"
    readonly property color borderColor: "#454B68"

    function deviceConnected(deviceName) {
        for (let i = 0; i < Networking.devices.count; i++) {
            let device = Networking.devices.get(i)
            if (device.name === deviceName)
                return device.connected
        }
        return false
    }

    function runPowerCommand(command) {
        if (command === "lock")
            Quickshell.execDetached(["loginctl", "lock-session"])
        else if (command === "suspend")
            Quickshell.execDetached(["systemctl", "suspend"])
        else if (command === "logout")
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
        else if (command === "reboot")
            Quickshell.execDetached(["systemctl", "reboot"])
        else if (command === "poweroff")
            Quickshell.execDetached(["systemctl", "poweroff"])
    }

    function scheduleClose() {
        closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 250
        repeat: false

        onTriggered: {
            if (!root.triggerHovered && !root.panelHovered)
                root.menuVisible = false
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // =========================================
    // TOP BAR
    // =========================================

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 14
        color: "#E9171B29"
        border.color: "#454B68"
        border.width: 1

        // WORKSPACES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Repeater {
                model: Hyprland.workspaces

                delegate: Rectangle {
                    required property var modelData

                    visible: modelData.id > 0 && modelData.id <= 10
                    width: 30
                    height: 30
                    radius: 9

                    color: Hyprland.focusedWorkspace?.id === modelData.id
                        ? root.accent : root.surface

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id
                        color: Hyprland.focusedWorkspace?.id === modelData.id
                            ? "#FFFFFF" : root.textMuted
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(
                            "workspace " + modelData.id
                        )
                    }
                }
            }
        }

        // CLOCK
        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "ddd  dd MMM  •  hh:mm")
            color: root.textMain
            font.pixelSize: 13
            font.bold: true

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockText.text =
                    Qt.formatDateTime(new Date(), "ddd  dd MMM  •  hh:mm")
            }
        }

        // RIGHT SIDE
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: root.deviceConnected("enp8s0") ? "ETH" : "OFFLINE"
                color: root.textMuted
                font.pixelSize: 11
                font.bold: true
            }

            // SYSTEM TRAY
            Row {
                spacing: 8

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        required property var modelData
                        width: 18
                        height: 18

                        Image {
                            anchors.fill: parent
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.activate()
                            onPressAndHold: {
                                if (modelData.hasMenu)
                                    modelData.display(root, 0, 64)
                            }
                        }
                    }
                }
            }

            // CONTROL CENTRE BUTTON
            Rectangle {
                width: 36
                height: 36
                radius: 11
                color: triggerHover.hovered
                    ? "#45415F" : root.surface
                border.color: root.borderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "☷"
                    color: root.textMain
                    font.pixelSize: 21
                }

                HoverHandler {
                    id: triggerHover

                    onHoveredChanged: {
                        root.triggerHovered = hovered
                        if (hovered) {
                            closeTimer.stop()
                            root.menuVisible = true
                        } else {
                            root.scheduleClose()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.menuVisible = !root.menuVisible
                }
            }
        }
    }

    // =========================================
    // FLOATING CONTROL CENTRE
    // =========================================

    PopupWindow {
        id: controlCentre

        anchor.window: root
        anchor.rect.x: root.width - width - 12
            + (1 - root.controlCentreProgress) * (width + 24)
        anchor.rect.y: 72

        width: 410
        height: 660
        visible: root.menuVisible || root.controlCentreProgress > 0.001
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 26
            color: "#F0161A28"
            border.color: "#555B78"
            border.width: 1

            HoverHandler {
                onHoveredChanged: {
                    root.panelHovered = hovered
                    if (hovered)
                        closeTimer.stop()
                    else
                        root.scheduleClose()
                }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 20
                clip: true
                contentWidth: availableWidth

                Column {
                    width: parent.width
                    spacing: 16

                    // HEADER
                    Row {
                        width: parent.width
                        height: 44
                        spacing: 8

                        Column {
                            width: parent.width - 112
                            spacing: 4

                            Text {
                                text: "CONTROL CENTRE"
                                color: root.textMain
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: "OBSIDIAN  •  " + Qt.formatDateTime(
                                    new Date(), "dddd, dd MMMM"
                                )
                                color: root.textMuted
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 10
                            color: root.surfaceAlt

                            Text {
                                anchors.centerIn: parent
                                text: "⚙"
                                color: "#C4BDF5"
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.settingsVisible = true
                                    root.menuVisible = false
                                }
                            }
                        }

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 10
                            color: root.surfaceAlt

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.textMain
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.menuVisible = false
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.borderColor
                    }

                    // CONNECTIVITY
                    Text {
                        text: "CONNECTIVITY"
                        color: root.textMuted
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 86
                            radius: 16
                            color: Networking.wifiEnabled
                                ? root.accentSoft : root.surface
                            border.color: Networking.wifiEnabled
                                ? root.accent : root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 5

                                Text {
                                    text: "◉  Wi-Fi"
                                    color: root.textMain
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: Networking.wifiEnabled
                                        ? "Enabled" : "Disabled"
                                    color: root.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Networking.wifiEnabled =
                                    !Networking.wifiEnabled
                            }
                        }

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 86
                            radius: 16
                            color: Bluetooth.defaultAdapter?.enabled
                                ? root.accentSoft : root.surface
                            border.color: Bluetooth.defaultAdapter?.enabled
                                ? root.accent : root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 5

                                Text {
                                    text: "ᛒ  Bluetooth"
                                    color: root.textMain
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: Bluetooth.defaultAdapter?.enabled
                                        ? "Enabled" : "Disabled"
                                    color: root.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (Bluetooth.defaultAdapter)
                                        Bluetooth.defaultAdapter.enabled =
                                            !Bluetooth.defaultAdapter.enabled
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 86
                            radius: 16
                            color: root.surface
                            border.color: root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 5

                                Text {
                                    text: "⌁  Ethernet"
                                    color: root.textMain
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: root.deviceConnected("enp8s0")
                                        ? "Connected" : "Disconnected"
                                    color: root.textMuted
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 86
                            radius: 16
                            color: root.surface
                            border.color: root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 5

                                Text {
                                    text: "▣  Desktop"
                                    color: root.textMain
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: "Hyprland"
                                    color: root.textMuted
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    // AUDIO
                    Text {
                        text: "AUDIO"
                        color: root.textMuted
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 104
                        radius: 16
                        color: root.surface
                        border.color: root.borderColor

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Row {
                                width: parent.width

                                Text {
                                    text: "Output volume"
                                    color: root.textMain
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Item {
                                    width: 1
                                    height: 1
                                }

                                Text {
                                    text: Pipewire.defaultAudioSink?.audio?.muted
                                        ? "MUTED"
                                        : Math.round(
                                            (Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100
                                        ) + "%"
                                    color: "#C4BDF5"
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 9

                                Text {
                                    text: Pipewire.defaultAudioSink?.audio?.muted
                                        ? "×" : "♫"
                                    color: "#C4BDF5"
                                    font.pixelSize: 19
                                }

                                Slider {
                                    id: volumeSlider
                                    width: parent.width - 42
                                    from: 0
                                    to: 1
                                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0

                                    onMoved: {
                                        let audio =
                                            Pipewire.defaultAudioSink?.audio
                                        if (audio)
                                            audio.volume = value
                                    }
                                }
                            }

                            Text {
                                text: "Click the sound icon to mute or unmute"
                                color: root.textMuted
                                font.pixelSize: 9
                            }

                            MouseArea {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: 25
                                height: 25
                                onClicked: {
                                    let audio =
                                        Pipewire.defaultAudioSink?.audio
                                    if (audio)
                                        audio.muted = !audio.muted
                                }
                            }
                        }
                    }

                    // PERSONALIZATION
                    Text {
                        text: "PERSONALIZATION"
                        color: root.textMuted
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 54
                        radius: 15
                        color: root.accentSoft
                        border.color: root.accent

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: "✧"
                                color: "#C4BDF5"
                                font.pixelSize: 20
                            }

                            Text {
                                text: "Random wallpaper"
                                color: root.textMain
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached([
                                "/home/foi/.config/quickshell/wallpaper/wallpaperctl",
                                "random"
                            ])
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 14
                        color: root.surface
                        border.color: root.borderColor

                        Text {
                            anchors.centerIn: parent
                            text: "Open Settings  →"
                            color: root.textMain
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.settingsVisible = true
                                root.menuVisible = false
                            }
                        }
                    }

                    // POWER
                    Text {
                        text: "POWER"
                        color: root.textMuted
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: 7

                        Repeater {
                            model: [
                                { label: "LOCK", command: "lock" },
                                { label: "SLEEP", command: "suspend" },
                                { label: "LOGOUT", command: "logout" },
                                { label: "REBOOT", command: "reboot" },
                                { label: "OFF", command: "poweroff" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: (parent.width - 28) / 5
                                height: 42
                                radius: 9
                                color: root.surface
                                border.color: root.borderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: root.textMuted
                                    font.pixelSize: 8
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.runPowerCommand(
                                        modelData.command
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================
    // FULL SETTINGS WINDOW
    // =========================================

    PopupWindow {
        id: settingsWindow

        anchor.window: root
        anchor.rect.x: (root.width - width) / 2
        anchor.rect.y: 90

        width: 680
        height: 500
        visible: root.settingsVisible
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#F0191D2C"
            border.color: root.borderColor
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 18

                // SETTINGS SIDEBAR
                Rectangle {
                    width: 170
                    height: parent.height
                    radius: 15
                    color: "#252A3B"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 13
                        spacing: 8

                        Text {
                            text: "SETTINGS"
                            color: root.textMain
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: "OBSIDIAN DESKTOP"
                            color: root.textMuted
                            font.pixelSize: 9
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.borderColor
                        }

                        Repeater {
                            model: [
                                "Appearance",
                                "Network",
                                "Bluetooth",
                                "Audio",
                                "Wallpaper",
                                "Desktop",
                                "About"
                            ]

                            delegate: Rectangle {
                                required property string modelData

                                width: parent.width
                                height: 38
                                radius: 9
                                color: root.settingsPage === modelData
                                    ? root.accentSoft : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: root.settingsPage === modelData
                                        ? "#E8EAF5" : root.textMuted
                                    font.pixelSize: 11
                                    font.bold: root.settingsPage === modelData
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.settingsPage = modelData
                                }
                            }
                        }

                        Item {
                            width: 1
                            height: 1
                        }

                        Text {
                            text: "Obsidian • 0.1"
                            color: "#737C9A"
                            font.pixelSize: 9
                        }
                    }
                }

                // SETTINGS CONTENT
                Column {
                    width: parent.width - 188
                    height: parent.height
                    spacing: 14

                    Row {
                        width: parent.width
                        height: 38

                        Text {
                            text: root.settingsPage
                            color: root.textMain
                            font.pixelSize: 19
                            font.bold: true
                        }

                        Item {
                            width: 1
                            height: 1
                        }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 9
                            color: root.surface

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.textMain
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.settingsVisible = false
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.borderColor
                    }

                    // APPEARANCE PAGE
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: root.settingsPage === "Appearance"

                        Text {
                            text: "Colour palette"
                            color: root.textMain
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Row {
                            spacing: 9

                            Repeater {
                                model: [
                                    "#171B29",
                                    "#252A3B",
                                    "#8179C9",
                                    "#A6B8E8",
                                    "#D9DDF5"
                                ]

                                delegate: Rectangle {
                                    required property string modelData
                                    width: 48
                                    height: 48
                                    radius: 12
                                    color: modelData
                                    border.color: "#777F9F"
                                }
                            }
                        }

                        Text {
                            text: "Obsidian uses deep navy surfaces, lavender accents and icy-blue highlights."
                            color: root.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 58
                            radius: 12
                            color: root.surface
                            border.color: root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 4

                                Text {
                                    text: "Visual style"
                                    color: root.textMain
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    text: "Dark glass • Rounded corners • Soft borders"
                                    color: root.textMuted
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    
// =========================================
// NETWORK PAGE
// =========================================

Column {
    width: parent.width
    spacing: 12
    visible: root.settingsPage === "Network"

    Text {
        text: "Wi-Fi networks"
        color: root.textMain
        font.pixelSize: 13
        font.bold: true
    }

    Row {
        width: parent.width
        spacing: 10

        Text {
            text: Networking.wifiEnabled ? "Wi-Fi enabled" : "Wi-Fi disabled"
            color: root.textMuted
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        Switch {
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = checked
        }
    }

    Repeater {
        model: Networking.devices

        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 8

            Component.onCompleted: {
                if (modelData.name === "wlp7s0")
                    modelData.scannerEnabled = true
            }

            Repeater {
                model: modelData.networks

                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 60
                    radius: 12
                    color: modelData.connected
                        ? root.accentSoft : root.surface
                    border.color: modelData.connected
                        ? root.accent : root.borderColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Column {
                            width: 220
                            spacing: 5

                            Text {
                                text: modelData.name
                                color: root.textMain
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: modelData.connected
                                    ? "Connected"
                                    : modelData.known
                                        ? "Saved network"
                                        : "Available network"
                                color: root.textMuted
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            text: Math.round(
                                modelData.signalStrength * 100
                            ) + "%"
                            color: root.textMuted
                            font.pixelSize: 11
                        }

                        Text {
                            text: modelData.connected ? "✓" : "Connect"
                            color: root.textMain
                            font.pixelSize: 11

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (modelData.connected) {
                                        modelData.disconnect()
                                    } else if (modelData.known) {
                                        modelData.connect()
                                    } else {
                                        root.selectedWifiNetwork = modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    TextField {
        width: parent.width
        visible: root.selectedWifiNetwork !== null
        placeholderText: "Wi-Fi password"
        echoMode: TextInput.Password
        text: root.wifiPassword
        onTextChanged: root.wifiPassword = text
    }

    Button {
        visible: root.selectedWifiNetwork !== null
        text: "Connect"
        onClicked: {
            if (root.selectedWifiNetwork) {
                root.selectedWifiNetwork.connectWithPsk(
                    root.wifiPassword
                )
                root.selectedWifiNetwork = null
                root.wifiPassword = ""
            }
        }
    }
}

// =========================================
// BLUETOOTH PAGE
// =========================================

Column {
    width: parent.width
    spacing: 12
    visible: root.settingsPage === "Bluetooth"

    Text {
        text: "Bluetooth devices"
        color: root.textMain
        font.pixelSize: 13
        font.bold: true
    }

    Row {
        width: parent.width
        spacing: 10

        Text {
            text: Bluetooth.defaultAdapter?.enabled
                ? "Bluetooth enabled" : "Bluetooth disabled"
            color: root.textMuted
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        Switch {
            checked: Bluetooth.defaultAdapter?.enabled ?? false

            onToggled: {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = checked
            }
        }
    }

    Button {
        text: Bluetooth.defaultAdapter?.discovering
            ? "Stop scanning" : "Scan for devices"

        enabled: Bluetooth.defaultAdapter?.enabled ?? false

        onClicked: {
            if (Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.discovering =
                    !Bluetooth.defaultAdapter.discovering
            }
        }
    }

    Repeater {
        model: Bluetooth.defaultAdapter?.devices

        delegate: Rectangle {
            required property var modelData

            width: parent.width
            height: 76
            radius: 12
            color: root.surface
            border.color: modelData.connected
                ? root.accent : root.borderColor

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Column {
                    width: 175
                    spacing: 5

                    Text {
                        text: modelData.name
                        color: root.textMain
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        text: modelData.connected
                            ? "Connected"
                            : modelData.paired
                                ? "Paired"
                                : modelData.pairing
                                    ? "Pairing..."
                                    : "Available"
                        color: root.textMuted
                        font.pixelSize: 10
                    }
                }

                Button {
                    text: modelData.connected
                        ? "Disconnect"
                        : modelData.paired
                            ? "Connect" : "Pair"

                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect()
                        else if (modelData.paired)
                            modelData.connect()
                        else
                            modelData.pair()
                    }
                }
            }
        }
    }
}


                         
// AUDIO PAGE
Column {
    width: parent.width
    spacing: 10
    visible: root.settingsPage === "Audio"

    Text {
        text: "OUTPUT DEVICES"
        color: root.textMuted
        font.pixelSize: 10
        font.bold: true
    }

    Repeater {
        model: Pipewire.nodes

        delegate: Rectangle {
            required property var modelData

            visible: modelData.audio !== null
                && !modelData.isStream
                && modelData.isSink

            width: parent.width
            height: visible ? 54 : 0
            radius: 11
            color: modelData === Pipewire.defaultAudioSink
                ? root.accentSoft : root.surface
            border.color: modelData === Pipewire.defaultAudioSink
                ? root.accent : root.borderColor

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                spacing: 4

                Text {
                    text: modelData.nickname
                        || modelData.description
                        || modelData.name
                    color: root.textMain
                    font.pixelSize: 11
                    font.bold: true
                    width: 350
                    elide: Text.ElideRight
                }

                Text {
                    text: modelData === Pipewire.defaultAudioSink
                        ? "● Default output"
                        : "Click to use this output"
                    color: modelData === Pipewire.defaultAudioSink
                        ? "#C4BDF5" : root.textMuted
                    font.pixelSize: 9
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked:
                    Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    Text {
        text: "INPUT DEVICES"
        color: root.textMuted
        font.pixelSize: 10
        font.bold: true
    }

    Repeater {
        model: Pipewire.nodes

        delegate: Rectangle {
            required property var modelData

            visible: modelData.audio !== null
                && !modelData.isStream
                && !modelData.isSink

            width: parent.width
            height: visible ? 54 : 0
            radius: 11
            color: modelData === Pipewire.defaultAudioSource
                ? root.accentSoft : root.surface
            border.color: modelData === Pipewire.defaultAudioSource
                ? root.accent : root.borderColor

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                spacing: 4

                Text {
                    text: modelData.nickname
                        || modelData.description
                        || modelData.name
                    color: root.textMain
                    font.pixelSize: 11
                    font.bold: true
                    width: 350
                    elide: Text.ElideRight
                }

                Text {
                    text: modelData === Pipewire.defaultAudioSource
                        ? "● Default input"
                        : "Click to use this microphone"
                    color: modelData === Pipewire.defaultAudioSource
                        ? "#C4BDF5" : root.textMuted
                    font.pixelSize: 9
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked:
                    Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    Text {
        text: "OUTPUT VOLUME"
        color: root.textMuted
        font.pixelSize: 10
        font.bold: true
    }

    Slider {
        width: parent.width
        from: 0
        to: 1
        value: Pipewire.defaultAudioSink?.audio?.volume ?? 0

        onMoved: {
            let audio = Pipewire.defaultAudioSink?.audio
            if (audio)
                audio.volume = value
        }
    }

    Text {
        text: "INPUT VOLUME"
        color: root.textMuted
        font.pixelSize: 10
        font.bold: true
    }

    Slider {
        width: parent.width
        from: 0
        to: 1
        value: Pipewire.defaultAudioSource?.audio?.volume ?? 0

        onMoved: {
            let audio = Pipewire.defaultAudioSource?.audio
            if (audio)
                audio.volume = value
        }
    }
}


                    // WALLPAPER PAGE
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: root.settingsPage === "Wallpaper"

                        Text {
                            text: "Wallpaper controls"
                            color: root.textMain
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 12
                            color: root.accentSoft
                            border.color: root.accent

                            Text {
                                anchors.centerIn: parent
                                text: "✧   Set random wallpaper"
                                color: root.textMain
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached([
                                    "/home/foi/.config/quickshell/wallpaper/wallpaperctl",
                                    "random"
                                ])
                            }
                        }

                        Text {
                            text: "Your existing wallpaper gallery remains separate."
                            color: root.textMuted
                            font.pixelSize: 10
                        }
                    }

                    // DESKTOP PAGE
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: root.settingsPage === "Desktop"

                        Text {
                            text: "Desktop environment"
                            color: root.textMain
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 65
                            radius: 12
                            color: root.surface
                            border.color: root.borderColor

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 13
                                spacing: 5

                                Text {
                                    text: "Hyprland"
                                    color: root.textMain
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    text: "Wayland compositor"
                                    color: root.textMuted
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    // ABOUT PAGE
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: root.settingsPage === "About"

                        Text {
                            text: "Obsidian Shell"
                            color: root.textMain
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: "A custom Quickshell desktop interface for Hyprland."
                            color: root.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            text: "Theme: Deep navy / Lavender / Ice blue"
                            color: root.textMuted
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}

