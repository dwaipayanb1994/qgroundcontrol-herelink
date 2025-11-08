/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

/// Industrial-style UTG (Ultrasonic Thickness Gauge) Control Panel
Rectangle {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var utgCommunication: vehicle ? vehicle.utgCommunication : null

    // Debug component loading
    Component.onCompleted: {
        console.log("=== UTG PANEL DEBUG ===")
        console.log("Panel loaded successfully")
        console.log("vehicle:", vehicle)
        console.log("utgCommunication:", utgCommunication)
        console.log("QGroundControl.multiVehicleManager:", QGroundControl.multiVehicleManager)
        console.log("activeVehicle:", QGroundControl.multiVehicleManager.activeVehicle)
    }
    
    // Industrial color scheme
    readonly property color primaryColor: "#2C3E50"      // Dark blue-gray
    readonly property color secondaryColor: "#34495E"    // Lighter blue-gray  
    readonly property color accentColor: "#3498DB"       // Bright blue
    readonly property color successColor: "#27AE60"      // Green
    readonly property color warningColor: "#F39C12"      // Orange
    readonly property color errorColor: "#E74C3C"        // Red
    readonly property color textColor: "#ECF0F1"         // Light gray
    readonly property color backgroundColor: "#1A252F"    // Very dark blue
    
    color: backgroundColor
    radius: ScreenTools.defaultFontPixelWidth * 0.5
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth * 0.5
        
        // Header with title and connection status
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
            color: primaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: accentColor
            border.width: 1

            Component.onCompleted: {
                console.log("=== HEADER RECTANGLE DEBUG ===")
                console.log("Header rectangle created")
                console.log("Width:", width, "Height:", height)
                console.log("Visible:", visible)
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5

                Component.onCompleted: {
                    console.log("=== ROW LAYOUT DEBUG ===")
                    console.log("RowLayout created")
                    console.log("Children count:", children.length)
                    console.log("Width:", width, "Height:", height)
                }
                
                QGCLabel {
                    text: qsTr("UTG THICKNESS GAUGE")
                    font.bold: true
                    font.pixelSize: ScreenTools.largeFontPixelSize
                    color: textColor
                    Layout.fillWidth: true
                }
                
                // Connection status indicator
                Rectangle {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    color: utgCommunication && utgCommunication.connected ? successColor : errorColor
                    radius: ScreenTools.defaultFontPixelWidth * 0.25
                    
                    QGCLabel {
                        anchors.centerIn: parent
                        text: utgCommunication && utgCommunication.connected ? qsTr("CONNECTED") : qsTr("DISCONNECTED")
                        font.bold: true
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        color: "white"
                    }
                    
                    // Pulsing animation for disconnected state
                    SequentialAnimation on opacity {
                        running: utgCommunication && !utgCommunication.connected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1000 }
                        NumberAnimation { to: 1.0; duration: 1000 }
                    }
                }
                
                // Connect/Disconnect button
                QGCButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    text: utgCommunication && utgCommunication.connected ? qsTr("DISCONNECT") : qsTr("CONNECT")
                    backgroundColor: utgCommunication && utgCommunication.connected ? warningColor : successColor
                    onClicked: {
                        if (utgCommunication) {
                            if (utgCommunication.connected) {
                                utgCommunication.disconnectFromUTG()
                            } else {
                                utgCommunication.connectToUTG()
                            }
                        }
                    }
                }

                QGCButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    text: qsTr("READINGS")
                    backgroundColor: warningColor

                    Component.onCompleted: {
                        console.log("=== READINGS BUTTON DEBUG ===")
                        console.log("READINGS button created successfully!")
                        console.log("Button text:", text)
                        console.log("Button visible:", visible)
                        console.log("Button enabled:", enabled)
                        console.log("Button width:", width, "height:", height)
                        console.log("Button parent:", parent)
                        console.log("Button backgroundColor:", backgroundColor)
                    }

                    onClicked: {
                        console.log("READINGS button clicked")
                        console.log("utgCommunication:", utgCommunication)
                        console.log("readingManager:", utgCommunication ? utgCommunication.readingManager : "null")
                        readingListDialog.open()
                    }
                }

                QGCButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    text: qsTr("SETTINGS")
                    backgroundColor: primaryColor

                    Component.onCompleted: {
                        console.log("=== SETTINGS BUTTON DEBUG ===")
                        console.log("SETTINGS button created successfully!")
                        console.log("Button visible:", visible)
                        console.log("Button width:", width, "height:", height)
                    }

                    onClicked: settingsDialog.open()
                }
            }
        }
        
        // Main content area
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: ScreenTools.defaultFontPixelWidth
            
            // Left column - Measurement and Configuration
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.6
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                
                // Measurement Display Panel
                UTGMeasurementPanel {
                    id: measurementPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                    utgCommunication: root.utgCommunication
                }
                
                // Configuration Panel
                UTGConfigurationPanel {
                    id: configPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    utgCommunication: root.utgCommunication
                }
            }
            
            // Right column - Calibration and Status
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                
                // Device Information Panel
                UTGDeviceInfoPanel {
                    id: deviceInfoPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 6
                    utgCommunication: root.utgCommunication
                }
                
                // Calibration Panel
                UTGCalibrationPanel {
                    id: calibrationPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                    utgCommunication: root.utgCommunication
                }
                
                // Status/Log Panel
                UTGStatusPanel {
                    id: statusPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    utgCommunication: root.utgCommunication
                }
            }
        }
        
        // Error display at bottom
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
            color: errorColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            visible: utgCommunication && utgCommunication.lastError !== ""
            
            QGCLabel {
                anchors.centerIn: parent
                text: utgCommunication ? utgCommunication.lastError : ""
                font.bold: true
                color: "white"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Auto-hide error after 5 seconds
            Timer {
                interval: 5000
                running: parent.visible
                onTriggered: {
                    if (utgCommunication) {
                        utgCommunication.lastError = ""
                    }
                }
            }
        }
    }

    // Settings Dialog
    QGCPopupDialog {
        id: settingsDialog
        title: qsTr("UTG Settings")
        standardButtons: StandardButton.Close

        UTGSettingsPanel {
            width: ScreenTools.defaultFontPixelWidth * 50
            height: ScreenTools.defaultFontPixelHeight * 40
        }
    }

    // Reading List Dialog
    Dialog {
        id: readingListDialog
        title: qsTr("UTG Readings")
        standardButtons: StandardButton.Close
        width: ScreenTools.defaultFontPixelWidth * 80
        height: ScreenTools.defaultFontPixelHeight * 50

        UTGReadingListPanel {
            anchors.fill: parent
            utgReadingManager: utgCommunication ? utgCommunication.readingManager : null
        }
    }

    // Save Reading Dialog
    Dialog {
        id: saveReadingDialog
        title: qsTr("Save Reading")
        standardButtons: StandardButton.Ok | StandardButton.Cancel

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Current Reading: %1 %2").arg(
                    utgCommunication ? utgCommunication.currentThickness.toFixed(2) : "0.00"
                ).arg(
                    utgCommunication ? utgCommunication.detectedUnit : "mm"
                )
                font.bold: true
            }

            QGCLabel {
                text: qsTr("Notes (optional):")
            }

            TextField {
                id: readingNotesField
                placeholderText: qsTr("Enter notes for this reading...")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 40
            }
        }

        onAccepted: {
            if (utgCommunication) {
                if (readingNotesField.text.trim().length > 0) {
                    utgCommunication.saveReadingWithNotes(readingNotesField.text.trim())
                } else {
                    utgCommunication.saveCurrentReading()
                }
                readingNotesField.text = ""
            }
        }

        onRejected: {
            readingNotesField.text = ""
        }
    }

    // Drop shadow effect
    DropShadow {
        anchors.fill: parent
        source: parent
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8.0
        samples: 17
        color: "#80000000"
    }
}
