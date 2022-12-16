import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Layouts          1.11
import QtQuick.Dialogs          1.3
import Qt.labs.platform         1.1
import Qt.labs.settings         1.0

import QGroundControl             1.0
import QGroundControl.Palette     1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Controls    1.0

Item {
    anchors.fill:       parent

    ColumnLayout {
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        QGCLabel {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 20
            text: "Camera Controls Settings"
        }

        Rectangle {
            width: grid.width + 40
            height: grid.height + 40

            border.color: "#808080"
            border.width: 1
            color: qgcPal.window

            GridLayout {
                id: grid

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 20
                anchors.leftMargin: 20
                columns: 2

                QGCLabel {
                    text: "Cameras Count"
                }

                SpinBox {
                    Layout.minimumWidth: 150

                    from: 0
                    to: customPlugin.maxCameras
                    value: customPlugin.nbCameras
                    textFromValue: function(value) {return value;}
                    onValueModified: {
                        customPlugin.nbCameras = value;
                    }
                }

                QGCLabel {
                    text: "Target System Id"
                }

                SpinBox {
                    Layout.minimumWidth: 150

                    editable: true
                    from: 0
                    to: 255
                    value: customPlugin.targetSystemId
                    textFromValue: function(value) {return value;}
                    onValueModified: {
                        customPlugin.targetSystemId = value;
                    }
                }

                QGCLabel {
                    text: "Target Component Id"
                }

                SpinBox {
                    Layout.minimumWidth: 150

                    editable: true
                    from: 0
                    to: 255
                    value: customPlugin.targetComponentId
                    textFromValue: function(value) {return value;}
                    onValueModified: {
                        customPlugin.targetComponentId = value;
                    }
                }

                QGCLabel {
                    text: "Zoom Timer Delay (ms)"
                }

                SpinBox {
                    Layout.minimumWidth: 150

                    editable: true
                    from: 0
                    to: 1000
                    value: customPlugin.zoomTimerDuration
                    textFromValue: function(value) {return value;}
                    onValueModified: {
                        customPlugin.zoomTimerDuration = value;
                    }
                }
            }
        }
    }
}
