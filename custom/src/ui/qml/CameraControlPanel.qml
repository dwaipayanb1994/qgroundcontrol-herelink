/****************************************************************************
 *
 * (c) 2024 Custom QGroundControl Development Team
 *
 * Camera control panel providing one-touch access to all protocol commands.
 *
 ****************************************************************************/

import QtQuick 2                // Up button
                QGCButton {
                    text: "▲"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(ScreenTools.defaultFontPixelWidth * 8, parent.width * 0.3)
                    onClicked: {
                        var cmd = controller.previewCommand("PTZ_UP")
                        console.log("Sending: " + cmd)
                        controller.sendCommand("PTZ_UP")
                    }
                } QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

import Custom.Camera 1.0

/// Topotek Camera Control Panel for Instrument Panel PageView
Column {
    id: root
    width: pageWidth
    spacing: ScreenTools.defaultFontPixelHeight * 0.5

    property bool showSettingsIcon: false

    readonly property int contentMargin: ScreenTools.defaultFontPixelWidth
    readonly property color accent: "#63ace5"
    readonly property color headerBackground: "#1c2333"
    readonly property color successColor: "#2f9e44"
    readonly property color dangerColor: "#c92a2a"

    property string serialPortField: ""
    property int serialBaudField: 115200
    property string udpAddressField: "192.168.31.200"
    property int udpRemotePortField: 20000
    property int udpLocalPortField: 9004

    readonly property QGCPalette palette: QGCPalette {
        colorGroupEnabled: true
    }

    CameraController {
        id: controller
    }

    function sendCommand(command, manualData, optionData) {
        var params = {}
        if (optionData !== undefined && optionData !== null && optionData !== "") {
            params.optionData = optionData
        }
        if (manualData !== undefined && manualData !== null && manualData !== "") {
            params.data = manualData
        }
        if (!controller.sendCommandWithParameters(command.key, params)) {
            console.warn("Command failed:", controller.lastError)
        }
    }

    // ========== Header Section ==========
    Rectangle {
        width: parent.width
        height: ScreenTools.defaultFontPixelHeight * 12
        color: headerBackground
        radius: contentMargin * 0.5
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: contentMargin * 2
            spacing: contentMargin

            QGCLabel {
                text: "Topotek Camera Control"
                font.pointSize: ScreenTools.largeFontPointSize
                font.bold: true
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            QGCLabel {
                text: qsTr("Serial: %1  |  UDP: %2")
                      .arg(controller.serialConnected ? "Connected" : "Disconnected")
                      .arg(controller.udpConnected ? "Bound" : "Idle")
                font.pointSize: ScreenTools.defaultFontPointSize
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            QGCComboBox {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
                model: [
                    { text: qsTr("Auto"), value: CameraController.Auto },
                    { text: qsTr("Serial Only"), value: CameraController.SerialOnly },
                    { text: qsTr("UDP Only"), value: CameraController.UdpOnly }
                ]
                textRole: "text"
                Component.onCompleted: {
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].value === controller.activeTransportMode) {
                            currentIndex = i
                            break
                        }
                    }
                }
                onActivated: controller.activeTransportMode = model[index].value
                displayText: qsTr("Mode: %1").arg(model[currentIndex].text)
            }
        }
    }

    // ========== Serial Link Section ==========
    Rectangle {
        width: parent.width
        height: serialColumn.height + contentMargin * 4
        color: palette.windowShade
        radius: contentMargin * 0.5

        Column {
            id: serialColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: contentMargin * 2
            spacing: contentMargin

            QGCLabel {
                width: parent.width
                text: qsTr("Serial Link Configuration")
                font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                font.bold: true
            }

            QGCLabel {
                text: qsTr("Port Name:")
            }

            QGCTextField {
                width: parent.width
                placeholderText: qsTr("e.g. /dev/ttyUSB0 or COM3")
                text: serialPortField
                onTextChanged: serialPortField = text
            }

            QGCLabel {
                text: qsTr("Baud Rate:")
            }

            QGCTextField {
                width: parent.width
                placeholderText: "115200"
                text: serialBaudField.toString()
                inputMethodHints: Qt.ImhDigitsOnly
                onTextChanged: {
                    var val = parseInt(text)
                    serialBaudField = isNaN(val) ? 115200 : val
                }
            }

            Row {
                width: parent.width
                spacing: contentMargin

                QGCButton {
                    text: controller.serialConnected ? qsTr("Disconnect") : qsTr("Connect")
                    width: (parent.width - contentMargin) / 2
                    onClicked: {
                        if (controller.serialConnected) {
                            controller.disconnectSerial()
                        } else {
                            if (!controller.connectSerial(serialPortField, serialBaudField)) {
                                console.warn("Serial connection failed:", controller.lastError)
                            }
                        }
                    }
                }

                QGCButton {
                    text: qsTr("Send Test")
                    width: (parent.width - contentMargin) / 2
                    enabled: controller.serialConnected
                    onClicked: controller.sendTestCommand(CameraController.SerialOnly)
                }
            }
        }
    }

    // ========== UDP Link Section ==========
    Rectangle {
        width: parent.width
        height: udpColumn.height + contentMargin * 4
        color: palette.windowShade
        radius: contentMargin * 0.5

        Column {
            id: udpColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: contentMargin * 2
            spacing: contentMargin

            QGCLabel {
                width: parent.width
                text: qsTr("UDP Link Configuration")
                font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                font.bold: true
            }

            QGCLabel {
                text: qsTr("Remote IP Address:")
            }

            QGCTextField {
                width: parent.width
                placeholderText: "192.168.31.200"
                text: udpAddressField
                onTextChanged: udpAddressField = text
            }

            QGCLabel {
                text: qsTr("Remote Port:")
            }

            QGCTextField {
                width: parent.width
                placeholderText: "20000"
                text: udpRemotePortField.toString()
                inputMethodHints: Qt.ImhDigitsOnly
                onTextChanged: {
                    var val = parseInt(text)
                    udpRemotePortField = isNaN(val) ? 20000 : val
                }
            }

            QGCLabel {
                text: qsTr("Local Port:")
            }

            QGCTextField {
                width: parent.width
                placeholderText: "9004"
                text: udpLocalPortField.toString()
                inputMethodHints: Qt.ImhDigitsOnly
                onTextChanged: {
                    var val = parseInt(text)
                    udpLocalPortField = isNaN(val) ? 9004 : val
                }
            }

            Row {
                width: parent.width
                spacing: contentMargin

                QGCButton {
                    text: controller.udpConnected ? qsTr("Unbind") : qsTr("Bind")
                    width: (parent.width - contentMargin) / 2
                    onClicked: {
                        if (controller.udpConnected) {
                            controller.disconnectUdp()
                        } else {
                            if (!controller.connectUdp(udpAddressField, udpRemotePortField, udpLocalPortField)) {
                                console.warn("UDP bind failed:", controller.lastError)
                            }
                        }
                    }
                }

                QGCButton {
                    text: qsTr("Send Test")
                    width: (parent.width - contentMargin) / 2
                    enabled: controller.udpConnected
                    onClicked: controller.sendTestCommand(CameraController.UdpOnly)
                }
            }
        }
    }

    // ========== Camera Controls ==========
    Rectangle {
        width: parent.width
        height: controlsColumn.height + contentMargin * 4
        color: palette.windowShade
        radius: contentMargin * 0.5

        Column {
            id: controlsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: contentMargin * 2
            spacing: contentMargin * 2

            QGCLabel {
                width: parent.width
                text: qsTr("Camera Controls")
                font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                font.bold: true
            }

            // Gimbal Direction Controls
            Column {
                width: parent.width
                spacing: contentMargin

                QGCLabel {
                    text: qsTr("Gimbal Direction")
                    font.bold: true
                }

                // Up button
                QGCButton {
                    text: "▲ Up"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ScreenTools.defaultFontPixelWidth * 15
                    onClicked: {
                        console.log("Gimbal Up")
                        // Add your gimbal up command here
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: contentMargin

                    // Left button
                    QGCButton {
                        text: "◀ Left"
                        width: ScreenTools.defaultFontPixelWidth * 15
                        onClicked: {
                            console.log("Gimbal Left")
                            // Add your gimbal left command here
                        }
                    }

                    // Center button
                    QGCButton {
                        text: "⬤ Center"
                        width: ScreenTools.defaultFontPixelWidth * 15
                        onClicked: {
                            console.log("Gimbal Center")
                            // Add your gimbal center command here
                        }
                    }

                    // Right button
                    QGCButton {
                        text: "▶ Right"
                        width: ScreenTools.defaultFontPixelWidth * 15
                        onClicked: {
                            console.log("Gimbal Right")
                            // Add your gimbal right command here
                        }
                    }
                }

                // Down button
                QGCButton {
                    text: "▼ Down"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ScreenTools.defaultFontPixelWidth * 15
                    onClicked: {
                        console.log("Gimbal Down")
                        // Add your gimbal down command here
                    }
                }
            }

            // Zoom Controls
            Row {
                width: parent.width
                spacing: contentMargin

                QGCLabel {
                    text: qsTr("Zoom:")
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.2
                }

                QGCButton {
                    text: "− Out"
                    width: (parent.width - parent.spacing * 2 - parent.children[0].width) / 2
                    onClicked: {
                        console.log("Zoom Out")
                        // Add your zoom out command here
                    }
                }

                QGCButton {
                    text: "+ In"
                    width: (parent.width - parent.spacing * 2 - parent.children[0].width) / 2
                    onClicked: {
                        console.log("Zoom In")
                        // Add your zoom in command here
                    }
                }
            }

            // Focus Controls
            Row {
                width: parent.width
                spacing: contentMargin

                QGCLabel {
                    text: qsTr("Focus:")
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.2
                }

                QGCButton {
                    text: "◀ Near"
                    width: (parent.width - parent.spacing * 3 - parent.children[0].width) / 3
                    onClicked: {
                        console.log("Focus Near")
                        // Add your focus near command here
                    }
                }

                QGCButton {
                    text: "⦿ Auto"
                    width: (parent.width - parent.spacing * 3 - parent.children[0].width) / 3
                    onClicked: {
                        console.log("Auto Focus")
                        // Add your auto focus command here
                    }
                }

                QGCButton {
                    text: "▶ Far"
                    width: (parent.width - parent.spacing * 3 - parent.children[0].width) / 3
                    onClicked: {
                        console.log("Focus Far")
                        // Add your focus far command here
                    }
                }
            }
        }
    }

    // ========== Traffic Log Section ==========
    Rectangle {
        width: parent.width
        height: ScreenTools.defaultFontPixelHeight * 20
        color: palette.windowShade
        radius: contentMargin * 0.5

        Column {
            anchors.fill: parent
            anchors.margins: contentMargin * 2
            spacing: contentMargin

            Row {
                width: parent.width
                spacing: contentMargin

                QGCLabel {
                    text: qsTr("Traffic Log (%1 entries)").arg(controller.trafficLog ? controller.trafficLog.length : 0)
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                    font.bold: true
                    width: parent.width - clearBtn.width - contentMargin
                }

                QGCButton {
                    id: clearBtn
                    text: qsTr("Clear")
                    onClicked: controller.clearTrafficLog()
                }
            }

            ListView {
                width: parent.width
                height: parent.height - parent.spacing - clearBtn.height - contentMargin * 2
                clip: true
                model: controller.trafficLog ? controller.trafficLog : []

                delegate: QGCLabel {
                    width: parent.width
                    text: modelData
                    font.family: "Courier"
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ========== Frame Preview Section ==========
    Rectangle {
        width: parent.width
        height: ScreenTools.defaultFontPixelHeight * 15
        color: palette.windowShade
        radius: contentMargin * 0.5

        Column {
            anchors.fill: parent
            anchors.margins: contentMargin * 2
            spacing: contentMargin

            QGCLabel {
                text: qsTr("Frame Preview")
                font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: parent.height - parent.spacing - contentMargin * 2
                color: "#1a1a1a"
                radius: 3

                QGCLabel {
                    anchors.centerIn: parent
                    text: (controller.lastFrameHex && controller.lastFrameHex.length > 0)
                          ? controller.lastFrameHex 
                          : qsTr("No frame received yet")
                    font.family: "Courier"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: "#00ff00"
                    wrapMode: Text.WrapAnywhere
                    width: parent.width - contentMargin * 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
