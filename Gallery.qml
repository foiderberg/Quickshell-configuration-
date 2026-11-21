
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PanelWindow {
    id: gallery

    visible: true
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string controller: Quickshell.env("HOME") + "/.config/quickshell/wallpaper/wallpaperctl"
    property string selectedWallpaper: ""
    property var wallpapers: []
    property var favourites: []

    function refresh() {
        listProcess.running = true
        favouritesProcess.running = true
    }

    function applyWallpaper(path) {
        selectedWallpaper = path
        setProcess.command = [controller, "set", path]
        setProcess.running = true
    }

    Component.onCompleted: refresh()

    Process {
        id: listProcess
        command: [gallery.controller, "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                gallery.wallpapers = text.trim().length
                    ? text.trim().split("\n") : []

                if (gallery.selectedWallpaper === "")
                    gallery.selectedWallpaper = gallery.wallpapers[0] || ""
            }
        }
    }

    Process {
        id: favouritesProcess
        command: [gallery.controller, "favourites"]

        stdout: StdioCollector {
            onStreamFinished: {
                gallery.favourites = text.trim().length
                    ? text.trim().split("\n") : []
            }
        }
    }

    Process {
        id: setProcess
        command: []
    }

    Process {
        id: randomProcess
        command: [gallery.controller, "random"]
        onExited: gallery.refresh()
    }

    Process {
        id: nextProcess
        command: [gallery.controller, "next"]
        onExited: gallery.refresh()
    }

    Process {
        id: previousProcess
        command: [gallery.controller, "previous"]
        onExited: gallery.refresh()
    }

    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: gallery.visible = false
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1200)
        height: Math.min(parent.height - 80, 760)
        radius: 20
        color: "#151515"
        border.color: "#383838"
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                mouse.accepted = false
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 20

            Row {
                width: parent.width

                Column {
                    spacing: 4

                    Text {
                        text: "OBSIDIAN"
                        color: "#eeeeee"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                        text: "WALLPAPER COLLECTION"
                        color: "#777777"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }
                }

                Item { width: 1; height: 1 }

                Text {
                    text: gallery.wallpapers.length + " WALLPAPERS"
                    color: "#999999"
                    font.pixelSize: 11
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 9
                    color: "#292929"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "white"
                        font.pixelSize: 21
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: gallery.visible = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#303030"
            }

            Row {
                width: parent.width
                height: parent.height - 95
                spacing: 22

                Column {
                    width: parent.width * 0.53
                    height: parent.height
                    spacing: 12

                    Rectangle {
                        width: parent.width
                        height: parent.height - 110
                        radius: 14
                        color: "#222222"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: gallery.selectedWallpaper
                                ? "file://" + gallery.selectedWallpaper : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !gallery.selectedWallpaper
                            text: "NO WALLPAPER SELECTED"
                            color: "#777777"
                        }
                    }

                    Text {
                        width: parent.width
                        text: gallery.selectedWallpaper.split("/").pop()
                        color: "#aaaaaa"
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "PREVIOUS", action: "previous" },
                                { label: "RANDOM", action: "random" },
                                { label: "NEXT", action: "next" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 105
                                height: 38
                                radius: 9
                                color: "#292929"
                                border.color: "#444444"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: "#eeeeee"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData.action === "random")
                                            randomProcess.running = true
                                        else if (modelData.action === "next")
                                            nextProcess.running = true
                                        else
                                            previousProcess.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width * 0.47 - 22
                    height: parent.height
                    spacing: 12

                    Text {
                        text: "YOUR WALLPAPERS"
                        color: "#eeeeee"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    GridView {
                        width: parent.width
                        height: parent.height - 45
                        clip: true
                        cellWidth: width / 2
                        cellHeight: 130
                        model: gallery.wallpapers

                        delegate: Rectangle {
                            required property string modelData
                            required property int index

                            width: GridView.view.cellWidth - 9
                            height: 118
                            radius: 10
                            color: gallery.selectedWallpaper === modelData
                                ? "#393939" : "#222222"
                            border.color: gallery.selectedWallpaper === modelData
                                ? "#aaaaaa" : "#333333"
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "#000000"
                                opacity: 0.25
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 9
                                text: modelData.split("/").pop()
                                color: "white"
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 9
                                text: gallery.favourites.indexOf(modelData) !== -1
                                    ? "★" : ""
                                color: "#ffffff"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    gallery.selectedWallpaper = modelData
                                    gallery.applyWallpaper(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

