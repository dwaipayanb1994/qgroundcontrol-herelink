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

/// Industrial-style status and log panel
Rectangle {
    id: root
    
    property var utgCommunication
    
    // Industrial colors
    readonly property color primaryColor: "#2C3E50"
    readonly property color secondaryColor: "#34495E"
    readonly property color accentColor: "#3498DB"
    readonly property color successColor: "#27AE60"
    readonly property color warningColor: "#F39C12"
    readonly property color textColor: "#ECF0F1"
    readonly property color logColor: "#1A252F"
    
    color: primaryColor
    radius: ScreenTools.defaultFontPixelWidth * 0.25
    border.color: accentColor
    border.width: 2
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth * 0.5
        
        // Panel title with clear button
        RowLayout {
            Layout.fillWidth: true
            
            QGCLabel {
                text: qsTr("STATUS & LOG")
                font.bold: true
                font.pixelSize: ScreenTools.mediumFontPixelSize
                color: textColor
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            
            QGCButton {
                text: qsTr("CLEAR")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
                backgroundColor: warningColor
                enabled: utgCommunication && utgCommunication.commandLog.length > 0
                
                onClicked: {
                    if (utgCommunication) {
                        // Clear the log by setting it to empty array
                        // This would need to be implemented in the C++ backend
                        utgCommunication.clearCommandLog()
                    }
                }
            }
        }
        
        // Connection status indicator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: utgCommunication && utgCommunication.connected ? successColor : "#E74C3C"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                
                Rectangle {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth
                    Layout.preferredHeight: ScreenTools.defaultFontPixelWidth
                    radius: width / 2
                    color: utgCommunication && utgCommunication.connected ? successColor : "#E74C3C"
                    
                    // Pulsing animation for connected state
                    SequentialAnimation on opacity {
                        running: utgCommunication && utgCommunication.connected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1500 }
                        NumberAnimation { to: 1.0; duration: 1500 }
                    }
                }
                
                QGCLabel {
                    text: utgCommunication && utgCommunication.connected ? 
                          qsTr("UTG Device Connected") : qsTr("UTG Device Disconnected")
                    font.bold: true
                    color: textColor
                    Layout.fillWidth: true
                }
                
                QGCLabel {
                    text: utgCommunication && utgCommunication.deviceVersion !== "" ? 
                          utgCommunication.deviceVersion : qsTr("No Version")
                    color: utgCommunication && utgCommunication.deviceVersion !== "" ? successColor : "#7F8C8D"
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }
            }
        }
        
        // Command/Response log
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: logColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: accentColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("COMMAND LOG")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.alignment: Qt.AlignHCenter
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: logListView
                        model: utgCommunication ? utgCommunication.commandLog : []
                        
                        delegate: Rectangle {
                            width: logListView.width
                            height: logText.height + ScreenTools.defaultFontPixelWidth * 0.5
                            color: index % 2 === 0 ? "transparent" : "#0F1419"
                            
                            QGCLabel {
                                id: logText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                                
                                text: modelData
                                color: {
                                    if (modelData.includes("TX:")) return accentColor
                                    if (modelData.includes("RX:")) return successColor
                                    if (modelData.includes("ERROR") || modelData.includes("TIMEOUT")) return "#E74C3C"
                                    return textColor
                                }
                                font.pixelSize: ScreenTools.smallFontPixelSize
                                font.family: "Courier"
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        // Auto-scroll to bottom when new entries are added
                        onCountChanged: {
                            Qt.callLater(function() {
                                if (count > 0) {
                                    positionViewAtEnd()
                                }
                            })
                        }
                    }
                }
                
                // Log statistics
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    color: secondaryColor
                    radius: ScreenTools.defaultFontPixelWidth * 0.25
                    
                    QGCLabel {
                        anchors.centerIn: parent
                        text: qsTr("Log entries: %1").arg(utgCommunication ? utgCommunication.commandLog.length : 0)
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                }
            }
        }
        
        // Quick action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            
            QGCButton {
                text: qsTr("VERSION")
                Layout.fillWidth: true
                backgroundColor: accentColor
                enabled: utgCommunication && utgCommunication.connected
                
                onClicked: {
                    if (utgCommunication) {
                        utgCommunication.getVersion()
                    }
                }
            }
            
            QGCButton {
                text: qsTr("HELP")
                Layout.fillWidth: true
                backgroundColor: accentColor
                enabled: utgCommunication && utgCommunication.connected
                
                onClicked: {
                    if (utgCommunication) {
                        utgCommunication.getHelp()
                    }
                }
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
