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

/// Industrial-style configuration panel
Rectangle {
    id: root
    
    property var utgCommunication
    
    // Industrial colors
    readonly property color primaryColor: "#2C3E50"
    readonly property color secondaryColor: "#34495E"
    readonly property color accentColor: "#3498DB"
    readonly property color warningColor: "#F39C12"
    readonly property color textColor: "#ECF0F1"
    readonly property color inputColor: "#1A252F"
    
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
            text: qsTr("CONFIGURATION")
            font.bold: true
            font.pixelSize: ScreenTools.mediumFontPixelSize
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Velocity configuration
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: accentColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("ULTRASONIC VELOCITY")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                        color: inputColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        border.color: accentColor
                        border.width: 1
                        
                        QGCTextField {
                            id: velocityField
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                            text: utgCommunication ? utgCommunication.velocity.toFixed(0) : "5920"
                            validator: DoubleValidator { bottom: 1000; top: 10000 }
                            color: textColor
                            font.bold: true
                            horizontalAlignment: TextInput.AlignHCenter
                            
                            onEditingFinished: {
                                if (utgCommunication && acceptableInput) {
                                    utgCommunication.setVelocityCommand(parseFloat(text))
                                }
                            }
                        }

                        Connections {
                            target: utgCommunication
                            function onVelocityChanged(velocity) {
                                if (!velocityField.activeFocus) {
                                    velocityField.text = velocity.toFixed(0)
                                }
                            }
                        }
                    }
                    
                    QGCLabel {
                        text: qsTr("m/s")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                    
                    QGCButton {
                        text: qsTr("GET")
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        backgroundColor: warningColor
                        enabled: utgCommunication && utgCommunication.connected
                        
                        onClicked: {
                            if (utgCommunication) {
                                utgCommunication.getVelocity()
                            }
                        }
                    }
                }
            }
        }
        
        // Gain configuration
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: accentColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("GAIN")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                        color: inputColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        border.color: accentColor
                        border.width: 1
                        
                        QGCTextField {
                            id: gainField
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                            text: utgCommunication ? utgCommunication.gain.toString() : "50"
                            validator: IntValidator { bottom: 0; top: 100 }
                            color: textColor
                            font.bold: true
                            horizontalAlignment: TextInput.AlignHCenter
                            
                            onEditingFinished: {
                                if (utgCommunication && acceptableInput) {
                                    utgCommunication.setGainCommand(parseInt(text))
                                }
                            }
                        }
                    }
                    
                    QGCLabel {
                        text: qsTr("dB")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                    
                    QGCButton {
                        text: qsTr("GET")
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        backgroundColor: warningColor
                        enabled: utgCommunication && utgCommunication.connected
                        
                        onClicked: {
                            if (utgCommunication) {
                                utgCommunication.getGain()
                            }
                        }
                    }
                }
            }
        }
        
        // Range configuration
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 5
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: accentColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("MEASUREMENT RANGE")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCLabel {
                        text: qsTr("START:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        color: inputColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        border.color: accentColor
                        border.width: 1
                        
                        QGCTextField {
                            id: rangeStartField
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                            text: utgCommunication ? utgCommunication.rangeStart.toFixed(1) : "0.0"
                            validator: DoubleValidator { bottom: 0; top: 1000 }
                            color: textColor
                            font.bold: true
                            horizontalAlignment: TextInput.AlignHCenter
                        }
                    }
                    
                    QGCLabel {
                        text: qsTr("END:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        color: inputColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        border.color: accentColor
                        border.width: 1
                        
                        QGCTextField {
                            id: rangeEndField
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                            text: utgCommunication ? utgCommunication.rangeEnd.toFixed(1) : "100.0"
                            validator: DoubleValidator { bottom: 0; top: 1000 }
                            color: textColor
                            font.bold: true
                            horizontalAlignment: TextInput.AlignHCenter
                        }
                    }
                    
                    QGCLabel {
                        text: qsTr("mm")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCButton {
                        text: qsTr("SET RANGE")
                        Layout.fillWidth: true
                        backgroundColor: warningColor
                        enabled: utgCommunication && utgCommunication.connected
                        
                        onClicked: {
                            if (utgCommunication && rangeStartField.acceptableInput && rangeEndField.acceptableInput) {
                                utgCommunication.setRangeCommand(parseFloat(rangeStartField.text), parseFloat(rangeEndField.text))
                            }
                        }
                    }
                    
                    QGCButton {
                        text: qsTr("GET")
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        backgroundColor: warningColor
                        enabled: utgCommunication && utgCommunication.connected
                        
                        onClicked: {
                            if (utgCommunication) {
                                utgCommunication.getRange()
                            }
                        }
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
