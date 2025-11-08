/*
 * (c) 2024 Custom QGroundControl Development Team
 * Camera control panel providing one-touch access to all protocol commands.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.0

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

import Custom.Camera 1.0

Rectangle {
    id: root
    color: palette.window
    radius: ScreenTools.defaultFontPixelWidth * 0.5

    readonly property color accent: "#63ace5"
    readonly property color headerBackground: "#1c2333"
    readonly property color successColor: "#2f9e44"
    readonly property color dangerColor: "#c92a2a"

    property alias controller: controller
    property string serialPortField: ""
    property int serialBaudField: 115200
    property string udpAddressField: "192.168.31.200"
    property int udpRemotePortField: 20000
    property int udpLocalPortField: 9004

    readonly property QGCPalette palette: QGCPalette {
        paletteType: QGCPalette.Custom
        colorGroup: QGroundControl.globalPalette.colorGroup
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
            errorBanner.showError(controller.lastError)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth

        // Header & transport summary
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
            radius: ScreenTools.defaultFontPixelWidth * 0.3
            color: headerBackground
            border.color: accent
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelWidth

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel {
                        text: qsTr("Topotek Camera Control")
                        font.pixelSize: ScreenTools.largeFontPixelSize
                        font.bold: true
                        color: "white"
                    }
                    QGCLabel {
                        text: qsTr("Serial: %1  |  UDP: %2")
                              .arg(controller.serialConnected ? qsTr("Connected") : qsTr("Disconnected"))
                              .arg(controller.udpConnected ? qsTr("Bound") : qsTr("Idle"))
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                        color: "white"
                    }
                }

                QGCComboBox {
                    id: transportModeCombo
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                    model: [
                        { text: qsTr("Auto"), value: CameraController.Auto },
                        { text: qsTr("Serial Only"), value: CameraController.SerialOnly },
                        { text: qsTr("UDP Only"), value: CameraController.UdpOnly }
                    ]
                    textRole: "text"
                    valueRole: "value"
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

        // Transport configuration cards
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 18
            spacing: ScreenTools.defaultFontPixelWidth

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ScreenTools.defaultFontPixelWidth * 0.3
                color: palette.windowShade
                border.color: palette.windowShadeDark

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Serial Link")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCTextField {
                            Layout.fillWidth: true
                            placeholderText: qsTr("Port name (e.g. ttyUSB0)")
                            text: serialPortField
                            onTextChanged: serialPortField = text
                        }

                        QGCTextField {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                            placeholderText: qsTr("Baud")
                            text: serialBaudField.toString()
                            inputMethodHints: Qt.ImhDigitsOnly
                            onTextChanged: {
                                serialBaudField = parseInt(text)
                                if (isNaN(serialBaudField)) {
                                    serialBaudField = 115200
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                            enabled: !controller.serialConnected
                            text: qsTr("Connect Serial")
                            onClicked: {
                                if (!controller.connectSerial(serialPortField, serialBaudField)) {
                                    errorBanner.showError(controller.lastError)
                                }
                            }
                        }

                        QGCButton {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                            enabled: controller.serialConnected
                            text: qsTr("Disconnect")
                            onClicked: controller.disconnectSerial()
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            color: controller.serialConnected ? successColor : dangerColor
                            text: controller.serialConnected ? qsTr("Connected") : qsTr("Disconnected")
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ScreenTools.defaultFontPixelWidth * 0.3
                color: palette.windowShade
                border.color: palette.windowShadeDark

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("UDP Link")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
                        font.bold: true
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelWidth
                        Layout.fillWidth: true

                        QGCLabel { text: qsTr("Device IP") }
                        QGCTextField {
                            Layout.fillWidth: true
                            text: udpAddressField
                            onTextChanged: udpAddressField = text
                        }

                        QGCLabel { text: qsTr("Device Port") }
                        QGCTextField {
                            Layout.fillWidth: true
                            text: udpRemotePortField.toString()
                            inputMethodHints: Qt.ImhDigitsOnly
                            onTextChanged: {
                                udpRemotePortField = parseInt(text)
                                if (isNaN(udpRemotePortField)) udpRemotePortField = 0
                            }
                        }

                        QGCLabel { text: qsTr("Local Port") }
                        QGCTextField {
                            Layout.fillWidth: true
                            text: udpLocalPortField.toString()
                            inputMethodHints: Qt.ImhDigitsOnly
                            onTextChanged: {
                                udpLocalPortField = parseInt(text)
                                if (isNaN(udpLocalPortField)) udpLocalPortField = 0
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                            enabled: !controller.udpConnected
                            text: qsTr("Bind UDP")
                            onClicked: {
                                if (!controller.configureUdp(udpAddressField, udpRemotePortField, udpLocalPortField)) {
                                    errorBanner.showError(controller.lastError)
                                }
                            }
                        }

                        QGCButton {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                            enabled: controller.udpConnected
                            text: qsTr("Close")
                            onClicked: controller.disconnectUdp()
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            color: controller.udpConnected ? successColor : dangerColor
                            text: controller.udpConnected ? qsTr("Bound") : qsTr("Idle")
                        }
                    }
                }
            }
        }

        // Command list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.window
            radius: ScreenTools.defaultFontPixelWidth * 0.3
            border.color: palette.windowShadeDark

            ScrollView {
                anchors.fill: parent
                clip: true

                Column {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelWidth
                    padding: ScreenTools.defaultFontPixelWidth

                    Repeater {
                        model: controller.commandCatalog
                        delegate: Rectangle {
                            width: parent.width
                            color: palette.windowShade
                            radius: ScreenTools.defaultFontPixelWidth * 0.3
                            border.color: palette.windowShadeDark

                            property var category: modelData

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                RowLayout {
                                    Layout.fillWidth: true
                                    QGCLabel {
                                        text: category.name + qsTr(" (%1)").arg(category.commands ? category.commands.length : 0)
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    QGCButton {
                                        text: qsTr("Collapse")
                                        checkable: true
                                        checked: true
                                        onToggled: commandColumn.visible = checked
                                    }
                                }

                                ColumnLayout {
                                    id: commandColumn
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                    Repeater {
                                        model: category.commands
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            color: palette.window
                                            radius: ScreenTools.defaultFontPixelWidth * 0.25
                                            border.color: palette.windowShadeDark

                                            property var command: modelData
                                            property string manualData: command.defaultData || ""
                                            property string selectedOption: command.defaultData || ""

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: ScreenTools.defaultFontPixelWidth
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.25

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: ScreenTools.defaultFontPixelWidth

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        text: command.label
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.05
                                                        font.bold: true
                                                        wrapMode: Text.WordWrap
                                                    }

                                                    QGCButton {
                                                        text: qsTr("Send")
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                                                        onClicked: sendCommand(command,
                                                                               command.dataEditable ? manualData : "",
                                                                               command.hasOptions ? selectedOption : "")
                                                    }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    visible: (command.dataEditable && command.hasOptions) || command.dataEditable || command.hasOptions
                                                    spacing: ScreenTools.defaultFontPixelWidth

                                                    QGCComboBox {
                                                        id: optionCombo
                                                        visible: command.hasOptions
                                                        Layout.fillWidth: command.dataEditable ? false : true
                                                        Layout.preferredWidth: command.dataEditable ? ScreenTools.defaultFontPixelWidth * 15 : undefined
                                                        model: command.options
                                                        textRole: "label"
                                                        valueRole: "data"
                                                        Component.onCompleted: {
                                                            if (!command.hasOptions || !command.options) {
                                                                return
                                                            }
                                                            for (var i = 0; i < command.options.length; i++) {
                                                                if (command.options[i].data === command.defaultData) {
                                                                    currentIndex = i
                                                                    selectedOption = command.options[i].data
                                                                    break
                                                                }
                                                            }
                                                            if (currentIndex < 0 && command.options.length > 0) {
                                                                currentIndex = 0
                                                                selectedOption = command.options[0].data
                                                            }
                                                        }
                                                        onActivated: {
                                                            if (command.hasOptions && command.options && command.options.length > index) {
                                                                selectedOption = command.options[index].data
                                                            }
                                                        }
                                                        onCurrentIndexChanged: {
                                                            if (command.hasOptions && currentIndex >= 0 && command.options && command.options.length > currentIndex) {
                                                                selectedOption = command.options[currentIndex].data
                                                            }
                                                        }
                                                    }

                                                    QGCTextField {
                                                        visible: command.dataEditable
                                                        Layout.fillWidth: true
                                                        placeholderText: command.dataHint || qsTr("Data payload")
                                                        text: manualData
                                                        onTextChanged: manualData = text
                                                    }
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    visible: command.description && command.description.length
                                                    text: command.description
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                                                    wrapMode: Text.WordWrap
                                                    color: palette.buttonText
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    font.pixelSize: ScreenTools.smallFontPixelSize
                                                    color: palette.textFieldText
                                                    text: qsTr("Key: %1  •  Identifier: %2  •  Default: %3")
                                                            .arg(command.key)
                                                            .arg(command.identifier)
                                                            .arg(command.defaultData || qsTr("<none>"))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Telemetry & log area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 18
            color: palette.windowShade
            radius: ScreenTools.defaultFontPixelWidth * 0.3
            border.color: palette.windowShadeDark

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelWidth

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    QGCLabel {
                        text: qsTr("Traffic Log")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                        font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: controller.logEntries
                        clip: true
                        delegate: QGCLabel {
                            text: modelData
                            wrapMode: Text.NoWrap
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Component.onCompleted: positionViewAtEnd()
                        onCountChanged: positionViewAtEnd()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        QGCButton {
                            text: qsTr("Clear Log")
                            onClicked: controller.clearLog()
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 30
                    Layout.fillHeight: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Last Frame Preview")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        color: palette.window
                        border.color: palette.windowShadeDark

                        QGCLabel {
                            anchors.centerIn: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                            wrapMode: Text.WrapAnywhere
                            horizontalAlignment: Text.AlignHCenter
                            text: controller.lastFrame.length ? controller.lastFrame : qsTr("No frame yet")
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: controller.lastError
                        color: palette.colorOrange
                        visible: controller.lastError.length > 0
                    }
                }
            }
        }
    }

    // Error banner overlay
    Popup {
        id: errorBanner
        x: root.width / 2 - width / 2
        y: ScreenTools.defaultFontPixelWidth
        modal: false
        focus: false
        padding: ScreenTools.defaultFontPixelWidth
        background: Rectangle {
            color: "#c92a2a"
            radius: ScreenTools.defaultFontPixelWidth * 0.3
        }

        function showError(message) {
            bannerText.text = message
            if (!visible) {
                open()
            }
            hideTimer.restart()
        }

        Column {
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel {
                id: bannerText
                color: "white"
                wrapMode: Text.WordWrap
                width: ScreenTools.defaultFontPixelWidth * 40
            }
            QGCButton {
                text: qsTr("Dismiss")
                onClicked: errorBanner.close()
            }
        }

        Timer {
            id: hideTimer
            interval: 5000
            onTriggered: errorBanner.close()
        }
    }

    DropShadow {
        anchors.fill: parent
        source: parent
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8
        samples: 17
        color: "#40000000"
    }
}
