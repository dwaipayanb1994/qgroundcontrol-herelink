import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Layouts          1.11
import QtQuick.Dialogs          1.3
import Qt.labs.platform         1.1
import Qt.labs.settings         1.0

import QGroundControl           1.0
import QGroundControl.Palette   1.0

Item {
    anchors.fill: parent

    function setChannelValue(channelIndex, value)
    {
        customPlugin.setChannelValue(channelIndex === 0 ? -1 : channelIndex + 4, value);
    }

    function onChannelChanged(cboChannel, newChannelIndex)
    {
        if(newChannelIndex === 0)
            return;

        let camId = null, ctrlName = null;

        for(let i = 0; i < _repCameras.count; i++)
        {
            for (const [controlName, controlItem] of Object.entries(_repCameras.itemAt(i).configPage.config))
            {
              if(controlItem.cboChannel !== cboChannel && controlItem.channelIndex === newChannelIndex)
              {
                  // already used
                  camId = i;
                  ctrlName = controlName;
                  break;
              }
            }
        }

        // Check if channel is already used
        if(camId && ctrlName)
        {
            messageDialog.text = `Channel ${newChannelIndex+4} is already used in CAM ${camId} (${ctrlName[0].toUpperCase() + ctrlName.slice(1)}) !`;
            messageDialog.open();
            cboChannel.currentIndex = cboChannel.lastIndex;
        }
        else
        {
            // Reset previous channel so it goes back to failsafe
            setChannelValue(cboChannel.lastIndex, 0);

            // Remember previous channel
            cboChannel.lastIndex = cboChannel.currentIndex;
        }
    }

    MessageDialog {
        id: messageDialog
    }

    QGCPalette { id: qgcPal }

    Repeater {
        id: _repCameras
        model: customPlugin.nbCameras

        Rectangle {
            id: mainRect

            property int cameraId: index
            property bool isConfigModeOn: false
            property string settingsRoot: `CameraControls/Camera${cameraId}`
            property alias configPage: configPage

            function switchMode()
            {
                mainRect.isConfigModeOn = !mainRect.isConfigModeOn;
            }

            function onButtonAction(controlName, valueName)
            {
                const config = configPage.config[controlName];
                setChannelValue(config.channelIndex, config.values[valueName ? valueName : "default"].value);
            }

            x: 40
            y: 40
            color: Qt.rgba(0,0,0,0.75)
            radius: mainRect.isConfigModeOn ? 0 : 48
            width: mainRect.isConfigModeOn ? configPage.width + 60 : 346
            height: mainRect.isConfigModeOn ? configPage.height + 60 : 256
            clip: true

            Settings {
                category: `${settingsRoot}/Position`
                property alias x: mainRect.x
                property alias y: mainRect.y
            }

            MouseArea {
                anchors.fill: parent
                drag.target: mainRect
                drag.axis: Drag.XAndYAxis
            }

            // Edge button
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: -60
                anchors.topMargin: -60
                radius: 60
                width: 120
                height: 120
                color: qgcPal.brandingPurple

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        mainRect.switchMode()
                    }
                }
            }

            RoundButton {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 0
                anchors.topMargin: 0
                width: 48
                height: 48
                background: null

                icon.source: `qrc:/custom/img/${mainRect.isConfigModeOn ? "Controls" : "Settings"}`
                icon.color: this.pressed ? qgcPal.brandingBlue : "#ffffff"
                icon.width: 36
                icon.height: 36

                onClicked: {
                    mainRect.switchMode()
                }
            }

            Item {
                width: 240
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8

                visible: !mainRect.isConfigModeOn

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `CAM ${cameraId + 1}`
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"

                    MouseArea {
                        property bool mustRelease: false
                        anchors.fill: parent

                        onPressed: parent.color = qgcPal.brandingPurple

                        onPressAndHold: {
                            mustRelease = true;
                            onButtonAction('home', 'active')
                        }

                        onReleased: {
                            parent.color = "#ffffff"

                            if(mustRelease)
                                onButtonAction('home')
                            mustRelease = false;
                        }
                    }
                }


                // Navigation Controls (Left, up, right, down)
                Repeater {
                   model: [
                       {controlName: 'vertical', valueName: 'up', icon: 'ArrowUp', top: true, horizontalCenter: true},
                       {controlName: 'horizontal', valueName: 'left', icon: 'ArrowLeft', left: true, verticalCenter: true},
                       {controlName: 'horizontal', valueName: 'right', icon: 'ArrowRight', right: true, verticalCenter: true},
                       {controlName: 'vertical', valueName: 'down', icon: 'ArrowDown', bottom: true, horizontalCenter: true}
                   ]

                   RoundButton {
                       anchors.top: modelData.top ? parent.top : undefined
                       anchors.left: modelData.left ? parent.left : undefined
                       anchors.right: modelData.right ? parent.right : undefined
                       anchors.bottom: modelData.bottom ? parent.bottom : undefined
                       anchors.horizontalCenter: modelData.horizontalCenter ? parent.horizontalCenter : undefined
                       anchors.verticalCenter: modelData.verticalCenter ? parent.verticalCenter : undefined

                       width: 80
                       height: 80

                       focusPolicy: Qt.NoFocus

                       icon.source: `qrc:/custom/img/${modelData.icon}`
                       icon.color: "#000000"
                       icon.width: 50
                       icon.height: 50

                       palette.button: this.pressed ? qgcPal.brandingPurple : "#ffffff"

                       onPressed: onButtonAction(modelData.controlName, modelData.valueName)
                       onReleased: onButtonAction(modelData.controlName)
                   }
                }
            }

            // Zoom In/Out
            Repeater {
               model: [
                   {icon: 'ZoomIn', top: true},
                   {icon: 'ZoomOut', bottom: true},
               ]

               RoundButton {
                   anchors.right: parent.right
                   anchors.rightMargin: 8

                   anchors.top: modelData.top ? parent.top : undefined
                   anchors.topMargin: modelData.top ? 8 : 0

                   anchors.bottom: modelData.bottom ? parent.bottom : undefined
                   anchors.bottomMargin: modelData.bottom ? 8 : 0

                   icon.source: `qrc:/custom/img/${modelData.icon}`
                   icon.color: "#000000"
                   icon.width: 50
                   icon.height: 50

                   focusPolicy: Qt.NoFocus

                   visible: !mainRect.isConfigModeOn

                   background: Item {

                       implicitWidth: 80
                       implicitHeight: 116

                       Rectangle {
                           anchors.right: parent.right
                           anchors.top: modelData.bottom ? parent.top : undefined
                           anchors.bottom: modelData.top ? parent.bottom : undefined
                           implicitWidth: 80
                           implicitHeight: 40
                           color: parent.parent.down ? qgcPal.brandingPurple : "#ffffff"
                       }

                       Rectangle {
                           anchors.fill: parent
                           radius: 40
                           color: parent.parent.down ? qgcPal.brandingPurple : "#ffffff"
                       }
                   }

                   onPressed: onButtonAction('zoom', modelData.top ? 'in' : 'out')
                   onReleased: {
                       onButtonAction('zoom');
                       _zoomTimer.valueName = modelData.top ? 'out' : 'in';
                       _zoomTimer.restart();
                   }

                   Timer {
                       property var valueName
                       id: _zoomTimer
                       interval: customPlugin.zoomTimerDuration
                       onTriggered: {
                           onButtonAction('zoom', valueName);

                           if(valueName !== undefined)
                           {
                               valueName = undefined;
                               _zoomTimer.restart();
                           }
                       }
                   }
               }
            }

            // Config page
            ColumnLayout {
                id: configPage

                property var config: ({}) // { "horizontal": horConfig, "vertical": verConfig }

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 30
                anchors.topMargin: 30
                visible: mainRect.isConfigModeOn

                Repeater {
                    model: [
                        {name: 'Horizontal', valuesNames: ['Left', 'Right', 'Default']},
                        {name: 'Vertical', valuesNames: ['Up', 'Down', 'Default']},
                        {name: 'Zoom', valuesNames: ['In', 'Out', 'Default']},
                        {name: 'Home', valuesNames: ['Active', 'Default']},
                    ]

                    GridLayout {
                        id: grid
                        property alias cboChannel: _cboChannel
                        property alias channelIndex: _cboChannel.currentIndex
                        property var configItemName: modelData.name.toLowerCase()
                        property var values: ({}) // { "left": leftSpinBox, "right": rightSpinBox }

                        columns: 4

                        Repeater {
                            model: [modelData.name, ...modelData.valuesNames]

                            Text {
                                Layout.alignment: Qt.AlignCenter
                                color: "#ffffff"
                                font.pixelSize: 22
                                text: modelData
                            }
                        }

                        Repeater {
                            model: 3 - modelData.valuesNames.length
                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        ComboBox {
                            property int lastIndex: 0

                            id: _cboChannel

                            //Layout.fillWidth: true
                            Layout.minimumWidth: 180
                            Layout.minimumHeight: 50

                            model: ListModel {
                                ListElement { text: " - " }
                                ListElement { text: "CH5" }
                                ListElement { text: "CH6" }
                                ListElement { text: "CH7" }
                                ListElement { text: "CH8" }
                                ListElement { text: "CH9" }
                                ListElement { text: "CH10" }
                                ListElement { text: "CH11" }
                                ListElement { text: "CH12" }
                                ListElement { text: "CH13" }
                                ListElement { text: "CH14" }
                                ListElement { text: "CH15" }
                                ListElement { text: "CH16" }
                                ListElement { text: "CH17" }
                                ListElement { text: "CH18" }
                            }

                            currentIndex: 0

                            Component.onCompleted: {
                                lastIndex = currentIndex;
                            }

                            onActivated: {
                                onChannelChanged(_cboChannel, currentIndex);
                            }
                        }

                        Repeater {
                            model: modelData.valuesNames

                            SpinBox {
                                id: spinBox
                                //Layout.fillWidth: true
                                Layout.minimumHeight: 50

                                editable: true
                                from: 1000
                                to: 2000
                                textFromValue: function(value) {return value;}

                                Settings {
                                    category: `${settingsRoot}/Config/${configItemName}/${modelData.toLowerCase()}`
                                    property alias value: spinBox.value
                                }
                            }

                            onItemAdded: (index, item) => {
                                 // values = { "left": leftSpinBox, "right": rightSpinBox }
                                 grid.values[model[index].toLowerCase()] = item;
                            }
                        }

                        Repeater {
                            model: 4 - modelData.valuesNames.length
                            Item {
                                //Layout.fillWidth: true
                            }
                        }

                        Settings {
                            category: `${settingsRoot}/Config/${modelData.name}`
                            property alias channel: _cboChannel.currentIndex
                        }
                    }

                    onItemAdded: (index, item) => {
                         configPage.config[model[index].name.toLowerCase()] = item;
                    }
                }
            }
        }
   }
}
