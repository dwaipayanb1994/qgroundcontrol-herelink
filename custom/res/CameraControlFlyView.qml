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

    QGCPalette { id: qgcPal }

    Repeater {
       model: customPlugin.nbCameras

       Rectangle {
           id: mainRect

           property int cameraId: index
           property bool isConfigModeOn: false
           property string settingsRoot: `CameraControls/Camera${cameraId}`

           function switchMode()
           {
               mainRect.isConfigModeOn = !mainRect.isConfigModeOn;
           }

           function setChannelValue(channelIndex, value)
           {
               customPlugin.setChannelValue(channelIndex === 0 ? -1 : channelIndex + 4, value);
           }

           function onButtonAction(action, pressed)
           {
               let config, firstValue;

               if(action === "left" || action === "right")
               {
                   config = configPage.horConfig;
                   firstValue = action === "left";
               }
               else if(action === "up" || action === "down")
               {
                   config = configPage.verConfig;
                   firstValue = action === "up";
               }
               else if(action === "zoom in" || action === "zoom out")
               {
                   config = configPage.zoomConfig;
                   firstValue = action === "zoom in";
               }

               // Special command for zoom: when a zoom button is released, we must send the other button value before default!
               if(config === configPage.zoomConfig && !pressed)
               {
                   setChannelValue(config.channelIndex, firstValue ? config.secondValue : config.firstValue);
               }

               setChannelValue(config.channelIndex,
                               pressed ? (firstValue ? config.firstValue : config.secondValue) : config.defaultValue);
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
               }


               // Navigation Controls (Left, up, right, down)
               Repeater {
                  model: [
                      {name: 'up', icon: 'ArrowUp', top: true, horizontalCenter: true},
                      {name: 'left', icon: 'ArrowLeft', left: true, verticalCenter: true},
                      {name: 'right', icon: 'ArrowRight', right: true, verticalCenter: true},
                      {name: 'down', icon: 'ArrowDown', bottom: true, horizontalCenter: true}
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

                      onPressed: onButtonAction(modelData.name, true)
                      onReleased: onButtonAction(modelData.name, false)
                  }
               }
           }

           // Zoom In/Out
           Repeater {
              model: [
                  {name: 'zoom in', icon: 'ZoomIn', top: true},
                  {name: 'zoom out', icon: 'ZoomOut', bottom: true},
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

                  onPressed: onButtonAction(modelData.name, true)
                  onReleased: onButtonAction(modelData.name, false)
              }
           }

           // Config page
           ColumnLayout {
               id: configPage

               property var horConfig: null
               property var verConfig: null
               property var zoomConfig: null

               anchors.left: parent.left
               anchors.top: parent.top
               anchors.leftMargin: 30
               anchors.topMargin: 30
               visible: mainRect.isConfigModeOn

               function onChannelChanged(cboChannel, currentIndex)
               {
                   if(currentIndex === 0)
                       return;

                   const duplicatedChannel = ![horConfig.cboChannel, verConfig.cboChannel, zoomConfig.cboChannel]
                   .filter(c => c !== cboChannel)
                   .every(c => c.currentIndex !== currentIndex);

                   // Check if channel is already used
                   if(duplicatedChannel)
                   {                       
                       messageDialog.text = `Channel ${currentIndex+4} is already used!`;
                       messageDialog.open();
                       cboChannel.currentIndex = cboChannel.lastIndex;
                   }
                   else
                   {
                       // Reset previous channel so it goes back to failsafe
                       mainRect.setChannelValue(cboChannel.lastIndex, 0);

                       // Remember previous channel
                       cboChannel.lastIndex = cboChannel.currentIndex;
                   }
               }

               MessageDialog {
                   id: messageDialog
               }

               Repeater {
                   model: [
                       {name: 'Horizontal', firstValueName: 'Left', secondValueName: 'Right'},
                       {name: 'Vertical', firstValueName: 'Up', secondValueName: 'Down'},
                       {name: 'Zoom', firstValueName: 'In', secondValueName: 'Out'},
                   ]

                   onItemAdded: (index, item) => {
                        if(index === 0)
                            configPage.horConfig = item;
                        else if(index === 1)
                            configPage.verConfig = item;
                        else if(index === 2)
                            configPage.zoomConfig = item;
                   }

                   GridLayout {
                       property alias cboChannel: _cboChannel
                       property alias channelIndex: _cboChannel.currentIndex
                       property alias firstValue: _nbrFirstValue.value
                       property alias secondValue: _nbrSecondValue.value
                       property alias defaultValue: _nbrDefaultValue.value

                       columns: 4

                       Text {
                           Layout.alignment: Qt.AlignCenter
                           color: "#ffffff"
                           font.pixelSize: 22
                           text: modelData.name
                       }

                       Text {
                           Layout.alignment: Qt.AlignCenter
                           color: "#ffffff"
                           font.pixelSize: 22
                           text: modelData.firstValueName
                       }

                       Text {
                           Layout.alignment: Qt.AlignCenter
                           color: "#ffffff"
                           font.pixelSize: 22
                           text: modelData.secondValueName
                       }

                       Text {
                           Layout.alignment: Qt.AlignCenter
                           text: "Default"
                           color: "#ffffff"
                           font.pixelSize: 22
                       }

                       ComboBox {
                           property int lastIndex: -1

                           id: _cboChannel

                           Layout.fillWidth: true
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

                           onCurrentIndexChanged: {
                               // Init lastIndex
                               if(lastIndex === -1)
                                   lastIndex = currentIndex;
                           }

                           onActivated: {
                               configPage.onChannelChanged(_cboChannel, currentIndex);
                           }
                       }

                       SpinBox {
                           id: _nbrFirstValue

                           Layout.fillWidth: true
                           Layout.minimumHeight: 50

                           editable: true
                           from: 1000
                           to: 2000
                           textFromValue: function(value) {return value;}
                       }

                       SpinBox {
                           id: _nbrSecondValue

                           Layout.fillWidth: true
                           Layout.minimumHeight: 50

                           editable: true
                           from: 1000
                           to: 2000
                           textFromValue: function(value) {return value;}
                       }

                       SpinBox {
                           id: _nbrDefaultValue

                           Layout.fillWidth: true
                           Layout.minimumHeight: 50

                           editable: true
                           from: 1000
                           to: 2000
                           textFromValue: function(value) {return value;}
                       }

                       Settings {
                           category: `${settingsRoot}/Config/${modelData.name}`
                           property alias channel: _cboChannel.currentIndex
                           property alias firstValue: _nbrFirstValue.value
                           property alias secondValue: _nbrSecondValue.value
                           property alias defaultValue: _nbrDefaultValue.value
                       }
                   }
               }
           }
       }
   }
}
