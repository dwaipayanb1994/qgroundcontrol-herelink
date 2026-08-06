import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Layouts          1.11
import QtQuick.Dialogs          1.2

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

Item {
    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _utgCommunication: _activeVehicle ? _activeVehicle.utgCommunication : null
    property var _utgSettings:      QGroundControl.settingsManager.utgSettings
    property bool _utgEnabled:      _utgSettings ? _utgSettings.enabled.rawValue : false
    property bool _utgConnected:    _utgCommunication ? _utgCommunication.connected : false
    property real _currentThickness: _utgCommunication ? _utgCommunication.currentThickness : 0.0
    property bool _continuousMeasuring: _utgCommunication ? _utgCommunication.continuousMeasurement : false

    property var _readingManager:   _utgCommunication ? _utgCommunication.readingManager : null
    property int _readingCount:     _readingManager ? _readingManager.count : 0
    property string _currentZone: "Zone A"
    property int _zoneCounter: 1
    property string _pendingReadingNotes: ""

    // Persistent device information storage
    property string _savedDeviceVersion: ""
    property string _savedSerialNumber: ""
    property string _savedFirmwareVersion: ""
    property string _savedMcpLeverVersion: ""
    property string _savedSwid: ""

    function getAllDeviceInformation() {
        if (!_utgCommunication || !_utgConnected) {
            return
        }

        _utgCommunication.getDeviceInfo()
        _utgCommunication.getSerialNumber()
        _utgCommunication.getFirmwareVersion()
        _utgCommunication.getMCPLeverVersion()
        _utgCommunication.getSWID()
        _utgCommunication.getProbeModel()
        _utgCommunication.getVelocity()
    }

    function normalizeVelocity(value) {
        var parsed = parseInt(value)
        if (isNaN(parsed)) {
            return 5920
        }
        return parsed
    }

    function updateZoneCounter() {
        if (!_readingManager) {
            return
        }
        var maxCounter = 0
        for (var i = 0; i < _readingManager.count; i++) {
            var note = _readingManager.notesAt(i)
            if (note && note.indexOf(_currentZone) === 0) {
                var parts = note.split(" ")
                if (parts.length >= 3) {
                    var num = parseInt(parts[2])
                    if (!isNaN(num) && num > maxCounter) {
                        maxCounter = num
                    }
                }
            }
        }
        _zoneCounter = maxCounter + 1
    }

    function deleteReading(index) {
        if (_readingManager) {
            _readingManager.removeReading(index)
            updateZoneCounter()
        }
    }

    function clearAllReadings() {
        if (_readingManager) {
            _readingManager.clearAll()
        }
        _zoneCounter = 1
    }

    Connections {
        target: _readingManager
        onReadingsLoaded: updateZoneCounter()
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: updateZoneCounter()
    }

    Connections {
        target: _utgCommunication
        onReadingSaved: updateZoneCounter()
        onConnectionStatusChanged: {
            if (_utgCommunication && _utgCommunication.connected) {
                saveDeviceInformation()
            }
        }
    }

    anchors.fill: parent

    MessageDialog {
        id: messageDialog
    }

    QGCPalette { id: qgcPal }

    visible: _utgEnabled

    // Function to save device information to persistent storage
    function saveDeviceInformation() {
        if (!_utgCommunication) {
            return
        }

        if (_utgCommunication.deviceVersion && _utgCommunication.deviceVersion !== "") {
            _savedDeviceVersion = _utgCommunication.deviceVersion
        }
        if (_utgCommunication.serialNumber && _utgCommunication.serialNumber !== "") {
            _savedSerialNumber = _utgCommunication.serialNumber
        }
        if (_utgCommunication.firmwareVersion && _utgCommunication.firmwareVersion !== "") {
            _savedFirmwareVersion = _utgCommunication.firmwareVersion
        }
        if (_utgCommunication.mcpLeverVersion && _utgCommunication.mcpLeverVersion !== "") {
            _savedMcpLeverVersion = _utgCommunication.mcpLeverVersion
        }
        if (_utgCommunication.swid && _utgCommunication.swid !== "") {
            _savedSwid = _utgCommunication.swid
        }
    }

    Connections {
        target: _utgCommunication
        onSerialNumberChanged: saveDeviceInformation()
    }

    Rectangle {
        id: mainThicknessRectangle

        x: 140
        y: 100
        color: qgcPal.window
        radius: 12
        width: Math.min(parent.width * 0.45, 480)
        height: Math.min(parent.height * 0.40, 320)
        clip: true

        border.color: _utgConnected ? qgcPal.colorGreen : (_utgEnabled ? qgcPal.colorOrange : qgcPal.colorGrey)
        border.width: 3

        MouseArea {
            anchors.fill: parent
            drag.target: mainThicknessRectangle
            drag.axis: Drag.XAndYAxis
        }

        Column {
            id: mainColumn
            width: parent.width - (ScreenTools.defaultFontPixelWidth * 1.6)
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.8
            spacing: ScreenTools.defaultFontPixelHeight * 0.4

            // Header with History Icon and Title
            Row {
                width: parent.width - (ScreenTools.defaultFontPixelHeight * 2.5)
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                // Readings Icon (Top Left) - Waypoint icon (represents multiple data points)
                Rectangle {
                    width: ScreenTools.defaultFontPixelHeight * 1.6
                    height: ScreenTools.defaultFontPixelHeight * 1.6
                    color: qgcPal.button
                    radius: width / 2
                    border.color: qgcPal.text
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width: parent.width * 0.55
                        height: parent.height * 0.55
                        source: "/res/waypoint.svg"
                        color: qgcPal.text
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: readingsOverlay.visible = true
                    }
                }

                QGCLabel {
                    text: qsTr("UTG Thickness")
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.mediumFontPointSize
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: _utgConnected ? qgcPal.colorGreen : (_utgEnabled ? qgcPal.colorOrange : qgcPal.colorGrey)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Main reading display
            Rectangle {
                width: parent.width
                height: 60
                color: qgcPal.windowShade
                radius: 6

                Column {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        id: readingValue
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (!_utgEnabled) {
                                return "Disabled"
                            }
                            if (!_utgConnected) {
                                return "Disconnected"
                            }
                            if (!_utgSettings) {
                                return "No Settings"
                            }

                            var detectedUnit = _utgCommunication && _utgCommunication.detectedUnit ? _utgCommunication.detectedUnit : ""
                            var settingsUnit = _utgSettings.measurementUnit ? _utgSettings.measurementUnit.enumStringValue : "mm"
                            var unit = detectedUnit || settingsUnit
                            var precision = _utgSettings.displayPrecision ? _utgSettings.displayPrecision.rawValue : 2

                            return _currentThickness.toFixed(precision) + " " + unit
                        }
                        font.pointSize: ScreenTools.mediumFontPointSize * 1.2
                        font.bold: true
                        color: _utgConnected ? qgcPal.text : qgcPal.colorGrey
                    }


                }
            }

            // Control buttons - Reorganized layout
            Column {
                width: parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.15

                // Row 1: Connect/Disconnect (full width)
                QGCButton {
                    text: _utgConnected ? "Disconnect" : "Connect"
                    width: parent.width
                    height: ScreenTools.defaultFontPixelHeight * 1.8
                    onClicked: {
                        if (!_utgConnected) {
                            if (_utgCommunication) _utgCommunication.connectToUTG()
                        } else {
                            if (_utgCommunication) _utgCommunication.disconnectFromUTG()
                        }
                    }
                }

                // Row 2: Single and Fast (side by side)
                Row {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelWidth * 0.4

                    QGCButton {
                        text: "Single"
                        enabled: _utgCommunication !== null && _utgConnected
                        width: (parent.width - parent.spacing) / 2
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        onClicked: {
                            if (_utgCommunication && _utgConnected) {
                                _pendingReadingNotes = _currentZone + " " + _zoneCounter
                                _utgCommunication.takeMeasurement()
                            }
                        }
                    }

                    QGCButton {
                        text: _continuousMeasuring ? "Stop Fast" : "Fast"
                        enabled: _utgCommunication !== null && _utgConnected
                        width: (parent.width - parent.spacing) / 2
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        onClicked: {
                            if (_utgCommunication && _utgConnected) {
                                if (_continuousMeasuring) {
                                    _utgCommunication.stopContinuousMeasurement()
                                } else {
                                    _utgCommunication.startContinuousMeasurement()
                                }
                            }
                        }
                    }
                }
            }

        }

        // Settings Gear Icon (Top Right Corner) - Outside Column
        Rectangle {
            width: ScreenTools.defaultFontPixelHeight * 1.6
            height: ScreenTools.defaultFontPixelHeight * 1.6
            color: qgcPal.button
            radius: width / 2
            border.color: qgcPal.text
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.8
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.8

            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.55
                height: parent.height * 0.55
                source: "/res/gear-white.svg"
                color: qgcPal.text
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onClicked: settingsDialog.open()
            }
        }
    }

    // UTG Settings Popup Background
    Rectangle {
        id: settingsDialogBackground
        anchors.fill: parent
        color: "#80000000"  // Semi-transparent black (50% opacity) - no animation
        z: 999
        enabled: settingsDialog._isOpen
        visible: settingsDialog._isOpen

        // Disable all implicit animations and transitions
        Behavior on opacity { enabled: false }
        Behavior on visible { enabled: false }
        Behavior on enabled { enabled: false }
        Behavior on color { enabled: false }
        layer.enabled: false

        // Prevent any parent transitions
        transform: []
        transformOrigin: Item.Center

        MouseArea {
            anchors.fill: parent
            enabled: settingsDialogBackground.visible
            onClicked: settingsDialog.cancelSettings()
        }
    }

    // UTG Settings Popup
    Rectangle {
        id: settingsDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, ScreenTools.defaultFontPixelWidth * 50)
        height: Math.min(parent.height * 0.8, ScreenTools.defaultFontPixelHeight * 40)
        color: qgcPal.window
        border.color: qgcPal.text
        border.width: 1
        radius: ScreenTools.defaultFontPixelHeight * 0.5
        z: 1000

        // Control visibility through custom property to avoid QML animations
        property bool _isOpen: false
        visible: _isOpen
        enabled: _isOpen
        opacity: 1.0  // Always full opacity - no fade transitions
        rotation: 0   // Always 0 rotation - no spin animations

        // Disable all implicit animations and transitions
        Behavior on opacity { enabled: false }
        Behavior on visible { enabled: false }
        Behavior on enabled { enabled: false }
        Behavior on x { enabled: false }
        Behavior on y { enabled: false }
        Behavior on scale { enabled: false }
        Behavior on rotation { enabled: false }
        layer.enabled: false

        property int _originalSoundVelocity: 5920
        property var _originalProbeModel: 0
        property bool _refreshingSettings: false
        property string _refreshStatus: "Applying settings to UTG device..."
        property bool _pendingVelocityApply: false
        property bool _pendingProbeApply: false
        // Draft value edited in the field; Apply compares this to _originalSoundVelocity
        property int _draftSoundVelocity: 5920

        Connections {
            target: _utgCommunication
            // Qt 5.11-compatible Connections syntax (function onX{} needs Qt 5.15+)
            onVelocityApplied: {
                var applied = normalizeVelocity(velocity)
                settingsDialog._originalSoundVelocity = applied
                settingsDialog._draftSoundVelocity = applied
                settingsDialog._pendingVelocityApply = false
                if (_utgSettings && _utgSettings.soundVelocity) {
                    _utgSettings.soundVelocity.rawValue = applied
                }
                if (!soundVelocityField.activeFocus) {
                    soundVelocityField.text = applied.toString()
                }
                settingsDialog.checkApplyComplete()
            }
            onResponseReceived: {
                if (command === "V1" && response.indexOf(" A") !== -1) {
                    var applied = normalizeVelocity(_utgCommunication ? _utgCommunication.velocity : settingsDialog._draftSoundVelocity)
                    settingsDialog._originalSoundVelocity = applied
                    settingsDialog._draftSoundVelocity = applied
                    settingsDialog._pendingVelocityApply = false
                    if (!soundVelocityField.activeFocus) {
                        soundVelocityField.text = applied.toString()
                    }
                    settingsDialog.checkApplyComplete()
                } else if (command === "P1" && response.indexOf(" A") !== -1) {
                    if (_utgSettings && _utgSettings.probeModel) {
                        settingsDialog._originalProbeModel = _utgSettings.probeModel.rawValue
                    }
                    settingsDialog._pendingProbeApply = false
                    settingsDialog.checkApplyComplete()
                }
            }
            onVelocityChanged: {
                if (!settingsDialog._isOpen) {
                    return
                }
                var vel = normalizeVelocity(velocity)
                // During refresh/open sync, adopt device value as baseline
                if (settingsDialog._refreshingSettings || settingsDialog._isRefreshing) {
                    settingsDialog._originalSoundVelocity = vel
                    settingsDialog._draftSoundVelocity = vel
                    if (!soundVelocityField.activeFocus) {
                        soundVelocityField.text = vel.toString()
                    }
                    settingsDialog._finishSettingsRefresh()
                    return
                }
                if (!soundVelocityField.activeFocus && !settingsDialog._pendingVelocityApply) {
                    soundVelocityField.text = vel.toString()
                }
            }
        }

        Timer {
            id: refreshTimer
            interval: 3000
            repeat: false
            onTriggered: settingsDialog._finishSettingsRefresh()
        }

        Timer {
            id: applyTimeoutTimer
            interval: 5000
            repeat: false
            onTriggered: {
                if (settingsDialog._pendingVelocityApply || settingsDialog._pendingProbeApply) {
                    settingsDialog._pendingVelocityApply = false
                    settingsDialog._pendingProbeApply = false
                    settingsDialog._refreshStatus = qsTr("Apply timed out - device did not confirm")
                    settingsDialog._refreshingSettings = false
                }
            }
        }

        property bool _isRefreshing: false

        property bool _hasUnsavedChanges: {
            if (!_utgSettings) {
                return false
            }
            var velocityChanged = normalizeVelocity(_draftSoundVelocity) !== normalizeVelocity(_originalSoundVelocity)
            var probeChanged = _utgSettings.probeModel && _utgSettings.probeModel.rawValue !== _originalProbeModel
            return velocityChanged || probeChanged
        }

        function storeCurrentAsOriginal() {
            if (_utgSettings) {
                _originalSoundVelocity = _utgSettings.soundVelocity ? normalizeVelocity(_utgSettings.soundVelocity.rawValue) : 5920
                _originalProbeModel = _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : 0
                _draftSoundVelocity = _originalSoundVelocity
                if (soundVelocityField && !soundVelocityField.activeFocus) {
                    soundVelocityField.text = _originalSoundVelocity.toString()
                }
            }
        }

        function _finishSettingsRefresh() {
            if (!_isRefreshing && !_refreshingSettings) {
                return
            }
            refreshTimer.stop()
            _refreshingSettings = false
            _isRefreshing = false
            // Only reset draft from settings if user has not already edited
            if (normalizeVelocity(_draftSoundVelocity) === normalizeVelocity(_originalSoundVelocity)) {
                storeCurrentAsOriginal()
            }
        }

        function checkApplyComplete() {
            if (!settingsDialog._pendingVelocityApply && !settingsDialog._pendingProbeApply) {
                applyTimeoutTimer.stop()
                settingsDialog._refreshStatus = qsTr("Settings applied successfully")
                settingsDialog._refreshingSettings = false
                settingsDialog._isRefreshing = false
                settingsDialog._originalSoundVelocity = settingsDialog._draftSoundVelocity
            }
        }

        function _setSettingsPushDeferred(deferred) {
            if (_utgCommunication) {
                _utgCommunication.setSettingsPushDeferred(deferred)
            }
        }

        function open() {
            _isOpen = true
            _setSettingsPushDeferred(true)
            storeCurrentAsOriginal()
            if (_utgCommunication && _utgConnected) {
                refreshSettingsFromDevice()
            }
        }

        function closeDialog() {
            _setSettingsPushDeferred(false)
            _isOpen = false
        }

        function refreshSettingsFromDevice() {
            if (_utgCommunication && _utgConnected) {
                _refreshingSettings = true
                _isRefreshing = true
                _refreshStatus = qsTr("Refreshing settings from UTG device...")
                getAllDeviceInformation()
                refreshTimer.start()
            }
        }

        function saveSettings() {
            if (_utgCommunication && _utgConnected && _utgSettings) {
                // Commit field text into draft before comparing
                if (soundVelocityField.text !== "") {
                    var typed = normalizeVelocity(soundVelocityField.text)
                    if (typed >= 1000 && typed <= 10000) {
                        _draftSoundVelocity = typed
                        _utgSettings.soundVelocity.rawValue = typed
                    }
                }

                _refreshingSettings = true
                _refreshStatus = qsTr("Applying settings to UTG device...")
                var changeCount = 0
                _pendingVelocityApply = false
                _pendingProbeApply = false

                if (normalizeVelocity(_draftSoundVelocity) !== normalizeVelocity(_originalSoundVelocity)) {
                    _utgCommunication.setVelocityCommand(_draftSoundVelocity)
                    _pendingVelocityApply = true
                    changeCount++
                }

                if (_utgSettings.probeModel && _utgSettings.probeModel.rawValue !== _originalProbeModel) {
                    var probeModels = ["P5EE", "N05", "N07", "HT5", "N02"]
                    _utgCommunication.setProbeModel(probeModels[_utgSettings.probeModel.rawValue])
                    _pendingProbeApply = true
                    changeCount++
                }

                if (changeCount > 0) {
                    applyTimeoutTimer.start()
                } else {
                    _refreshingSettings = false
                }
            }
        }

        function cancelSettings() {
            _setSettingsPushDeferred(false)
            if (_utgSettings) {
                if (_utgSettings.soundVelocity) _utgSettings.soundVelocity.rawValue = _originalSoundVelocity
                if (_utgSettings.probeModel) _utgSettings.probeModel.rawValue = _originalProbeModel
            }
            _draftSoundVelocity = _originalSoundVelocity
            if (soundVelocityField) {
                soundVelocityField.text = _originalSoundVelocity.toString()
            }
            _isOpen = false
        }

        Column {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelHeight

            // Title
            Column {
                id: titleSection
                width: parent.width

                QGCLabel {
                    text: settingsDialog._hasUnsavedChanges ? "UTG Settings *" : "UTG Settings"
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.mediumFontPointSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: settingsDialog._hasUnsavedChanges ? qgcPal.warningText : qgcPal.text
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: qgcPal.text
                }
            }

            // Content
            ScrollView {
                width: parent.width
                height: parent.height - titleSection.height - buttonSection.height - ScreenTools.defaultFontPixelHeight
                clip: true

                Column {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelHeight

                GroupBox {
                    title: qsTr("Device Information")
                    width: parent.width
                    visible: _utgConnected || _savedDeviceVersion !== ""

                    GridLayout {
                        columns: 2
                        width: parent.width
                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.5
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.2

                        QGCLabel {
                            text: "Device:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.deviceVersion !== "" ? _utgCommunication.deviceVersion : (_savedDeviceVersion !== "" ? _savedDeviceVersion : "N/A")
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }

                        QGCLabel {
                            text: "Serial:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.serialNumber !== "" ? _utgCommunication.serialNumber : (_savedSerialNumber !== "" ? _savedSerialNumber : "N/A")
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }

                        QGCLabel {
                            text: "Firmware:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.firmwareVersion !== "") || _savedFirmwareVersion !== ""
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.firmwareVersion !== "" ? _utgCommunication.firmwareVersion : (_savedFirmwareVersion !== "" ? _savedFirmwareVersion : "N/A")
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.firmwareVersion !== "") || _savedFirmwareVersion !== ""
                        }

                        QGCLabel {
                            text: "MCP:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.mcpLeverVersion !== "") || _savedMcpLeverVersion !== ""
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.mcpLeverVersion !== "" ? _utgCommunication.mcpLeverVersion : (_savedMcpLeverVersion !== "" ? _savedMcpLeverVersion : "N/A")
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.mcpLeverVersion !== "") || _savedMcpLeverVersion !== ""
                        }

                        QGCLabel {
                            text: "SWID:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.swid !== "") || _savedSwid !== ""
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.swid !== "" ? _utgCommunication.swid : (_savedSwid !== "" ? _savedSwid : "N/A")
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            visible: (_utgCommunication && _utgCommunication.swid !== "") || _savedSwid !== ""
                        }

                        QGCLabel {
                            text: "Unit:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                        QGCLabel {
                            text: _utgCommunication ? _utgCommunication.detectedUnit : "N/A"
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }

                        QGCLabel {
                            text: "Velocity:"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                        QGCLabel {
                            text: _utgCommunication && _utgCommunication.velocity > 0 ? _utgCommunication.velocity.toFixed(0) + " m/s" : "N/A"
                            color: qgcPal.colorGrey
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                    }
                }

                GroupBox {
                    title: qsTr("Connection")
                    width: parent.width

                    GridLayout {
                        columns: 2
                        width: parent.width

                        QGCLabel { text: "Status:" }
                        QGCLabel {
                            text: _utgCommunication ? (_utgConnected ? "Connected" : "Disconnected") : "No UTG"
                            color: _utgConnected ? qgcPal.colorGreen : qgcPal.colorOrange
                        }

                        QGCLabel { text: "Communication:" }
                        QGCLabel {
                            Layout.fillWidth: true
                            text: "MAVLink Pass-through"
                            color: qgcPal.colorGrey
                        }

                        QGCButton {
                            text: _utgConnected ? "Disconnect" : "Connect"
                            Layout.fillWidth: true
                            onClicked: {
                                if (_utgCommunication) {
                                    if (_utgConnected) {
                                        _utgCommunication.disconnectFromUTG()
                                    } else {
                                        _utgCommunication.connectToUTG()
                                    }
                                }
                            }
                        }

                        QGCButton {
                            text: "Refresh Settings"
                            Layout.fillWidth: true
                            enabled: _utgConnected
                            onClicked: settingsDialog.refreshSettingsFromDevice()
                        }
                    }
                }

                GroupBox {
                    title: qsTr("Measurement")
                    width: parent.width
                    enabled: _utgConnected

                    GridLayout {
                        columns: 2
                        width: parent.width

                        QGCLabel { text: qsTr("Sound Velocity (m/s):") }
                        QGCTextField {
                            id: soundVelocityField
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            placeholderText: "1000-10000"
                            validator: IntValidator {
                                bottom: 1000
                                top: 10000
                            }
                            onTextChanged: {
                                if (activeFocus && text !== "") {
                                    var newValue = parseInt(text)
                                    if (!isNaN(newValue)) {
                                        settingsDialog._draftSoundVelocity = newValue
                                    }
                                }
                            }
                            onEditingFinished: {
                                if (text !== "") {
                                    var newValue = parseInt(text)
                                    if (newValue >= 1000 && newValue <= 10000) {
                                        settingsDialog._draftSoundVelocity = newValue
                                        if (_utgSettings && _utgSettings.soundVelocity) {
                                            _utgSettings.soundVelocity.rawValue = newValue
                                        }
                                    } else {
                                        text = settingsDialog._draftSoundVelocity.toString()
                                    }
                                }
                            }
                        }

                        Connections {
                            target: _utgSettings ? _utgSettings.soundVelocity : null
                            onRawValueChanged: {
                                if (!soundVelocityField.activeFocus && !settingsDialog._pendingVelocityApply) {
                                    var vel = normalizeVelocity(_utgSettings.soundVelocity.rawValue)
                                    // Don't clobber an in-progress user edit relative to original
                                    if (normalizeVelocity(settingsDialog._draftSoundVelocity) === normalizeVelocity(settingsDialog._originalSoundVelocity)) {
                                        settingsDialog._draftSoundVelocity = vel
                                        soundVelocityField.text = vel.toString()
                                    }
                                }
                            }
                        }

                        QGCLabel { text: qsTr("Probe Model:") }
                        QGCComboBox {
                            Layout.fillWidth: true
                            model: ["P5EE", "N05", "N07", "HT5", "N02"]
                            currentIndex: _utgSettings && _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : 0
                            onCurrentIndexChanged: {
                                if (_utgSettings && _utgSettings.probeModel) {
                                    _utgSettings.probeModel.rawValue = currentIndex
                                }
                            }
                        }

                        QGCLabel { text: qsTr("Current Zone:") }
                        QGCTextField {
                            Layout.fillWidth: true
                            text: _currentZone
                            placeholderText: qsTr("Enter zone name...")
                            onEditingFinished: {
                                _currentZone = text
                                _zoneCounter = 1
                            }
                        }

                    }
                }

                // Removed duplicate Signal Parameters group

                GroupBox {
                    title: qsTr("Calibration")
                    width: parent.width
                    enabled: _utgConnected

                    Column {
                        width: parent.width
                        spacing: ScreenTools.defaultFontPixelHeight * 0.5

                        // Simplified calibration - just the essential controls

                        GridLayout {
                            width: parent.width
                            columns: 2
                            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.5
                            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

                            QGCButton {
                                text: "Zero Calibration"
                                Layout.fillWidth: true
                                ToolTip.text: qsTr("Sends UTG Z command (probe zero). Hold the probe on the 4 mm calibration block, then press.")
                                ToolTip.visible: hovered
                                onClicked: {
                                    if (_utgCommunication) {
                                        _utgCommunication.performZeroCalibration()
                                    }
                                }
                            }

                            QGCButton {
                                text: "Reset Device"
                                Layout.fillWidth: true
                                onClicked: {
                                    if (_utgCommunication) {
                                        _utgCommunication.resetDevice()
                                    }
                                }
                            }
                        }
                    }
                }
                }  // End Column inside ScrollView
            }  // End ScrollView

            // Spacer
            Item {
                width: parent.width
                height: ScreenTools.defaultFontPixelHeight * 0.5
            }

            // Buttons
            Rectangle {
                id: buttonSection
                width: parent.width
                height: ScreenTools.defaultFontPixelHeight * 4
                color: "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight * 0.3

                    QGCLabel {
                        text: settingsDialog._hasUnsavedChanges ? "⚠️ Unsaved changes" : "✅ No changes"
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: settingsDialog._hasUnsavedChanges ? qgcPal.colorOrange : qgcPal.colorGreen
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: settingsDialog._hasUnsavedChanges ? "Apply *" : "Apply"
                            width: ScreenTools.defaultFontPixelWidth * 8
                            height: ScreenTools.defaultFontPixelHeight * 2
                            enabled: settingsDialog._hasUnsavedChanges && !settingsDialog._refreshingSettings
                            onClicked: settingsDialog.saveSettings()
                            primary: settingsDialog._hasUnsavedChanges
                        }

                        QGCButton {
                            text: "Close"
                            width: ScreenTools.defaultFontPixelWidth * 8
                            height: ScreenTools.defaultFontPixelHeight * 2
                            enabled: !settingsDialog._refreshingSettings
                            onClicked: settingsDialog.cancelSettings()
                        }
                    }
                }
            }


        }

        // Refresh overlay
        Rectangle {
            visible: settingsDialog._refreshingSettings
            anchors.fill: parent
            color: "black"
            opacity: 0.7
            z: 1000
            rotation: 0

            Column {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelHeight
                rotation: 0

                Item {
                    id: refreshSpinner
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ScreenTools.defaultFontPixelHeight * 3
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "white"
                        border.width: 3
                        radius: width / 2
                    }

                    Rectangle {
                        width: parent.width / 4
                        height: parent.height / 4
                        color: "white"
                        radius: width / 2
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 3
                    }

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: settingsDialog._refreshingSettings
                        onRunningChanged: {
                            if (!running) {
                                refreshSpinner.rotation = 0
                            }
                        }
                    }
                }

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: settingsDialog._refreshStatus
                    color: "white"
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Please wait..."
                    color: "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity: 0.8
                }
            }
        }
    }





    // Reading List Overlay
    Rectangle {
        id: readingsOverlay
        anchors.fill: parent
        color: qgcPal.window
        visible: false
        z: 1000  // High z-order to appear on top
        opacity: 1.0  // Always full opacity - no fade transitions

        // Disable all implicit animations and transitions
        Behavior on opacity { enabled: false }
        Behavior on visible { enabled: false }
        Behavior on x { enabled: false }
        Behavior on y { enabled: false }

        // Prevent any parent-level transitions from affecting this overlay
        layer.enabled: false

        // Readings are loaded asynchronously when the vehicle connects.

        // Handle back key/escape
        Keys.onPressed: {
            if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
                readingsOverlay.visible = false
                event.accepted = true
            }
        }

        // Make sure overlay can receive key events
        focus: visible

        Column {
            anchors.fill: parent
            spacing: 0

            // Back button and title bar
            Rectangle {
                id: titleBar
                width: parent.width
                height: titleLabel.height + ScreenTools.defaultFontPixelHeight
                color: qgcPal.windowShade
                border.color: qgcPal.text
                border.width: 1

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        width: parent.width * 0.6
                        height: parent.height

                        QGCLabel {
                            id: titleLabel
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                            text: qsTr("UTG Thickness Readings")
                            font.family: ScreenTools.demiboldFontFamily
                            font.pointSize: ScreenTools.largeFontPointSize
                        }
                    }

                    Item {
                        width: parent.width * 0.1
                        height: parent.height
                    }

                    Item {
                        width: parent.width * 0.3
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                            text: qsTr("Total records: ") + _readingCount
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }

            // Header section


            // Table header
            Rectangle {
                width: parent.width
                height: ScreenTools.defaultFontPixelHeight * 2
                color: qgcPal.button
                border.color: qgcPal.text
                border.width: 1

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        width: parent.width * 0.20
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            text: qsTr("Date/Time")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item {
                        width: parent.width * 0.12
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            text: qsTr("Reading (mm)")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Item {
                        width: parent.width * 0.18
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            text: qsTr("GPS Location")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item {
                        width: parent.width * 0.10
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            text: qsTr("Height")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Item {
                        width: parent.width * 0.27
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            text: qsTr("Notes")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item {
                        width: parent.width * 0.13
                        height: parent.height

                        QGCLabel {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                            text: qsTr("Actions")
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // Scrollable readings list
            ScrollView {
                width: parent.width
                height: parent.height - y - (ScreenTools.defaultFontPixelHeight * 3)  // Account for action buttons at bottom

                ListView {
                    id: readingsListView
                    model: _readingManager

                    delegate: Rectangle {
                        width: readingsListView.width
                        height: ScreenTools.defaultFontPixelHeight * 3
                        color: index % 2 === 0 ? qgcPal.window : qgcPal.windowShade
                        border.color: qgcPal.text
                        border.width: 0.5

                        Row {
                            anchors.fill: parent
                            spacing: 0

                            Item {
                                width: parent.width * 0.20
                                height: parent.height

                                QGCLabel {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: datetime
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }

                            Item {
                                width: parent.width * 0.12
                                height: parent.height

                                QGCLabel {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: reading
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Item {
                                width: parent.width * 0.18
                                height: parent.height

                                QGCLabel {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: gpsLocation
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }

                            Item {
                                width: parent.width * 0.10
                                height: parent.height

                                QGCLabel {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: altitude
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }

                            Item {
                                width: parent.width * 0.27
                                height: parent.height

                                QGCTextField {
                                    id: notesField
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: notes
                                    placeholderText: qsTr("Enter notes...")
                                    onEditingFinished: {
                                        if (_readingManager) {
                                            _readingManager.setNotes(index, text)
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width * 0.13
                                height: parent.height

                                Rectangle {
                                    id: deleteButton
                                    width: ScreenTools.defaultFontPixelHeight * 1.5
                                    height: width
                                    radius: width / 2
                                    color: deleteMouseArea.pressed ? "#B71C1C" : (deleteMouseArea.containsMouse ? "#D32F2F" : "#F44336")
                                    border.color: "#B71C1C"
                                    border.width: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Rectangle {
                                        width: parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: "transparent"
                                        border.color: "black"
                                        border.width: 1
                                        opacity: 0.2
                                        anchors.centerIn: parent
                                        anchors.margins: 1
                                    }

                                    Rectangle {
                                        width: deleteButton.width * 0.6
                                        height: 2
                                        color: "white"
                                        anchors.centerIn: parent
                                        rotation: 45
                                    }

                                    Rectangle {
                                        width: deleteButton.width * 0.6
                                        height: 2
                                        color: "white"
                                        anchors.centerIn: parent
                                        rotation: -45
                                    }

                                    MouseArea {
                                        id: deleteMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: deleteReading(index)
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Action buttons section at the bottom
        Rectangle {
            width: parent.width
            height: ScreenTools.defaultFontPixelHeight * 3.8
            color: qgcPal.windowShade
            border.color: qgcPal.text
            border.width: 1
            anchors.bottom: parent.bottom

            Row {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                spacing: 0

                // Back button - Left
                Item {
                    width: parent.width * 0.25
                    height: parent.height

                    QGCButton {
                        id: backButton
                        text: qsTr("← Back")
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        anchors.left: parent.left
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            readingsOverlay.visible = false
                        }
                    }
                }

                // Clear All button - Center
                Item {
                    width: parent.width * 0.25
                    height: parent.height

                    QGCButton {
                        id: clearAllButton
                        text: qsTr("Clear All")
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: true
                        onClicked: clearAllReadings()
                    }
                }

                Item {
                    width: parent.width * 0.5
                    height: parent.height

                    QGCButton {
                        text: qsTr("Refresh")
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        anchors.right: parent.right
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: _readingManager && !_readingManager.loading
                        onClicked: {
                            if (_readingManager) {
                                _readingManager.reloadAsync()
                            }
                        }
                    }
                }
            }
        }
    }
}
