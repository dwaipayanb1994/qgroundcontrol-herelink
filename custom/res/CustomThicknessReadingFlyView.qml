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
    property bool _measuring:       false // UTGCommunication doesn't have continuous measuring state
    property bool _continuousMeasuring: false // Track continuous measurement state

    // Simple reading storage - independent of vehicle connection
    property var _storedReadings: []
    property int _readingCount: 0
    property string _currentZone: "Zone A"
    property int _zoneCounter: 1
    property string _savedReadingsData: ""  // Simulates SD card storage

    // Persistent device information storage
    property string _savedDeviceVersion: ""
    property string _savedSerialNumber: ""
    property string _savedFirmwareVersion: ""
    property string _savedMcpLeverVersion: ""
    property string _savedSwid: ""

    // Debug property changes and auto-save
    on_CurrentThicknessChanged: {
        console.log("*** _currentThickness property changed to:", _currentThickness)
        console.log("*** Source (_utgCommunication.currentThickness):", _utgCommunication ? _utgCommunication.currentThickness : "null")

        // Automatically save new reading to SD card
        if (_currentThickness > 0) {
            console.log("*** Auto-saving new reading to SD card...")
            autoSaveReading(_currentThickness)
        } else {
            console.log("*** Invalid thickness reading, not saving")
        }
    }

    // Function to get all device information when device connects


    // Simple reading storage functions
    function loadStoredReadings() {
        console.log("=== LOADING STORED READINGS ===")

        // Load from centralized storage
        var loadedReadings = loadFromStorage()
        _storedReadings = loadedReadings
        _readingCount = _storedReadings.length

        console.log("Final reading count:", _readingCount)

        // Update zone counter based on existing readings
        updateZoneCounter()
        console.log("=== LOADING COMPLETE ===")
    }

    function updateZoneCounter() {
        var maxCounter = 0
        for (var i = 0; i < _storedReadings.length; i++) {
            var reading = _storedReadings[i]
            if (reading.notes && reading.notes.indexOf(_currentZone) === 0) {
                // Extract number from notes like "Zone A 5"
                var parts = reading.notes.split(" ")
                if (parts.length >= 3) {
                    var num = parseInt(parts[2])
                    if (!isNaN(num) && num > maxCounter) {
                        maxCounter = num
                    }
                }
            }
        }
        _zoneCounter = maxCounter + 1
        console.log("Updated zone counter to:", _zoneCounter)
    }

    function addNewReading(thickness, gpsLat, gpsLon, notes) {
        var newReading = {
            datetime: new Date().toLocaleString(),
            reading: thickness.toString(),
            gpsLocation: gpsLat + ", " + gpsLon,
            notes: notes || ""
        }
        _storedReadings.push(newReading)
        _readingCount = _storedReadings.length
        console.log("Added new reading:", JSON.stringify(newReading))

        // Save to storage immediately
        saveToStorage()
    }

    function saveCurrentReading() {
        console.log("=== SAVE CURRENT ===")
        console.log("Saving current readings list to SD card")
        console.log("Total readings to save:", _storedReadings.length)

        // Simply save whatever is currently in the readings list to storage
        saveToStorage()

        console.log("=== SAVE COMPLETE ===")
    }

    function deleteReading(index) {
        console.log("=== DELETE READING ===")
        console.log("Deleting reading at index:", index)
        console.log("Total readings before delete:", _storedReadings.length)

        if (index >= 0 && index < _storedReadings.length) {
            console.log("Reading to delete:", JSON.stringify(_storedReadings[index]))

            // Create new array without the deleted item (QML ListView needs new array reference)
            var newReadings = []
            for (var i = 0; i < _storedReadings.length; i++) {
                if (i !== index) {
                    newReadings.push(_storedReadings[i])
                }
            }

            // Assign new array to trigger ListView update
            _storedReadings = newReadings
            _readingCount = _storedReadings.length

            console.log("Remaining readings:", _readingCount)
            console.log("=== DELETE COMPLETE ===")

            // Save updated list to storage
            saveToStorage()
        } else {
            console.log("Invalid index:", index, "Array length:", _storedReadings.length)
        }
    }

    function clearAllReadings() {
        _storedReadings = []
        _readingCount = 0
        _zoneCounter = 1
        console.log("All readings cleared")

        // Clear storage
        saveToStorage()
    }

    function addTestEntry() {
        console.log("=== ADD TEST ENTRY ===")

        // Generate random test values
        var thickness = (Math.random() * 20 + 10).toFixed(1)
        var gpsLat = (37.7749 + Math.random() * 0.01).toFixed(6)
        var gpsLon = (-122.4194 + Math.random() * 0.01).toFixed(6)
        var zoneNote = _currentZone + " " + _zoneCounter

        console.log("Adding test entry:", zoneNote, "thickness:", thickness)

        // Add the test reading
        addNewReading(thickness, gpsLat, gpsLon, zoneNote)

        // Increment zone counter for next reading
        _zoneCounter++

        console.log("=== TEST ENTRY ADDED ===")
    }

    function autoSaveReading(thickness) {
        console.log("=== AUTO SAVE READING ===")
        console.log("Auto-saving thickness:", thickness)
        console.log("Current zone:", _currentZone)
        console.log("Zone counter:", _zoneCounter)

        // Get GPS coordinates if available
        var gpsLat = "0.0"
        var gpsLon = "0.0"
        if (_activeVehicle && _activeVehicle.coordinate.isValid) {
            gpsLat = _activeVehicle.coordinate.latitude.toFixed(6)
            gpsLon = _activeVehicle.coordinate.longitude.toFixed(6)
            console.log("Using vehicle GPS:", gpsLat, gpsLon)
        } else {
            console.log("No vehicle GPS available, using default coordinates")
        }

        // Create zone-based note
        var zoneNote = _currentZone + " " + _zoneCounter
        console.log("Creating auto-saved reading with zone note:", zoneNote)

        // Add the reading
        addNewReading(thickness, gpsLat, gpsLon, zoneNote)

        // Increment zone counter for next reading
        _zoneCounter++

        console.log("=== AUTO SAVE COMPLETE ===")
    }

    // ===== CENTRALIZED STORAGE SYSTEM =====
    // Handles all data persistence with dual storage strategy:
    // 1. JSON file for app persistence (machine-readable)
    // 2. CSV file for user export (human-readable)
    // 3. Memory backup for reliability

    readonly property string _jsonFilePath: "/sdcard/UTG_Readings.json"
    readonly property string _csvFilePath: "/sdcard/UTG_Readings.csv"

    /**
     * Save readings to persistent storage
     * Uses triple-redundancy strategy: Memory + JSON file + CSV export
     * @returns {boolean} true if at least memory save succeeded
     */
    function saveToStorage() {
        console.log("=== SAVE TO STORAGE ===")
        console.log("Saving", _storedReadings.length, "readings")
        console.log("Current Zone:", _currentZone, "Counter:", _zoneCounter)

        try {
            // Serialize data to JSON format
            var jsonData = JSON.stringify({
                readings: _storedReadings,
                currentZone: _currentZone,
                zoneCounter: _zoneCounter
            })

            console.log("JSON data size:", jsonData.length, "characters")

            // 1. Store in memory (always works as backup)
            _savedReadingsData = jsonData
            console.log("Memory storage: SUCCESS")

            // 2. Write JSON to SD card for app persistence
            var jsonWriteSuccess = _writeJSONFile(jsonData)

            // 3. Write CSV to SD card for user export
            var csvData = _convertReadingsToCSV(_storedReadings)
            var csvWriteSuccess = _writeCSVFile(csvData)

            // Report results
            if (jsonWriteSuccess && csvWriteSuccess) {
                console.log("SD card storage: SUCCESS (JSON + CSV)")
                console.log("Data will persist across app restarts")
            } else if (jsonWriteSuccess) {
                console.log("SD card storage: PARTIAL (JSON only)")
                console.log("Data will persist but CSV export failed")
            } else {
                console.log("SD card storage: FAILED")
                console.log("Using memory-only storage (data lost on restart)")
            }

            console.log("=== SAVE COMPLETE ===")
            return true

        } catch (error) {
            console.log("=== SAVE ERROR ===")
            console.log("Error:", error)
            return false
        }
    }

    /**
     * Load readings from persistent storage
     * Tries SD card first, falls back to memory
     * @returns {Array} Array of reading objects
     */
    function loadFromStorage() {
        console.log("=== LOAD FROM STORAGE ===")

        try {
            // 1. Try to load from SD card JSON file (primary source)
            var jsonData = _readJSONFile()
            if (jsonData) {
                console.log("SD card storage: FOUND")
                var data = JSON.parse(jsonData)
                if (data.readings) {
                    _currentZone = data.currentZone || "Zone A"
                    _zoneCounter = data.zoneCounter || 1
                    console.log("Loaded zone:", _currentZone, "counter:", _zoneCounter)
                    console.log("Loaded", data.readings.length, "readings from SD card")

                    // Sync to memory backup
                    _savedReadingsData = jsonData

                    console.log("=== LOAD COMPLETE ===")
                    return data.readings
                }
            }

            // 2. Fallback to memory storage
            if (typeof _savedReadingsData !== 'undefined' && _savedReadingsData) {
                console.log("SD card storage: NOT FOUND, using memory backup")
                var data = JSON.parse(_savedReadingsData)
                if (data.readings) {
                    _currentZone = data.currentZone || "Zone A"
                    _zoneCounter = data.zoneCounter || 1
                    console.log("Loaded zone:", _currentZone, "counter:", _zoneCounter)
                    console.log("Loaded", data.readings.length, "readings from memory")
                    console.log("=== LOAD COMPLETE ===")
                    return data.readings
                }
            }

            // 3. No data found anywhere
            console.log("No saved data found - starting fresh")
            console.log("=== LOAD COMPLETE ===")
            return []

        } catch (error) {
            console.log("=== LOAD ERROR ===")
            console.log("Error:", error)
            return []
        }
    }

    /**
     * Convert readings array to CSV format
     * @param {Array} readings - Array of reading objects
     * @returns {string} CSV formatted string
     */
    function _convertReadingsToCSV(readings) {
        console.log("Converting", readings.length, "readings to CSV format")

        try {
            // CSV Header
            var csv = "Date/Time,Thickness (mm),GPS Latitude,GPS Longitude,Notes\n"

            // Add each reading as a CSV row
            for (var i = 0; i < readings.length; i++) {
                var reading = readings[i]

                // Extract GPS coordinates from "lat, lon" format
                var gpsCoords = reading.gpsLocation.split(", ")
                var lat = gpsCoords[0] || "0.0"
                var lon = gpsCoords[1] || "0.0"

                // Escape quotes in notes field and wrap in quotes if contains commas
                var notes = reading.notes || ""
                if (notes.includes(",") || notes.includes("\"")) {
                    notes = "\"" + notes.replace(/"/g, "\"\"") + "\""
                }

                // Add CSV row
                csv += reading.datetime + "," +
                       reading.reading + "," +
                       lat + "," +
                       lon + "," +
                       notes + "\n"
            }

            console.log("CSV conversion complete, size:", csv.length, "characters")
            return csv

        } catch (error) {
            console.log("CSV conversion error:", error)
            return ""
        }
    }

    // ===== PRIVATE FILE I/O FUNCTIONS =====
    // Internal functions for SD card file operations
    // Use XMLHttpRequest with file:// protocol for cross-platform compatibility

    /**
     * Write JSON data to SD card file
     * @param {string} jsonData - JSON string to write
     * @returns {boolean} true if write succeeded
     * @private
     */
    function _writeJSONFile(jsonData) {
        console.log("Writing JSON file:", _jsonFilePath, "(" + jsonData.length, "bytes)")

        try {
            var request = new XMLHttpRequest()
            request.open("PUT", "file://" + _jsonFilePath, false)
            request.setRequestHeader("Content-Type", "application/json")
            request.send(jsonData)

            if (request.status === 0 || request.status === 200) {
                console.log("JSON file write: SUCCESS")
                return true
            } else {
                console.log("JSON file write: FAILED (status:", request.status + ")")
                return false
            }
        } catch (error) {
            console.log("JSON file write: ERROR -", error)
            // Fallback: output to console for manual save
            console.log("=== MANUAL SAVE REQUIRED ===")
            console.log("File:", _jsonFilePath)
            console.log("--- DATA START ---")
            console.log(jsonData)
            console.log("--- DATA END ---")
            return false
        }
    }

    /**
     * Write CSV data to SD card file
     * @param {string} csvData - CSV string to write
     * @returns {boolean} true if write succeeded
     * @private
     */
    function _writeCSVFile(csvData) {
        console.log("Writing CSV file:", _csvFilePath, "(" + csvData.length, "bytes)")

        try {
            var request = new XMLHttpRequest()
            request.open("PUT", "file://" + _csvFilePath, false)
            request.setRequestHeader("Content-Type", "text/csv")
            request.send(csvData)

            if (request.status === 0 || request.status === 200) {
                console.log("CSV file write: SUCCESS")
                return true
            } else {
                console.log("CSV file write: FAILED (status:", request.status + ")")
                return false
            }
        } catch (error) {
            console.log("CSV file write: ERROR -", error)
            // Fallback: output to console for manual save
            console.log("=== MANUAL SAVE REQUIRED ===")
            console.log("File:", _csvFilePath)
            console.log("Format: Excel/Google Sheets compatible")
            console.log("--- DATA START ---")
            console.log(csvData)
            console.log("--- DATA END ---")
            return false
        }
    }

    /**
     * Read JSON data from SD card file
     * @returns {string|null} JSON string if successful, null otherwise
     * @private
     */
    function _readJSONFile() {
        console.log("Reading JSON file:", _jsonFilePath)

        try {
            var request = new XMLHttpRequest()
            request.open("GET", "file://" + _jsonFilePath, false)
            request.send()

            if (request.status === 0 || request.status === 200) {
                var data = request.responseText
                if (data && data.length > 0) {
                    console.log("JSON file read: SUCCESS (" + data.length, "bytes)")
                    return data
                } else {
                    console.log("JSON file read: EMPTY FILE")
                    return null
                }
            } else {
                console.log("JSON file read: FAILED (status:", request.status + ")")
                return null
            }
        } catch (error) {
            console.log("JSON file read: ERROR -", error)
            return null
        }
    }

    // Log when unit is detected
    Connections {
        target: _utgCommunication
        function onDetectedUnitChanged(unit) {
            console.log("UTG Unit detected:", unit)
            console.log("UTG Communication detectedUnit property:", _utgCommunication ? _utgCommunication.detectedUnit : "null")
            console.log("Thickness display will now use unit:", unit)
        }
        function onDeviceVersionChanged(version) {
            console.log("UTG Device version changed:", version)
        }
        function onCurrentThicknessChanged(thickness) {
            console.log("=== UTG THICKNESS READING RECEIVED ===")
            console.log("New thickness reading:", thickness)
            console.log("Current _currentThickness property:", _currentThickness)
            console.log("UTG Connected:", _utgConnected)
            console.log("UTG Enabled:", _utgEnabled)

            // Automatically save new reading to SD card
            if (thickness > 0) {
                console.log("Auto-saving new reading to SD card...")
                autoSaveReading(thickness)
            } else {
                console.log("Invalid thickness reading, not saving")
            }
        }
        onConnectionStatusChanged: {
            var connected = _utgCommunication ? _utgCommunication.connected : false
            console.log("=== UTG CONNECTION STATUS CHANGED ===")
            console.log("Connected:", connected)
            if (connected) {
                console.log("UTG device connected - will request device information after delay")
                deviceInfoTimer.start()
            } else {
                console.log("UTG device disconnected")
                deviceInfoTimer.stop()
            }
            console.log("=== END CONNECTION STATUS CHANGED ===")
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: {
            customPlugin.connectContext
        }
    }

    anchors.fill: parent

    MessageDialog {
        id: messageDialog
    }

    QGCPalette { id: qgcPal }

    visible: _utgEnabled

    Component.onCompleted: {
        console.log("=== CUSTOM THICKNESS READING FLY VIEW LOADED ===")
        loadStoredReadings()
    }

    // Timer to request device info after connection
    Timer {
        id: deviceInfoTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("Requesting device information...")
            if (_utgCommunication && _utgConnected) {
                _utgCommunication.getSerialNumber()     // I4
                _utgCommunication.getFirmwareVersion()  // I3
                _utgCommunication.getMCPLeverVersion()  // I1
                _utgCommunication.getSWID()             // I5
            }
        }
    }

    // Function to save device information to persistent storage
    function saveDeviceInformation() {
        if (!_utgCommunication) {
            console.log("Cannot save device info - no UTG communication")
            return
        }

        console.log("=== SAVING DEVICE INFORMATION ===")
        console.log("Current UTG properties:")
        console.log("  deviceVersion:", _utgCommunication.deviceVersion)
        console.log("  serialNumber:", _utgCommunication.serialNumber)
        console.log("  firmwareVersion:", _utgCommunication.firmwareVersion)
        console.log("  mcpLeverVersion:", _utgCommunication.mcpLeverVersion)
        console.log("  swid:", _utgCommunication.swid)

        // Save only if property has a value
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

        console.log("Saved device info:")
        console.log("  Device:", _savedDeviceVersion)
        console.log("  Serial:", _savedSerialNumber)
        console.log("  Firmware:", _savedFirmwareVersion)
        console.log("  MCP:", _savedMcpLeverVersion)
        console.log("  SWID:", _savedSwid)
        console.log("=== DEVICE INFORMATION SAVED ===")
    }

    // Monitor device property changes to ensure UI updates
    Connections {
        target: _utgCommunication
        onSerialNumberChanged: {
            console.log("Serial number updated:", _utgCommunication.serialNumber)
            // Save all device info when serial number arrives
            saveDeviceInformation()
        }
        onFirmwareVersionChanged: {
            console.log("Firmware version updated:", _utgCommunication.firmwareVersion)
        }
        onMcpLeverVersionChanged: {
            console.log("MCP lever version updated:", _utgCommunication.mcpLeverVersion)
        }
        onSwidChanged: {
            console.log("SWID updated:", _utgCommunication.swid)
        }
        onDeviceVersionChanged: {
            console.log("Device version updated:", _utgCommunication.deviceVersion)
        }
        onTemperatureChanged: {
            console.log("Temperature updated:", _utgCommunication.temperature)
        }
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
                        onClicked: {
                            console.log("=== READINGS ICON CLICKED ===")
                            readingsOverlay.visible = true
                        }
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
                            console.log("=== Thickness Display Update ===")
                            console.log("_utgEnabled:", _utgEnabled)
                            console.log("_utgConnected:", _utgConnected)
                            console.log("_utgSettings:", _utgSettings)
                            console.log("_currentThickness:", _currentThickness)
                            console.log("_utgCommunication:", _utgCommunication)

                            if (!_utgEnabled) {
                                console.log("Returning: Disabled")
                                return "Disabled"
                            }
                            if (!_utgConnected) {
                                console.log("Returning: Disconnected")
                                return "Disconnected"
                            }
                            if (!_utgSettings) {
                                console.log("Returning: No Settings")
                                return "No Settings"
                            }

                            // Use detected unit from UTG device, fallback to settings
                            var detectedUnit = _utgCommunication && _utgCommunication.detectedUnit ? _utgCommunication.detectedUnit : ""
                            var settingsUnit = _utgSettings.measurementUnit ? _utgSettings.measurementUnit.enumStringValue : "mm"
                            var unit = detectedUnit || settingsUnit
                            var precision = _utgSettings.displayPrecision ? _utgSettings.displayPrecision.rawValue : 2

                            console.log("Thickness display - detected unit:", detectedUnit, "settings unit:", settingsUnit, "using:", unit)
                            console.log("Precision:", precision)

                            var result = _currentThickness.toFixed(precision) + " " + unit
                            console.log("Final display text:", result)
                            console.log("=== End Thickness Display Update ===")
                            return result
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
                        console.log("Connect/Disconnect button clicked - connected:", _utgConnected)
                        if (!_utgConnected) {
                            console.log("Connecting to UTG")
                            if (_utgCommunication) _utgCommunication.connectToUTG()
                        } else {
                            console.log("Disconnecting from UTG")
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
                            console.log("Single measurement button clicked")
                            if (_utgCommunication && _utgConnected) {
                                console.log("Taking single measurement")
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
                            console.log("Fast button clicked - connected:", _utgConnected, "measuring:", _continuousMeasuring)
                            if (_utgCommunication && _utgConnected) {
                                if (_continuousMeasuring) {
                                    console.log("Stopping continuous measurement")
                                    _utgCommunication.stopContinuousMeasurement()
                                    _continuousMeasuring = false
                                } else {
                                    console.log("Starting continuous measurement")
                                    _utgCommunication.startContinuousMeasurement()
                                    _continuousMeasuring = true
                                }
                            } else {
                                console.log("Cannot start fast measurement - not connected")
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
                onClicked: {
                    console.log("=== SETTINGS GEAR ICON CLICKED ===")
                    settingsDialog.open()
                }
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

        // Backup variables to store original values
        property var _originalGain: 50
        property var _originalSoundVelocity: 5920
        property var _originalThreshold: 50
        property var _originalProbeModel: 0
        property bool _refreshingSettings: false
        property string _refreshStatus: "Applying settings to UTG device..."

        // Monitor fact changes to trigger _hasUnsavedChanges update
        Connections {
            target: _utgSettings ? _utgSettings.soundVelocity : null
            onRawValueChanged: {
                console.log("UTG Settings: Sound velocity changed to:", _utgSettings.soundVelocity.rawValue)
            }
        }

        Connections {
            target: _utgSettings ? _utgSettings.probeModel : null
            onRawValueChanged: {
                console.log("UTG Settings: Probe model changed to:", _utgSettings.probeModel.rawValue)
            }
        }

        // Timer for refresh operations
        Timer {
            id: refreshTimer
            interval: 2000
            repeat: false
            onTriggered: {
                settingsDialog._refreshingSettings = false
            }
        }

        // Timer for apply sequence - just hide overlay, don't refresh
        Timer {
            id: applyTimer
            interval: 1000
            repeat: false
            onTriggered: {
                console.log("UTG Settings: Apply complete, hiding overlay")
                settingsDialog._refreshingSettings = false
                settingsDialog._isRefreshing = false
            }
        }

        // Timer for final overlay hide (not used anymore)
        Timer {
            id: finalTimer
            interval: 1000
            repeat: false
            onTriggered: {
                settingsDialog._refreshingSettings = false
            }
        }

        // Timer for delayed P0 command
        Timer {
            id: p0Timer
            interval: 100
            repeat: false
            onTriggered: {
                console.log("Sending P0 command for probe model...")
                _utgCommunication.getProbeModel()
            }
        }

        // Timer for delayed V0 command
        Timer {
            id: v0Timer
            interval: 200
            repeat: false
            onTriggered: {
                console.log("Sending V0 command for velocity...")
                _utgCommunication.getVelocity()
            }
        }

        // Timer for storing original values after device sync
        Timer {
            id: originalValuesTimer
            interval: 8000  // Wait 8 seconds for all device responses (I2, I3, I4, I1, I5, P0, V0)
            repeat: false
            onTriggered: {
                console.log("UTG Settings: Storing current values as original after device sync")
                settingsDialog.storeCurrentAsOriginal()
                settingsDialog._isRefreshing = false  // Clear refreshing flag
                console.log("UTG Settings: Original values stored, refreshing flag cleared, apply button should show 'No changes'")
            }
        }

        // Track if we're currently refreshing to avoid showing unsaved changes during refresh
        property bool _isRefreshing: false

        // Check if settings have been modified
        property bool _hasUnsavedChanges: {
            if (!_utgSettings || _isRefreshing) {
                console.log("UTG Settings: _hasUnsavedChanges = false (no settings or refreshing)")
                return false
            }

            var velocityChanged = _utgSettings.soundVelocity && _utgSettings.soundVelocity.rawValue !== _originalSoundVelocity
            var probeChanged = _utgSettings.probeModel && _utgSettings.probeModel.rawValue !== _originalProbeModel
            var gainChanged = _utgSettings.gain && _utgSettings.gain.rawValue !== _originalGain
            var thresholdChanged = _utgSettings.threshold && _utgSettings.threshold.rawValue !== _originalThreshold

            var hasChanges = velocityChanged || probeChanged || gainChanged || thresholdChanged

            if (hasChanges) {
                console.log("UTG Settings: Changes detected!")
                console.log("  Velocity:", _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue : "null", "vs", _originalSoundVelocity, "=", velocityChanged)
                console.log("  Probe:", _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : "null", "vs", _originalProbeModel, "=", probeChanged)
                console.log("  Gain:", _utgSettings.gain ? _utgSettings.gain.rawValue : "null", "vs", _originalGain, "=", gainChanged)
                console.log("  Threshold:", _utgSettings.threshold ? _utgSettings.threshold.rawValue : "null", "vs", _originalThreshold, "=", thresholdChanged)
            }

            return hasChanges
        }

        function storeCurrentAsOriginal() {
            // Store current values as original (after device refresh)
            if (_utgSettings) {
                _originalGain = _utgSettings.gain ? _utgSettings.gain.rawValue : 50
                _originalSoundVelocity = _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue : 5920
                _originalThreshold = _utgSettings.threshold ? _utgSettings.threshold.rawValue : 50
                _originalProbeModel = _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : 0

                console.log("UTG Settings: Updated original values after device sync - velocity:", _originalSoundVelocity, "probe:", _originalProbeModel)
                console.log("UTG Settings: Apply button should now show 'No changes'")
            }
        }

        function open() {
            console.log("UTG Settings Dialog: Opening settings dialog")
            console.log("Current device properties - serial:", _utgCommunication ? _utgCommunication.serialNumber : "null",
                       "firmware:", _utgCommunication ? _utgCommunication.firmwareVersion : "null",
                       "mcpLever:", _utgCommunication ? _utgCommunication.mcpLeverVersion : "null",
                       "swid:", _utgCommunication ? _utgCommunication.swid : "null")

            // Open dialog IMMEDIATELY - no delays
            _isOpen = true

            // Store current settings values as original (baseline for change detection)
            // Do NOT refresh from device automatically - user can click "Refresh Settings" if needed
            Qt.callLater(function() {
                console.log("UTG Settings: Storing current values as baseline")
                storeCurrentAsOriginal()
                console.log("UTG Settings: Dialog ready - use 'Refresh Settings' button to sync with device")
            })
        }

        function closeDialog() { _isOpen = false }

        function refreshSettingsFromDevice() {
            // Force refresh settings from UTG device
            if (_utgCommunication && _utgConnected) {
                _refreshingSettings = true
                _isRefreshing = true  // Set flag to prevent unsaved changes detection
                _refreshStatus = "Refreshing settings from UTG device..."
                console.log("UTG Settings: Force refreshing all values from device")
                console.log("Current settings before refresh - velocity:", _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue : "null", "probe:", _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : "null")
                console.log("Current detected unit before refresh:", _utgCommunication ? _utgCommunication.detectedUnit : "null")
                // Call getAllDeviceInformation to get device info with proper delays
                console.log("Calling getAllDeviceInformation()...")
                getAllDeviceInformation()

                // Use timers to space out commands to avoid queue issues
                p0Timer.start()  // Start P0 after 100ms
                v0Timer.start()  // Start V0 after 200ms

                // Check unit after a short delay
                Qt.callLater(function() {
                    console.log("Detected unit after I2 command:", _utgCommunication ? _utgCommunication.detectedUnit : "null")
                })

                // Hide overlay after 2 seconds (time for responses to come back)
                refreshTimer.start()
            } else {
                console.log("UTG Settings: Cannot refresh - communication:", _utgCommunication, "connected:", _utgConnected)
            }
        }

        function saveSettings() {
            // Apply only changed settings to UTG communication
            if (_utgCommunication && _utgConnected && _utgSettings) {
                _refreshingSettings = true
                _refreshStatus = "Applying settings to UTG device..."
                var changeCount = 0

                console.log("UTG Settings: Checking for changes...")
                console.log("Current velocity:", _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue : "null")
                console.log("Original velocity:", _originalSoundVelocity)
                console.log("Current probe:", _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : "null")
                console.log("Original probe:", _originalProbeModel)

                // Send sound velocity only if changed
                if (_utgSettings.soundVelocity && _utgSettings.soundVelocity.rawValue !== _originalSoundVelocity) {
                    console.log("UTG Settings: Velocity changed, sending V1 command")
                    _utgCommunication.setVelocityCommand(_utgSettings.soundVelocity.rawValue)
                    changeCount++
                }

                // Send probe model only if changed
                if (_utgSettings.probeModel && _utgSettings.probeModel.rawValue !== _originalProbeModel) {
                    console.log("UTG Settings: Probe model changed, sending P1 command")
                    var probeModels = ["P5EE", "N05", "N07", "HT5", "N02"]
                    _utgCommunication.setProbeModel(probeModels[_utgSettings.probeModel.rawValue])
                    changeCount++
                }





                if (changeCount > 0) {
                    console.log("UTG Settings: Applied", changeCount, "changes")

                    // Update original values to current values so change detection works
                    _originalSoundVelocity = _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue : _originalSoundVelocity
                    _originalProbeModel = _utgSettings.probeModel ? _utgSettings.probeModel.rawValue : _originalProbeModel

                    console.log("UTG Settings: Updated original values - velocity:", _originalSoundVelocity, "probe:", _originalProbeModel)

                    // Wait 1 second then hide overlay (don't refresh - trust the commands were sent)
                    _refreshStatus = "Settings applied successfully"
                    applyTimer.start()
                } else {
                    console.log("UTG Settings: No changes to apply")
                    _refreshingSettings = false
                }
            }
            // Don't close the window - let user close manually
        }

        function cancelSettings() {
            // Restore original values and close
            if (_utgSettings) {
                if (_utgSettings.gain) _utgSettings.gain.rawValue = _originalGain
                if (_utgSettings.soundVelocity) _utgSettings.soundVelocity.rawValue = _originalSoundVelocity
                if (_utgSettings.threshold) _utgSettings.threshold.rawValue = _originalThreshold
                if (_utgSettings.probeModel) _utgSettings.probeModel.rawValue = _originalProbeModel
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
                            onClicked: {
                                console.log("Refresh Settings button clicked")
                                settingsDialog.refreshSettingsFromDevice()
                            }
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
                            Layout.fillWidth: true
                            text: _utgSettings && _utgSettings.soundVelocity ? _utgSettings.soundVelocity.rawValue.toString() : ""
                            inputMethodHints: Qt.ImhDigitsOnly
                            placeholderText: "1000-10000"
                            validator: IntValidator {
                                bottom: 1000
                                top: 10000
                            }
                            onEditingFinished: {
                                if (_utgSettings && _utgSettings.soundVelocity && text !== "") {
                                    var newValue = parseInt(text)
                                    if (newValue >= 1000 && newValue <= 10000) {
                                        console.log("UTG Settings: User changed velocity from", _utgSettings.soundVelocity.rawValue, "to", newValue)
                                        _utgSettings.soundVelocity.rawValue = newValue
                                    } else {
                                        console.log("UTG Settings: Invalid velocity value:", newValue)
                                        // Reset to current value
                                        text = _utgSettings.soundVelocity.rawValue.toString()
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
                                _zoneCounter = 1  // Reset counter when zone changes
                                console.log("Zone changed to:", _currentZone)
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
                                ToolTip.text: qsTr("Sets current probe position as zero reference point. Use when probe is on a known reference surface.")
                                ToolTip.visible: hovered
                                onClicked: {
                                    console.log("Zero Calibration button clicked")
                                    if (_utgCommunication) {
                                        console.log("Performing zero calibration")
                                        _utgCommunication.performZeroCalibration()
                                    } else {
                                        console.log("No UTG communication available for calibration")
                                    }
                                }
                            }

                            QGCButton {
                                text: "Reset Device"
                                Layout.fillWidth: true
                                onClicked: {
                                    console.log("Reset Device button clicked")
                                    if (_utgCommunication) {
                                        console.log("Resetting UTG device")
                                        _utgCommunication.resetDevice()
                                    } else {
                                        console.log("No UTG communication available for reset")
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
                            onClicked: {
                                console.log("Apply button clicked")
                                settingsDialog.saveSettings()
                            }
                            primary: settingsDialog._hasUnsavedChanges
                        }

                        QGCButton {
                            text: "Close"
                            width: ScreenTools.defaultFontPixelWidth * 8
                            height: ScreenTools.defaultFontPixelHeight * 2
                            enabled: !settingsDialog._refreshingSettings
                            onClicked: {
                                console.log("Close button clicked")
                                settingsDialog.cancelSettings()
                            }
                        }
                    }
                }
            }


        }

        // Refresh overlay
        Rectangle {
            visible: false // _refreshingSettings
            anchors.fill: parent
            color: "black"
            opacity: 0.7
            z: 1000

            Column {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelHeight

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ScreenTools.defaultFontPixelHeight * 3
                    height: width
                    color: "transparent"
                    border.color: "white"
                    border.width: 3
                    radius: width / 2

                    Rectangle {
                        width: parent.width / 4
                        height: parent.height / 4
                        color: "white"
                        radius: width / 2
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 3
                    }

                    RotationAnimation {
                        target: parent
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 2000
                        loops: Animation.Infinite
                        running: false  // Disabled - was causing dialog to spin on open
                        // running: settingsDialog._refreshingSettings
                    }
                }

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Refreshing..." // _refreshStatus
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

        Component.onCompleted: {
            console.log("=== READING LIST OVERLAY CREATED ===")
            console.log("Stored readings count:", _readingCount)
        }

        onVisibleChanged: {
            if (visible) {
                console.log("=== READINGS OVERLAY OPENED ===")
                console.log("Current readings in memory:", _readingCount)
                console.log("Refreshing from SD card...")

                // Force refresh from SD card
                loadStoredReadings()

                console.log("After refresh - readings count:", _readingCount)
                console.log("Starting periodic refresh (2Hz)...")

                // Start periodic refresh timer
                periodicRefreshTimer.start()

                console.log("=== REFRESH COMPLETE ===")
            } else {
                console.log("=== READINGS OVERLAY CLOSED ===")

                // Stop periodic refresh when overlay is closed
                periodicRefreshTimer.stop()
            }
        }

        // Periodic refresh timer (1Hz = 1000ms interval)
        Timer {
            id: periodicRefreshTimer
            interval: 1000  // 1000ms = 1Hz (once per second)
            repeat: true
            onTriggered: {
                console.log("=== PERIODIC REFRESH (1Hz) ===")
                loadStoredReadings()
                console.log("Periodic refresh complete, count:", _readingCount)
            }
        }

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
                        width: parent.width * 0.20
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
                        width: parent.width * 0.35
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
                    model: _storedReadings

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
                                    text: modelData.datetime
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
                                    text: modelData.reading
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Item {
                                width: parent.width * 0.20
                                height: parent.height

                                QGCLabel {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: modelData.gpsLocation
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }

                            Item {
                                width: parent.width * 0.35
                                height: parent.height

                                QGCTextField {
                                    anchors.fill: parent
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.25
                                    text: modelData.notes
                                    placeholderText: qsTr("Enter notes...")
                                    onEditingFinished: {
                                        console.log("=== EDITING NOTES ===")
                                        console.log("Old notes:", modelData.notes)
                                        console.log("New notes:", text)
                                        modelData.notes = text
                                        console.log("Notes updated, saving to storage...")
                                        saveToStorage()
                                        console.log("=== NOTES EDIT COMPLETE ===")
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

                                    // Drop shadow effect
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

                                    // Draw X using two rectangles
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
                                        onClicked: {
                                            console.log("Delete button clicked for index:", index)
                                            deleteReading(index)
                                        }
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
                        onClicked: {
                            console.log("=== CLEAR ALL CLICKED ===")
                            console.log("Current reading count:", _readingCount)
                            clearAllReadings()
                        }
                    }
                }

                // Test buttons - Right
                Item {
                    width: parent.width * 0.5
                    height: parent.height

                    Row {
                        id: buttonRow
                        anchors.right: parent.right
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: qsTr("Add Test Entry")
                            height: ScreenTools.defaultFontPixelHeight * 1.8
                            enabled: true
                            onClicked: {
                                console.log("=== ADD TEST ENTRY CLICKED ===")
                                addTestEntry()
                            }
                        }

                        QGCButton {
                            text: qsTr("Refresh")
                            height: ScreenTools.defaultFontPixelHeight * 1.8
                            enabled: true
                            onClicked: {
                                console.log("=== REFRESH CLICKED ===")
                                console.log("Manual refresh from SD card...")
                                loadStoredReadings()
                                console.log("Manual refresh complete, count:", _readingCount)
                            }
                        }
                    }
                }
            }
        }
    }
}
