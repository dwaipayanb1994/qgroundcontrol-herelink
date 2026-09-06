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

/// Industrial-style calibration panel
Rectangle {
    id: root
    
    property var utgCommunication
    
    // Industrial colors
    readonly property color primaryColor: "#2C3E50"
    readonly property color secondaryColor: "#34495E"
    readonly property color accentColor: "#3498DB"
    readonly property color warningColor: "#F39C12"
    readonly property color errorColor: "#E74C3C"
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
            text: qsTr("CALIBRATION")
            font.bold: true
            font.pixelSize: ScreenTools.mediumFontPixelSize
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Zero calibration section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.5
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: warningColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("ZERO CALIBRATION")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.alignment: Qt.AlignHCenter
                }
                
                QGCLabel {
                    text: qsTr("Hold probe on the 4 mm calibration block, then press ZERO")
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                
                QGCButton {
                    text: qsTr("ZERO")
                    Layout.fillWidth: true
                    backgroundColor: warningColor
                    enabled: utgCommunication && utgCommunication.connected
                    font.bold: true
                    
                    onClicked: {
                        if (utgCommunication) {
                            utgCommunication.performZeroCalibration()
                        }
                    }
                    
                    // Button press animation
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                }
            }
        }
        
        // Thickness calibration section
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: warningColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("THICKNESS CALIBRATION")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.alignment: Qt.AlignHCenter
                }
                
                QGCLabel {
                    text: qsTr("Place probe on known thickness material")
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    QGCLabel {
                        text: qsTr("Thickness:")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                        color: inputColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.25
                        border.color: accentColor
                        border.width: 1
                        
                        QGCTextField {
                            id: calibrationThicknessField
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.25
                            text: "25.4"
                            validator: DoubleValidator { bottom: 0.1; top: 1000.0 }
                            color: textColor
                            font.bold: true
                            horizontalAlignment: TextInput.AlignHCenter
                            placeholderText: qsTr("0.1 - 1000.0")
                        }
                    }
                    
                    QGCLabel {
                        text: qsTr("mm")
                        color: textColor
                        font.pixelSize: ScreenTools.smallFontPixelSize
                    }
                }
                
                QGCButton {
                    text: qsTr("CALIBRATE")
                    Layout.fillWidth: true
                    backgroundColor: warningColor
                    enabled: utgCommunication && utgCommunication.connected && calibrationThicknessField.acceptableInput
                    font.bold: true
                    
                    onClicked: {
                        if (utgCommunication && calibrationThicknessField.acceptableInput) {
                            utgCommunication.performThicknessCalibration(parseFloat(calibrationThicknessField.text))
                        }
                    }
                    
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                }
            }
        }
        
        // Reset device section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.5
            color: secondaryColor
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            border.color: errorColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.25
                
                QGCLabel {
                    text: qsTr("RESET DEVICE")
                    font.bold: true
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    Layout.alignment: Qt.AlignHCenter
                }
                
                QGCLabel {
                    text: qsTr("Reset device to factory defaults")
                    color: textColor
                    font.pixelSize: ScreenTools.smallFontPixelSize
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                
                QGCButton {
                    text: qsTr("RESET")
                    Layout.fillWidth: true
                    backgroundColor: errorColor
                    enabled: utgCommunication && utgCommunication.connected
                    font.bold: true
                    
                    onClicked: {
                        resetConfirmDialog.open()
                    }
                    
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                }
            }
        }
    }
    
    // Reset confirmation dialog
    QGCPopupDialog {
        id: resetConfirmDialog
        title: qsTr("Confirm Reset")
        buttons: StandardButton.Yes | StandardButton.No
        
        QGCLabel {
            text: qsTr("Are you sure you want to reset the UTG device to factory defaults?\n\nThis will erase all calibration data.")
            wrapMode: Text.WordWrap
        }
        
        onAccepted: {
            if (utgCommunication) {
                utgCommunication.resetDevice()
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
