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

/// Industrial-style measurement display panel
Rectangle {
    id: root
    
    property var utgCommunication
    
    // Industrial colors
    readonly property color primaryColor: "#2C3E50"
    readonly property color accentColor: "#3498DB"
    readonly property color successColor: "#27AE60"
    readonly property color textColor: "#ECF0F1"
    readonly property color displayColor: "#1ABC9C"
    
    color: primaryColor
    radius: ScreenTools.defaultFontPixelWidth * 0.25
    border.color: accentColor
    border.width: 2
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth * 0.5
        
        // Panel title
        QGCLabel {
            text: qsTr("THICKNESS MEASUREMENT")
            font.bold: true
            font.pixelSize: ScreenTools.mediumFontPixelSize
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Main measurement display
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1A252F"
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: displayColor
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                
                // Large thickness value
                QGCLabel {
                    text: utgCommunication ? utgCommunication.currentThickness.toFixed(2) : "0.00"
                    font.bold: true
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 3
                    color: displayColor
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    // Glow effect for the measurement
                    layer.enabled: true
                    layer.effect: Glow {
                        radius: 8
                        samples: 17
                        color: displayColor
                        transparentBorder: true
                    }
                }
                
                // Unit label
                QGCLabel {
                    text: qsTr("mm")
                    font.bold: true
                    font.pixelSize: ScreenTools.largeFontPixelSize
                    color: textColor
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: ScreenTools.defaultFontPixelWidth
                }
            }
            
            // Measurement status indicator
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                width: ScreenTools.defaultFontPixelWidth * 1.5
                height: width
                radius: width / 2
                color: utgCommunication && utgCommunication.currentThickness > 0 ? successColor : "#7F8C8D"
                
                // Pulsing animation when measuring
                SequentialAnimation on scale {
                    running: utgCommunication && utgCommunication.currentThickness > 0
                    loops: 3
                    NumberAnimation { to: 1.2; duration: 200 }
                    NumberAnimation { to: 1.0; duration: 200 }
                }
            }
        }
        
        // Measurement controls
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            
            QGCButton {
                text: qsTr("MEASURE")
                Layout.fillWidth: true
                backgroundColor: successColor
                enabled: utgCommunication && utgCommunication.connected
                font.bold: true
                
                onClicked: {
                    if (utgCommunication) {
                        utgCommunication.takeMeasurement()
                    }
                }
                
                // Button press animation
                scale: pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
            
            QGCButton {
                text: qsTr("SAVE")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                backgroundColor: warningColor
                enabled: utgCommunication && utgCommunication.connected && utgCommunication.currentThickness > 0

                onClicked: {
                    if (utgCommunication) {
                        // Open save dialog from parent
                        var panel = parent
                        while (panel && !panel.saveReadingDialog) {
                            panel = panel.parent
                        }
                        if (panel && panel.saveReadingDialog) {
                            panel.saveReadingDialog.open()
                        }
                    }
                }

                scale: pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }

            QGCButton {
                text: qsTr("TEMP")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                backgroundColor: accentColor
                enabled: utgCommunication && utgCommunication.connected

                onClicked: {
                    if (utgCommunication) {
                        utgCommunication.getTemperature()
                    }
                }

                scale: pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }
        
        // Temperature display (if available)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
            color: "#34495E"
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            visible: utgCommunication && utgCommunication.temperature > 0
            
            QGCLabel {
                anchors.centerIn: parent
                text: qsTr("Temperature: %1°C").arg(utgCommunication ? utgCommunication.temperature.toFixed(1) : "0.0")
                color: textColor
                font.pixelSize: ScreenTools.smallFontPixelSize
            }
        }
    }
    
    // Panel glow effect
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 2
        verticalOffset: 2
        radius: 6.0
        samples: 13
        color: "#40000000"
    }
}
