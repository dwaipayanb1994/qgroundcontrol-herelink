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

import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root

    property var utgReadingManager

    color: qgcPal.window

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text: qsTr("Total readings: %1").arg(utgReadingManager ? utgReadingManager.count : 0)
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: readingListView
                model: utgReadingManager
                spacing: ScreenTools.defaultFontPixelHeight * 0.25

                delegate: Rectangle {
                    width: readingListView.width
                    height: ScreenTools.defaultFontPixelHeight * 3
                    color: index % 2 === 0 ? qgcPal.window : qgcPal.windowShade
                    border.color: qgcPal.text
                    border.width: 0.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5

                        QGCLabel {
                            Layout.preferredWidth: parent.width * 0.22
                            text: datetime
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.smallFontPointSize
                        }

                        QGCLabel {
                            Layout.preferredWidth: parent.width * 0.15
                            text: reading
                            horizontalAlignment: Text.AlignHCenter
                        }

                        QGCLabel {
                            Layout.preferredWidth: parent.width * 0.22
                            text: gpsLocation
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.smallFontPointSize
                        }

                        QGCLabel {
                            Layout.preferredWidth: parent.width * 0.12
                            text: altitude
                            horizontalAlignment: Text.AlignHCenter
                            font.pointSize: ScreenTools.smallFontPointSize
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: notes
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            QGCButton {
                text: qsTr("Refresh")
                Layout.fillWidth: true
                enabled: utgReadingManager && !utgReadingManager.loading
                onClicked: {
                    if (utgReadingManager) {
                        utgReadingManager.reloadAsync()
                    }
                }
            }

            QGCButton {
                text: qsTr("Clear All")
                Layout.fillWidth: true
                enabled: utgReadingManager && utgReadingManager.count > 0
                onClicked: {
                    if (utgReadingManager) {
                        utgReadingManager.clearAll()
                    }
                }
            }
        }
    }
}
