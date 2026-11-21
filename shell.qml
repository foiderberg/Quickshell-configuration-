
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    NotificationServer {
        id: notificationServer

        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true

            console.log("OBSIDIAN NOTIFICATION:",
                notification.appName,
                notification.summary)
        }
    }

    PanelWindow {
        id: popupWindow

        anchors {
            top: true
            right: true
        }

        margins {
            top: 24
            right: 24
        }

        implicitWidth: 420
        implicitHeight: 800

        color: "transparent"
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay

        Column {
            anchors {
                top: parent.top
                right: parent.right
            }

            width: 390
            spacing: 12

            Repeater {
                model: notificationServer.trackedNotifications

                delegate: Rectangle {
    id: card

    property real slideOffset: 32
    opacity: 0

    transform: Translate {
        x: card.slideOffset
    }

    Component.onCompleted: enterAnimation.start()

    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: card
            property: "slideOffset"
            from: 32
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 220
        }
    }
                    required property var modelData
                    property var notification: modelData

                    width: 390
                    height: notification.body ? 122 : 100

                    radius: 16
                    color: "#E6111419"

                    border.width: 1
                    border.color: "#454B55"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 13

                        Image {
                            width: 36
                            height: 36

                            source: Quickshell.iconPath(
                                notification.appIcon || "dialog-information"
                            )

                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            width: 260
                            spacing: 6

                            Text {
                                width: parent.width
                                text: notification.appName || "Notification"
                                color: "#929AA7"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: notification.summary || ""
                                color: "#F0F0F2"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: notification.body || ""
                                color: "#A9AFB9"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: "×"
                            color: "#858C98"
                            font.pixelSize: 20

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: notification.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}

