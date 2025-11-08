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

/// Industrial-style device information panel
Rectangle {
    id: root
    
    property var utgCommunication
    
    // Industrial colors
    readonly property color primaryColor: "#2C3E50"
    readonly property color secondaryColor: "#34495E"
    readonly property color accentColor: "#3498DB"
    readonly property color successColor: "#27AE60"
    readonly property color textColor: "#ECF0F1"
    readonly property color infoColor: "#9B59B6"
    
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
            text: qsTr("DEVICE INFORMATION")
            font.bold: true
            font.pixelSize: ScreenTools.mediumFontPixelSize
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Device version info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: infoColor
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                
                QGCLabel {
                    text: qsTr("VERSION:")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }
                
                QGCLabel {
                    text: utgCommunication && utgCommunication.deviceVersion !== "" ? 
                          utgCommunication.deviceVersion : qsTr("Unknown")
                    color: utgCommunication && utgCommunication.deviceVersion !== "" ? successColor : "#7F8C8D"
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.fillWidth: true
                }
                
                QGCButton {
                    text: qsTr("GET")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                    backgroundColor: infoColor
                    enabled: utgCommunication && utgCommunication.connected
                    
                    onClicked: {
                        if (utgCommunication) {
                            utgCommunication.getVersion()
                        }
                    }
                }
            }
        }
        
        // Current settings display
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: infoColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("CURRENT SETTINGS")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.alignment: Qt.AlignHCenter
                }
                
                // Velocity display
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCLabel {
                        text: qsTr("Velocity:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                    }
                    
                    QGCLabel {
                        text: utgCommunication ? qsTr("%1 m/s").arg(utgCommunication.velocity.toFixed(0)) : "-- m/s"
                        color: successColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
                
                // Gain display
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCLabel {
                        text: qsTr("Gain:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                    }
                    
                    QGCLabel {
                        text: utgCommunication ? qsTr("%1 dB").arg(utgCommunication.gain) : "-- dB"
                        color: successColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
                
                // Range display
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCLabel {
                        text: qsTr("Range:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                    }
                    
                    QGCLabel {
                        text: utgCommunication ? 
                              qsTr("%1 - %2 mm").arg(utgCommunication.rangeStart.toFixed(1)).arg(utgCommunication.rangeEnd.toFixed(1)) : 
                              "-- mm"
                        color: successColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
                
                // Temperature display
                RowLayout {
                    Layout.fillWidth: true
                    visible: utgCommunication && utgCommunication.temperature > 0
                    
                    QGCLabel {
                        text: qsTr("Temperature:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                    }
                    
                    QGCLabel {
                        text: utgCommunication ? qsTr("%1°C").arg(utgCommunication.temperature.toFixed(1)) : "--°C"
                        color: successColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
            }
        }
        
        // Help button
        QGCButton {
            Layout.fillWidth: true
            text: qsTr("GET HELP")
            backgroundColor: infoColor
            enabled: utgCommunication && utgCommunication.connected
            
            onClicked: {
                if (utgCommunication) {
                    utgCommunication.getHelp()
                }
            }
            
            // Button press animation
            scale: pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
    
    // Panel shadow effect
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 2
        verticalOffset: 2
        radius: 6.0
        samples: 13
        color: "#40000000"
    }
}
