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

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.FactControls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

/// UTG Settings Configuration Panel
Rectangle {
    id: root
    
    property var qgcPal: QGroundControlPalette { colorGroupEnabled: enabled }
    property var utgSettings: QGroundControl.settingsManager.utgSettings
    
    color: qgcPal.window
    border.color: qgcPal.text
    border.width: 1
    radius: ScreenTools.defaultFontPixelWidth * 0.25
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth * 0.5
        
        // Header
        QGCLabel {
            text: qsTr("UTG Settings")
            font.pointSize: ScreenTools.largeFontPointSize
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: qgcPal.text
        }
        
        // Connection Settings
        GroupBox {
            title: qsTr("Connection")
            Layout.fillWidth: true
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.25
                
                QGCLabel { text: qsTr("Enable UTG:") }
                FactCheckBox {
                    fact: utgSettings.enabled
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Auto Connect:") }
                FactCheckBox {
                    fact: utgSettings.autoConnect
                    Layout.fillWidth: true
                }
            }
        }
        
        // Measurement Settings
        GroupBox {
            title: qsTr("Measurement")
            Layout.fillWidth: true
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.25
                
                QGCLabel { text: qsTr("Unit:") }
                FactComboBox {
                    fact: utgSettings.measurementUnit
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Mode:") }
                FactComboBox {
                    fact: utgSettings.measurementMode
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Sound Velocity:") }
                FactTextField {
                    fact: utgSettings.soundVelocity
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Gain (%):") }
                FactTextField {
                    fact: utgSettings.gain
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Display Precision:") }
                FactTextField {
                    fact: utgSettings.displayPrecision
                    Layout.fillWidth: true
                }
            }
        }
        
        // Calibration Settings
        GroupBox {
            title: qsTr("Calibration")
            Layout.fillWidth: true
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.25
                
                QGCLabel { text: qsTr("Zero Offset:") }
                FactTextField {
                    fact: utgSettings.zeroOffset
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Material Type:") }
                FactComboBox {
                    fact: utgSettings.materialType
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Temperature Compensation:") }
                FactCheckBox {
                    fact: utgSettings.temperatureCompensation
                    Layout.fillWidth: true
                }
            }
        }
        
        // Logging Settings
        GroupBox {
            title: qsTr("Logging")
            Layout.fillWidth: true
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.25
                
                QGCLabel { text: qsTr("Log Measurements:") }
                FactCheckBox {
                    fact: utgSettings.logMeasurements
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Auto Save:") }
                FactCheckBox {
                    fact: utgSettings.autoSaveMeasurements
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Log File Path:") }
                FactTextField {
                    fact: utgSettings.logFilePath
                    Layout.fillWidth: true
                }
            }
        }
        
        // Alert Settings
        GroupBox {
            title: qsTr("Alerts")
            Layout.fillWidth: true
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.25
                
                QGCLabel { text: qsTr("Enable Alerts:") }
                FactCheckBox {
                    fact: utgSettings.alertEnabled
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Alert Sound:") }
                FactCheckBox {
                    fact: utgSettings.alertSound
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Min Thickness Alert:") }
                FactTextField {
                    fact: utgSettings.minThicknessAlert
                    Layout.fillWidth: true
                }
                
                QGCLabel { text: qsTr("Max Thickness Alert:") }
                FactTextField {
                    fact: utgSettings.maxThicknessAlert
                    Layout.fillWidth: true
                }
            }
        }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            spacing: ScreenTools.defaultFontPixelWidth
            
            QGCButton {
                text: qsTr("Reset to Defaults")
                onClicked: {
                    if (utgSettings) {
                        utgSettings.resetToDefaults()
                    }
                }
            }
            
            QGCButton {
                text: qsTr("Validate Settings")
                onClicked: {
                    if (utgSettings) {
                        utgSettings.validateSettings()
                    }
                }
            }
        }
        
        Item {
            Layout.fillHeight: true
        }
    }
}
