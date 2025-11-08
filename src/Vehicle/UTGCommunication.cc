/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UTGCommunication.h"
#include "Vehicle.h"
#include "QGCApplication.h"
#include "MultiVehicleManager.h"
#include "SettingsManager.h"
#include "UTGSettings.h"
#include "UTGReadingManager.h"
#include "UTGReading.h"
#include "ParameterManager.h"
#include "FactSystem.h"

#include <QDebug>
#include <QRegularExpression>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QAndroidJniObject>
#include <QtAndroid>
#endif

Q_LOGGING_CATEGORY(UTGCommunicationLog, "UTGCommunicationLog")

UTGCommunication::UTGCommunication(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _settings(nullptr)
    , _readingManager(new UTGReadingManager(this))
    , _connected(false)
    , _currentThickness(0.0)
    , _serialNumber("")
    , _firmwareVersion("")
    , _mcpLeverVersion("")
    , _swid("")
    , _temperature(0.0)
    , _velocity(5920.0)  // Default velocity for steel
    , _gain(50)          // Default gain
    , _rangeStart(0.0)   // Default range start
    , _rangeEnd(100.0)   // Default range end
    , _detectedUnit("mm")  // Default to mm
    , _commandTimer(new QTimer(this))
    , _continuousTimer(new QTimer(this))
    , _continuousMeasurement(false)
{
    qCDebug(UTGCommunicationLog) << "UTGCommunication created for vehicle" << (_vehicle ? _vehicle->id() : -1);

    // Get UTG settings
    QGCApplication* app = qgcApp();
    if (app && app->toolbox() && app->toolbox()->settingsManager()) {
        _settings = app->toolbox()->settingsManager()->utgSettings();
        if (_settings) {
            // Initialize values from settings
            _velocity = _settings->soundVelocity()->rawValue().toDouble();
            _gain = _settings->gain()->rawValue().toInt();

            // Connect to settings changes
            connect(_settings->soundVelocity(), &Fact::rawValueChanged, this, [this]() {
                _velocity = _settings->soundVelocity()->rawValue().toDouble();
                emit velocityChanged(_velocity);
            });
            connect(_settings->gain(), &Fact::rawValueChanged, this, [this]() {
                _gain = _settings->gain()->rawValue().toInt();
                emit gainChanged(_gain);
            });
        }
    }
    
    // Setup command timeout timer
    _commandTimer->setSingleShot(true);
    _commandTimer->setInterval(UTG_TIMEOUT);
    connect(_commandTimer, &QTimer::timeout, this, &UTGCommunication::_onCommandTimeout);

    // Setup continuous measurement timer (fast updates)
    _continuousTimer->setInterval(200);  // 5 Hz update rate
    connect(_continuousTimer, &QTimer::timeout, this, [this]() {
        if (_connected && _continuousMeasurement) {
            getInstantThickness();  // Use SI command for fast measurements
        }
    });
    
    // Connect measurement signal to reading manager
    connect(this, &UTGCommunication::measurementReceived,
            _readingManager, [this](double thickness) {
                if (_settings && _settings->autoSaveMeasurements()->rawValue().toBool()) {
                    _readingManager->onNewReading(thickness, _detectedUnit, 0);
                }
            });

    // Connect to vehicle signals if available
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived,
                this, [this](const mavlink_message_t& message) {
                    if (message.msgid == MAVLINK_MSG_ID_SERIAL_CONTROL) {
                        handleSerialControlMessage(message);
                    } else if (message.msgid == MAVLINK_MSG_ID_STATUSTEXT) {
                        handleStatusTextMessage(message);
                    }
                });
        connect(_vehicle, &Vehicle::connectionLostChanged, this, &UTGCommunication::_onVehicleConnectionChanged);

        // Auto-connect if enabled in settings
        if (_settings && _settings->autoConnect()->rawValue().toBool()) {
            QTimer::singleShot(5000, this, &UTGCommunication::connectToUTG); // Longer delay for stable connection
        }
    }
}

UTGCommunication::~UTGCommunication()
{
    disconnectFromUTG();
}

void UTGCommunication::connectToUTG()
{
    if (_connected) {
        return;
    }

    if (!_vehicle || !_vehicle->priorityLink()) {
        _setError(tr("No vehicle connection available"));
        return;
    }

    // Check UTG configuration first
    if (!checkUTGConfiguration()) {
        return; // Error already set by checkUTGConfiguration
    }

    qCDebug(UTGCommunicationLog) << "=== UTG INITIAL CONNECTION ===";
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: UTG Connection starting";
    qCDebug(UTGCommunicationLog) << "Vehicle ID:" << _vehicle->id();
    qCDebug(UTGCommunicationLog) << "Vehicle Component ID:" << _vehicle->defaultComponentId();
    qCDebug(UTGCommunicationLog) << "Priority Link:" << (_vehicle->priorityLink() ? _vehicle->priorityLink()->getName() : "None");
    qCDebug(UTGCommunicationLog) << "Vehicle Connected:" << !_vehicle->connectionLost();
    qCDebug(UTGCommunicationLog) << "QGC will use System ID: 255, Component ID: 0";
    qCDebug(UTGCommunicationLog) << "==============================";

    _addToCommandLog(tr("🔌 Connecting to UTG device..."));
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Sending I2 command to establish connection and detect units";

    // Clear any previous errors
    _lastError.clear();

    // Send I2 command to get device info, establish connection, and detect units
    _addToCommandLog(tr("Sending I2 command for device info and unit detection"));
    sendCommand("I2");
}

void UTGCommunication::disconnectFromUTG()
{
    if (!_connected) {
        return;
    }

    qCDebug(UTGCommunicationLog) << "Disconnecting from UTG device";
    _addToCommandLog(tr("Disconnecting from UTG device"));

    _clearCommandQueue();
    stopContinuousMeasurement();  // Stop any continuous measurements
    _setConnected(false);
}



bool UTGCommunication::checkUTGConfiguration()
{
    if (!_vehicle) {
        return false;
    }

    // For now, just check if vehicle is connected
    // Parameter checking can be added later when ParameterManager is properly included
    if (!_vehicle->priorityLink()) {
        _setError(tr("No vehicle connection available"));
        return false;
    }

    // TODO: Add parameter checking when ParameterManager include is resolved
    // - UTG_ENABLE should be 1
    // - SERIAL3_PROTOCOL should be 51
    // - SERIAL3_BAUD should be 9

    return true;
}

void UTGCommunication::getVersion()
{
    sendCommand("I3");  // Get software version per UTG specification
}

void UTGCommunication::getDeviceInfo()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getDeviceInfo() called, sending I2 command";
    sendCommand("I2");  // Get device info per UTG specification
}

void UTGCommunication::getMCPLeverVersion()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getMCPLeverVersion() called, sending I1 command";
    sendCommand("I1");  // Get MCP lever version per UTG specification
}

void UTGCommunication::getHelp()
{
    sendCommand("I0");  // List commands per UTG specification
}

void UTGCommunication::getFirmwareVersion()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getFirmwareVersion() called, sending I3 command";
    sendCommand("I3");  // Get firmware version per UTG specification
}

void UTGCommunication::getSerialNumber()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getSerialNumber() called, sending I4 command";
    sendCommand("I4");  // Get serial number per UTG specification
}

void UTGCommunication::getSWID()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getSWID() called, sending I5 command";
    sendCommand("I5");  // Get SWID per UTG specification
}

void UTGCommunication::getTemperature()
{
    // UTG specification doesn't have temperature command
    // Using a custom command - this may not work with real UTG devices
    sendCommand("TEMP");
}

void UTGCommunication::takeMeasurement()
{
    sendCommand("S");   // Get stable thickness per UTG specification
}

void UTGCommunication::measureThickness()
{
    sendCommand("S");   // Get stable thickness per UTG specification (alias)
}

void UTGCommunication::getInstantThickness()
{
    sendCommand("SI");  // Get instant thickness per UTG specification
}

void UTGCommunication::startContinuousMeasurement()
{
    if (!_connected) {
        _setError(tr("Cannot start continuous measurement - not connected"));
        return;
    }

    qCDebug(UTGCommunicationLog) << "Starting continuous measurement";
    _addToCommandLog(tr("Starting continuous measurement (5 Hz)"));

    _continuousMeasurement = true;
    _continuousTimer->start();
}

void UTGCommunication::stopContinuousMeasurement()
{
    qCDebug(UTGCommunicationLog) << "Stopping continuous measurement";
    _addToCommandLog(tr("Stopping continuous measurement"));

    _continuousMeasurement = false;
    _continuousTimer->stop();
}

void UTGCommunication::getVelocity()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getVelocity() called, sending V0 command";
    sendCommand("V0");  // Get sound velocity per UTG specification
}

void UTGCommunication::setVelocityCommand(double velocity)
{
    if (velocity >= 1000.0 && velocity <= 10000.0) {
        sendCommand(QString("V1 %1").arg(velocity, 0, 'f', 0));  // Set sound velocity per UTG specification
    } else {
        _setError(tr("Velocity must be between 1000 and 10000 m/s"));
    }
}

void UTGCommunication::getProbeModel()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getProbeModel() called, sending P0 command";
    sendCommand("P0");  // Get probe model per UTG specification
}

void UTGCommunication::setProbeModel(const QString& model)
{
    sendCommand(QString("P1 %1").arg(model));  // Set probe model per UTG specification
}

void UTGCommunication::getUnits()
{
    sendCommand("U0");  // Get measurement units per UTG specification
}

void UTGCommunication::setUnits(const QString& units)
{
    sendCommand(QString("U1 %1").arg(units));  // Set measurement units per UTG specification
}

// Memory functions per UTG specification
void UTGCommunication::getMemoryFileCount()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getMemoryFileCount() called, sending M0 command";
    sendCommand("M0");  // Get memory file count per UTG specification
}

void UTGCommunication::getFileRecordCount(int fileIndex)
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getFileRecordCount() called for file" << fileIndex << ", sending M1 command";
    sendCommand(QString("M1 %1").arg(fileIndex));  // Get file record count per UTG specification
}

void UTGCommunication::getFileRecords(int fileIndex)
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: getFileRecords() called for file" << fileIndex << ", sending M2 command";
    sendCommand(QString("M2 %1").arg(fileIndex));  // Get file records per UTG specification
}

void UTGCommunication::clearFile(int fileIndex)
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: clearFile() called for file" << fileIndex << ", sending MC command";
    sendCommand(QString("MC %1").arg(fileIndex));  // Clear specific file per UTG specification
}

void UTGCommunication::clearAllFiles()
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: clearAllFiles() called, sending MCA command";
    sendCommand("MCA");  // Clear all files per UTG specification
}



// Removed non-standard GAIN and RANGE commands - not in UTG specification

void UTGCommunication::performZeroCalibration()
{
    qCDebug(UTGCommunicationLog) << "Performing zero calibration...";
    _addToCommandLog(tr("🔧 Starting zero calibration..."));
    _addToCommandLog(tr("⚠️ IMPORTANT: Ensure probe is in air (not touching anything)"));
    _addToCommandLog(tr("📋 Device will enter calibration mode - do not move probe"));

    // Calibration needs longer timeout - use direct method
    if (!_vehicle || !_vehicle->priorityLink()) {
        _setError(tr("No vehicle connection available"));
        return;
    }

    QMutexLocker locker(&_commandMutex);

    // Add command to queue if another command is in progress
    if (_commandTimer->isActive()) {
        _commandQueue.enqueue("Z");
        qCDebug(UTGCommunicationLog) << "Calibration command queued";
        return;
    }

    _currentCommand = "Z";
    _sendSerialControlMessage("Z", UTG_CALIBRATION_TIMEOUT);  // Use 5-second timeout
    _commandTimer->start();

    qCDebug(UTGCommunicationLog) << "Zero calibration command sent with 5s timeout";
    _addToCommandLog(QString("TX: Z (calibration)"));
}

void UTGCommunication::resetDevice()
{
    qCDebug(UTGCommunicationLog) << "=== UTG DEVICE RESET ===";
    _addToCommandLog(tr("🔄 Resetting UTG device..."));
    _addToCommandLog(tr("⚠️ Device will restart and return serial number"));

    // Reset needs longer timeout - use direct method
    if (!_vehicle || !_vehicle->priorityLink()) {
        _setError(tr("No vehicle connection available"));
        return;
    }

    QMutexLocker locker(&_commandMutex);

    // Add command to queue if another command is in progress
    if (_commandTimer->isActive()) {
        _commandQueue.enqueue("@");
        qCDebug(UTGCommunicationLog) << "Reset command queued";
        return;
    }

    _currentCommand = "@";
    _sendSerialControlMessage("@", 10000);  // Use 10-second timeout for reset
    _commandTimer->start();

    qCDebug(UTGCommunicationLog) << "Reset command sent with 10s timeout";
    _addToCommandLog(QString("TX: @ (device reset - waiting up to 10s)"));
}

void UTGCommunication::sendCommand(const QString& command)
{
    if (!_vehicle || !_vehicle->priorityLink()) {
        _setError(tr("No vehicle connection available"));
        return;
    }
    
    QMutexLocker locker(&_commandMutex);
    
    // Add command to queue if another command is in progress
    if (_commandTimer->isActive()) {
        _commandQueue.enqueue(command);
        qCDebug(UTGCommunicationLog) << "Command queued:" << command;
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Command queued (timer active):" << command;
        return;
    }
    
    _currentCommand = command;
    _sendSerialControlMessage(command);
    _commandTimer->start();
    
    qCDebug(UTGCommunicationLog) << "Command sent:" << command;
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Command sent:" << command;
    _addToCommandLog(QString("TX: %1").arg(command));
}

void UTGCommunication::handleSerialControlMessage(const mavlink_message_t& message)
{
    mavlink_serial_control_t serialControl;
    mavlink_msg_serial_control_decode(&message, &serialControl);

    // Check if this is a UTG response (device 200 with REPLY flag)
    if (serialControl.device == SERIAL_CONTROL_DEV_UTG &&
        (serialControl.flags & SERIAL_CONTROL_FLAG_REPLY)) {

        // Log raw bytes received
        QByteArray rawBytes(reinterpret_cast<const char*>(serialControl.data), serialControl.count);
        qCWarning(UTGCommunicationLog) << "=== RAW BYTES RECEIVED ===";
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Byte count:" << serialControl.count;
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Raw hex:" << rawBytes.toHex(' ');
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Raw ASCII:" << rawBytes;
        qCWarning(UTGCommunicationLog) << "=== END RAW BYTES ===";

        QString response = QString::fromLatin1(
            reinterpret_cast<const char*>(serialControl.data),
            serialControl.count
        );

        _responseBuffer += response;

        // Process complete responses (ending with \r\n)
        while (_responseBuffer.contains("\r\n")) {
            int endIndex = _responseBuffer.indexOf("\r\n");
            QString completeResponse = _responseBuffer.left(endIndex);
            _responseBuffer = _responseBuffer.mid(endIndex + 2);

            if (!completeResponse.isEmpty()) {
                _processResponse(completeResponse);
            }
        }
    }
}

void UTGCommunication::handleStatusTextMessage(const mavlink_message_t& message)
{
    mavlink_statustext_t statusText;
    mavlink_msg_statustext_decode(&message, &statusText);

    QString text = QString::fromUtf8(statusText.text).trimmed();

    qCDebug(UTGCommunicationLog) << "STATUSTEXT received:" << text;

    // Log ALL STATUSTEXT messages for debugging
    _addToCommandLog(QString("STATUSTEXT: %1").arg(text));

    // Log all UTG-related messages for debugging
    if (text.contains("UTG")) {
        _addToCommandLog(QString("UTG DEBUG: %1").arg(text));
    }

    // Check for UTG responses with "UTG_RESPONSE: " prefix
    if (text.startsWith("UTG_RESPONSE: ")) {
        QString response = text.mid(14); // Remove "UTG_RESPONSE: " prefix
        if (!response.isEmpty()) {
            qCDebug(UTGCommunicationLog) << "Processing UTG response:" << response;
            _addToCommandLog(QString("← %1").arg(response));
            _processResponse(response);
        }
    }
    // Also check for debug messages that might contain UTG responses
    else if (text.contains("UTG: Parsed UTG response:")) {
        // Extract response from debug message: "DBDB UTG: Parsed UTG response: 'I3 A 1.35I IDUT0001'"
        int startPos = text.indexOf("'") + 1;
        int endPos = text.lastIndexOf("'");
        if (startPos > 0 && endPos > startPos) {
            QString response = text.mid(startPos, endPos - startPos);
            qCDebug(UTGCommunicationLog) << "Processing UTG response from debug:" << response;
            _addToCommandLog(QString("← %1").arg(response));
            _processResponse(response);
        }
    }
}

void UTGCommunication::setVelocity(double velocity)
{
    qCDebug(UTGCommunicationLog) << "setVelocity called with:" << velocity << "current:" << _velocity;
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: setVelocity called with:" << velocity << "current:" << _velocity;
    if (qAbs(_velocity - velocity) > 0.1) {
        _velocity = velocity;
        qCDebug(UTGCommunicationLog) << "Velocity updated to:" << _velocity;
        emit velocityChanged(_velocity);

        // Also update the settings if available
        if (_settings && _settings->soundVelocity()) {
            // Store as integer to avoid decimal display
            int intVelocity = qRound(velocity);
            qCDebug(UTGCommunicationLog) << "Updating UTG settings velocity from" << _settings->soundVelocity()->rawValue().toDouble() << "to:" << intVelocity;
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Updating settings velocity to:" << intVelocity;
            _settings->soundVelocity()->setRawValue(intVelocity);
            qCDebug(UTGCommunicationLog) << "UTG settings velocity now:" << _settings->soundVelocity()->rawValue().toDouble();
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Settings velocity updated to:" << _settings->soundVelocity()->rawValue().toDouble();
        } else {
            qCDebug(UTGCommunicationLog) << "Cannot update settings - _settings:" << _settings << "soundVelocity:" << (_settings ? _settings->soundVelocity() : nullptr);
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Cannot update settings - missing settings object";
        }
    }
}

void UTGCommunication::setGain(int gain)
{
    if (_gain != gain) {
        _gain = gain;
        emit gainChanged(_gain);
    }
}

void UTGCommunication::setRangeStart(double start)
{
    if (qAbs(_rangeStart - start) > 0.01) {
        _rangeStart = start;
        emit rangeChanged(_rangeStart, _rangeEnd);
    }
}

void UTGCommunication::setRangeEnd(double end)
{
    if (qAbs(_rangeEnd - end) > 0.01) {
        _rangeEnd = end;
        emit rangeChanged(_rangeStart, _rangeEnd);
    }
}

void UTGCommunication::_onCommandTimeout()
{
    qCWarning(UTGCommunicationLog) << "Command timeout:" << _currentCommand;
    _setError(tr("Command timeout: %1").arg(_currentCommand));
    _addToCommandLog(QString("TIMEOUT: %1").arg(_currentCommand));

    // If this was a connection attempt, try alternative commands
    if (_currentCommand == "I4" && !_connected) {
        qCDebug(UTGCommunicationLog) << "I4 failed, trying I3 for connection";
        _currentCommand.clear();
        sendCommand("I3");
        return;
    } else if (_currentCommand == "I3" && !_connected) {
        qCDebug(UTGCommunicationLog) << "I3 failed, trying I2 for connection";
        _currentCommand.clear();
        sendCommand("I2");
        return;
    }

    // Process next command in queue
    QMutexLocker locker(&_commandMutex);
    if (!_commandQueue.isEmpty()) {
        QString nextCommand = _commandQueue.dequeue();
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Processing queued command:" << nextCommand;
        locker.unlock();
        sendCommand(nextCommand);
    } else {
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Command queue is empty";
    }
}

void UTGCommunication::_onVehicleConnectionChanged()
{
    if (_vehicle && !_vehicle->connectionLost()) {
        // Vehicle reconnected - could attempt auto-reconnect here
    } else {
        // Vehicle disconnected
        _setConnected(false);
    }
}

void UTGCommunication::_sendSerialControlMessage(const QString& command, uint16_t timeout)
{
    if (!_vehicle || !_vehicle->priorityLink()) {
        return;
    }

    // Format command with terminator (exactly like Python script)
    QString formattedCommand = command + "\r\n";
    QByteArray commandData = formattedCommand.toUtf8();  // Use UTF-8 like Python

    if (commandData.size() > 70) {
        _setError(tr("Command too long: %1").arg(command));
        return;
    }

    // Debug: Log exact bytes being sent
    qCDebug(UTGCommunicationLog) << "Sending UTG command:" << command;
    qCDebug(UTGCommunicationLog) << "Formatted command bytes:" << commandData.toHex();
    qCDebug(UTGCommunicationLog) << "Command length:" << commandData.size();

    // Create SERIAL_CONTROL message
    mavlink_message_t message;
    mavlink_serial_control_t serialControl;

    // Set up SERIAL_CONTROL message targeting the vehicle
    memset(&serialControl, 0, sizeof(serialControl));  // Zero entire structure
    serialControl.device = SERIAL_CONTROL_DEV_UTG;
    serialControl.flags = 0;  // No special flags needed per specification
    serialControl.timeout = timeout;  // Use custom timeout
    serialControl.baudrate = UTG_BAUDRATE;
    serialControl.count = commandData.size();

    // Zero-pad the data array (70 bytes max) like Python script
    memset(serialControl.data, 0, 70);  // Ensure full 70 bytes are zeroed
    memcpy(serialControl.data, commandData.constData(), qMin(commandData.size(), 70));

    mavlink_msg_serial_control_pack(
        255,                               // system_id (QGC standard GCS ID)
        0,                                 // component_id (QGC component)
        &message,
        serialControl.device,
        serialControl.flags,
        serialControl.timeout,
        serialControl.baudrate,
        serialControl.count,
        serialControl.data
    );

    bool sent = _vehicle->sendMessageOnLink(_vehicle->priorityLink(), message);

    // Detailed debug logging
    qCDebug(UTGCommunicationLog) << "=== UTG SERIAL_CONTROL MESSAGE ===";
    qCDebug(UTGCommunicationLog) << "Command:" << command;
    qCDebug(UTGCommunicationLog) << "Message sent:" << sent;
    qCDebug(UTGCommunicationLog) << "System ID: 255, Component ID: 0";
    qCDebug(UTGCommunicationLog) << "Target Vehicle ID:" << _vehicle->id();
    qCDebug(UTGCommunicationLog) << "Device:" << serialControl.device << "(should be 200)";
    qCDebug(UTGCommunicationLog) << "Flags:" << serialControl.flags << "(should be 0)";
    qCDebug(UTGCommunicationLog) << "Timeout:" << serialControl.timeout << "Baudrate:" << serialControl.baudrate;
    qCDebug(UTGCommunicationLog) << "Data count:" << serialControl.count;
    qCDebug(UTGCommunicationLog) << "Raw command bytes:" << commandData.toHex();
    qCDebug(UTGCommunicationLog) << "=================================";
}

void UTGCommunication::_processResponse(const QString& response)
{
    qCDebug(UTGCommunicationLog) << "Processing response:" << response;
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: _processResponse called with:" << response;
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Response length:" << response.length();
    _addToCommandLog(QString("RX: %1").arg(response));

    QString command, status, data;
    _parseResponse(response, command, status, data);

    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Parsed - command:" << command << "status:" << status << "data:" << data;

    // Stop command timer since we got a response
    _commandTimer->stop();

    // Process next command in queue after successful response
    QMutexLocker locker(&_commandMutex);
    if (!_commandQueue.isEmpty()) {
        QString nextCommand = _commandQueue.dequeue();
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Processing queued command after response:" << nextCommand;
        locker.unlock();
        // Use a small delay to ensure the current response is fully processed
        QTimer::singleShot(50, this, [this, nextCommand]() {
            sendCommand(nextCommand);
        });
    } else {
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Command queue is empty after response";
    }

    // Emit response signal
    emit responseReceived(command, response);

    // Process specific responses based on UTG specification status codes
    if (status == "A") {  // Acknowledge/Success
        if (command == "I2") {  // Device info - used for connection establishment
            _deviceVersion = data;  // Store device info
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: I2 device info received:" << data;
            emit deviceVersionChanged(_deviceVersion);

            // Parse device info to detect units
            parseDeviceInfoForUnits(data);

            if (!_connected) {
                _setConnected(true);
                _addToCommandLog(tr("UTG device connected successfully (I2)"));
                qCDebug(UTGCommunicationLog) << "UTG connected via I2, info:" << data;
            }
        } else if (command == "I3") {  // Firmware version
            _firmwareVersion = data;
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: I3 firmware version received:" << data;
            emit firmwareVersionChanged(_firmwareVersion);
            _addToCommandLog(tr("🔧 Firmware Version: %1").arg(data));
            if (!_connected) {
                _setConnected(true);
            }
        } else if (command == "I4") {  // Serial number - used for connection test
            // Store the serial number from connection test
            _serialNumber = data;
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: I4 serial number received during connection:" << data;
            emit serialNumberChanged(_serialNumber);
            if (!_connected) {
                _setConnected(true);
                _addToCommandLog(tr("UTG device connected successfully (I4)"));
                qCDebug(UTGCommunicationLog) << "UTG connected via I4, serial:" << data;
            }
            // Check if this I4 response is from a reset command
            if (_currentCommand == "@") {
                _addToCommandLog(tr("✅ Device reset completed successfully"));
                _addToCommandLog(tr("📋 Device serial after reset: %1").arg(data));
                qCDebug(UTGCommunicationLog) << "Device reset successful, serial:" << data;
                _addToCommandLog(tr("🔄 Device reset complete - ready for operation"));
            }
        } else if (command == "I1") {  // MCP lever version
            _mcpLeverVersion = data;
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: I1 MCP lever version received:" << data;
            emit mcpLeverVersionChanged(_mcpLeverVersion);
            _addToCommandLog(tr("🔧 MCP Lever Version: %1").arg(data));
        } else if (command == "I5") {  // SWID
            _swid = data;
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: I5 SWID received:" << data;
            emit swidChanged(_swid);
            _addToCommandLog(tr("🆔 SWID: %1").arg(data));
        } else if (command == "S" || command == "SI") {  // Thickness measurement
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Thickness measurement received:" << data;
            // Parse "thickness unit" format
            QStringList parts = data.split(' ', QString::SkipEmptyParts);
            if (parts.size() >= 1) {
                bool ok;
                double thickness = parts[0].toDouble(&ok);
                if (ok) {
                    _currentThickness = thickness;
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Parsed thickness:" << thickness;
                    emit measurementReceived(_currentThickness);
                }
            }
        }
    } else if (status == "S") {  // Success status for thickness measurements
        if (command == "S" || command == "SI") {  // Thickness measurement
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Thickness measurement received (status S):" << data;
            // Parse "thickness unit" format
            QStringList parts = data.split(' ', QString::SkipEmptyParts);
            if (parts.size() >= 1) {
                bool ok;
                double thickness = parts[0].toDouble(&ok);
                if (ok) {
                    _currentThickness = thickness;
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Parsed thickness:" << thickness;
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Setting _currentThickness to:" << _currentThickness;
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Emitting measurementReceived signal with value:" << _currentThickness;
                    emit measurementReceived(_currentThickness);
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: measurementReceived signal emitted successfully";
                    _addToCommandLog(tr("📏 Thickness: %1 mm").arg(thickness, 0, 'f', 2));
                } else {
                    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Failed to parse thickness from:" << parts[0];
                }
            } else {
                qCWarning(UTGCommunicationLog) << "ANDROID LOG: No data parts found in response";
            }
        }
    } else if (status == "C") {  // Calibration needed (but data valid)
        if (command == "S" || command == "SI") {  // Thickness measurement
            QStringList parts = data.split(' ', QString::SkipEmptyParts);
            if (parts.size() >= 1) {
                bool ok;
                double thickness = parts[0].toDouble(&ok);
                if (ok) {
                    _currentThickness = thickness;
                    emit measurementReceived(_currentThickness);
                    _setError(tr("Calibration needed - measurement may be inaccurate"));
                }
            }
        }
    } else if (status == "E") {  // Error
        if (command == "Z") {
            _setError(tr("❌ Zero calibration failed - check probe contact"));
        } else if (command == "@") {
            _setError(tr("❌ Device reset failed - try again"));
        } else {
            _setError(tr("UTG Device error: %1").arg(command));
        }
    } else if (status == "B") {  // Busy/Partial response
        // Handle multi-line responses if needed
        _addToCommandLog(tr("Device busy or partial response"));
    }

    // Handle command-specific responses (regardless of status)
    if (command == "V0") {  // Sound velocity
        _addToCommandLog(tr("📏 Current Sound Velocity: %1").arg(data));
        qCDebug(UTGCommunicationLog) << "Current sound velocity response:" << data;
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: V0 response received:" << data;
        // Parse "velocity unit" format
        QStringList parts = data.split(' ', QString::SkipEmptyParts);
        if (parts.size() >= 1) {
            bool ok;
            int vel = parts[0].toInt(&ok);
            if (ok && vel > 0) {
                qCDebug(UTGCommunicationLog) << "Parsed velocity as integer:" << vel;
                qCWarning(UTGCommunicationLog) << "ANDROID LOG: V0 response parsed velocity:" << vel;
                qCWarning(UTGCommunicationLog) << "ANDROID LOG: Current internal velocity:" << _velocity;
                qCWarning(UTGCommunicationLog) << "ANDROID LOG: Calling setVelocity with:" << vel;
                setVelocity(vel);
            } else {
                qCDebug(UTGCommunicationLog) << "Failed to parse velocity from:" << parts[0];
            }
        } else {
            qCDebug(UTGCommunicationLog) << "Invalid velocity response format:" << data;
        }
    } else if (command == "I0") {  // Help/Commands list
        _addToCommandLog(tr("Commands: %1").arg(data));
    } else if (command == "P0") {  // Probe model
        _addToCommandLog(tr("📡 Current Probe Model: %1").arg(data));
        qCDebug(UTGCommunicationLog) << "Current probe model:" << data;
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: P0 response received:" << data;

        // Update settings with probe model
        updateProbeModelSettings(data);
    } else if (command == "P1") {  // Set probe model response
        _addToCommandLog(tr("✅ Probe model set successfully"));
        qCDebug(UTGCommunicationLog) << "Probe model set successfully";
    } else if (command == "U0") {  // Get units response
        _addToCommandLog(tr("📏 Current Units: %1").arg(data));
        qCDebug(UTGCommunicationLog) << "Current units:" << data;
    } else if (command == "U1") {  // Set units response
        _addToCommandLog(tr("✅ Units set successfully"));
        qCDebug(UTGCommunicationLog) << "Units set successfully";
    } else if (command == "M0") {  // Get memory file count response
        _addToCommandLog(tr("📁 Memory File Count: %1").arg(data));
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: M0 memory file count received:" << data;
    } else if (command == "M1") {  // Get file record count response
        _addToCommandLog(tr("📄 File Record Count: %1").arg(data));
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: M1 file record count received:" << data;
    } else if (command == "M2") {  // Get file records response
        _addToCommandLog(tr("📋 File Records: %1").arg(data));
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: M2 file records received:" << data;
    } else if (command == "MC") {  // Clear file response
        _addToCommandLog(tr("✅ File cleared successfully"));
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: MC file cleared successfully";
    } else if (command == "MCA") {  // Clear all files response
        _addToCommandLog(tr("✅ All files cleared successfully"));
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: MCA all files cleared successfully";
    } else if (command == "Z") {  // Zero calibration response
        _addToCommandLog(tr("✅ Zero calibration completed successfully"));
        _addToCommandLog(tr("📏 Probe zero point has been set"));
        qCDebug(UTGCommunicationLog) << "Zero calibration successful, response data:" << data;
    } else if (command == "@") {  // Reset device response
        _addToCommandLog(tr("✅ Device reset completed successfully"));
        if (!data.isEmpty()) {
            _addToCommandLog(tr("📋 Device info after reset: %1").arg(data));
        }
        qCDebug(UTGCommunicationLog) << "Device reset successful, response data:" << data;
        // After reset, device should be ready for new commands
        _addToCommandLog(tr("🔄 Device reset complete - ready for operation"));
    }
}

void UTGCommunication::_parseResponse(const QString& response, QString& command, QString& status, QString& data)
{
    // Expected format: "COMMAND STATUS [DATA]"
    QStringList parts = response.split(' ', QString::SkipEmptyParts);

    if (parts.size() >= 2) {
        command = parts[0];
        status = parts[1];

        // Join remaining parts as data
        if (parts.size() > 2) {
            data = parts.mid(2).join(' ');
        } else {
            data.clear();
        }
    } else {
        // Malformed response
        command = "UNKNOWN";
        status = "ERROR";
        data = response;
    }
}

void UTGCommunication::_setConnected(bool connected)
{
    if (_connected != connected) {
        _connected = connected;
        emit connectionStatusChanged(_connected);

        if (connected) {
            _addToCommandLog(tr("Connected to UTG device"));
        } else {
            _addToCommandLog(tr("Disconnected from UTG device"));
            _clearCommandQueue();
        }
    }
}

void UTGCommunication::_setError(const QString& error)
{
    _lastError = error;
    emit errorOccurred(_lastError);
    qCWarning(UTGCommunicationLog) << "UTG Error:" << error;
}

void UTGCommunication::_addToCommandLog(const QString& entry)
{
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    QString logEntry = QString("[%1] %2").arg(timestamp, entry);

    _commandLog.append(logEntry);

    // Limit log size
    while (_commandLog.size() > MAX_COMMAND_LOG_ENTRIES) {
        _commandLog.removeFirst();
    }

    emit commandLogChanged();
}

void UTGCommunication::_clearCommandQueue()
{
    QMutexLocker locker(&_commandMutex);
    _commandQueue.clear();
    _commandTimer->stop();
    _currentCommand.clear();
}

void UTGCommunication::clearCommandLog()
{
    _commandLog.clear();
    emit commandLogChanged();
}

void UTGCommunication::parseDeviceInfoForUnits(const QString& deviceInfo)
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Parsing device info for units:" << deviceInfo;

    QString detectedUnit = "mm"; // Default

    // Parse I2 response to detect units
    // Common patterns in UTG device info responses:
    // - "UTG-2600 V1.0 mm" (unit at end)
    // - "Model: UTG-2600, Units: mm, Version: 1.0"
    // - "UTG device mm mode"
    // - Look for "mm" or "inch" keywords

    QString lowerInfo = deviceInfo.toLower();

    if (lowerInfo.contains("inch") || lowerInfo.contains("in")) {
        detectedUnit = "inch";
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Detected INCH units from device info";
    } else if (lowerInfo.contains("mm")) {
        detectedUnit = "mm";
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Detected MM units from device info";
    } else {
        // Try to parse structured format
        QStringList parts = deviceInfo.split(QRegExp("[\\s,]+"), QString::SkipEmptyParts);
        for (const QString& part : parts) {
            QString lowerPart = part.toLower();
            if (lowerPart == "mm" || lowerPart == "millimeter" || lowerPart == "millimeters") {
                detectedUnit = "mm";
                break;
            } else if (lowerPart == "inch" || lowerPart == "inches" || lowerPart == "in") {
                detectedUnit = "inch";
                break;
            }
        }
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Parsed units from device info:" << detectedUnit;
    }

    // Always update the detected unit and emit signal (even if same)
    _detectedUnit = detectedUnit;
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Unit set to:" << _detectedUnit;
    emit detectedUnitChanged(_detectedUnit);
    _addToCommandLog(tr("📐 Detected Units: %1").arg(_detectedUnit));

    // Also update the settings if available
    if (_settings && _settings->measurementUnit()) {
        int unitIndex = (_detectedUnit == "inch") ? 1 : 0; // 0=mm, 1=inch
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Updating settings unit to index:" << unitIndex;
        _settings->measurementUnit()->setRawValue(unitIndex);
    }
}

void UTGCommunication::updateProbeModelSettings(const QString& probeModel)
{
    qCWarning(UTGCommunicationLog) << "ANDROID LOG: Updating probe model settings with:" << probeModel;

    // Map probe model strings to settings indices
    // Based on the probe models defined in UTGSettings
    QStringList probeModels = {"P5EE", "N05", "N07", "HT5", "N02"};

    int probeIndex = probeModels.indexOf(probeModel);
    if (probeIndex == -1) {
        // If not found, try to find partial matches
        for (int i = 0; i < probeModels.size(); i++) {
            if (probeModel.contains(probeModels[i], Qt::CaseInsensitive)) {
                probeIndex = i;
                break;
            }
        }
    }

    if (probeIndex >= 0) {
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Mapped probe model" << probeModel << "to index:" << probeIndex;

        // Update the settings if available
        if (_settings && _settings->probeModel()) {
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Updating settings probe model from" << _settings->probeModel()->rawValue().toInt() << "to:" << probeIndex;
            _settings->probeModel()->setRawValue(probeIndex);
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Settings probe model updated to:" << _settings->probeModel()->rawValue().toInt();
        } else {
            qCWarning(UTGCommunicationLog) << "ANDROID LOG: Cannot update probe model settings - missing settings object";
        }
    } else {
        qCWarning(UTGCommunicationLog) << "ANDROID LOG: Unknown probe model:" << probeModel << "- cannot map to settings";
    }
}

void UTGCommunication::saveCurrentReading()
{
    if (_readingManager && _currentThickness > 0.0) {
        _readingManager->onNewReading(_currentThickness, _detectedUnit, 0);
        qCDebug(UTGCommunicationLog) << "Manually saved reading:" << _currentThickness << _detectedUnit;
    }
}

void UTGCommunication::saveReadingWithNotes(const QString& notes)
{
    if (_readingManager && _currentThickness > 0.0) {
        UTGReading reading(_currentThickness, _detectedUnit);
        reading.notes = notes;
        reading.temperature = _temperature;

        if (_settings) {
            reading.measurementMode = _settings->measurementMode()->rawValue().toInt();
            reading.soundVelocity = _settings->soundVelocity()->rawValue().toDouble();
            reading.gain = _settings->gain()->rawValue().toInt();
        }

        // Add GPS location if available from vehicle
        if (_vehicle && _vehicle->coordinate().isValid()) {
            reading.location = _vehicle->coordinate();
        }

        _readingManager->addReading(reading);
        qCDebug(UTGCommunicationLog) << "Manually saved reading with notes:" << reading.toString();
    }
}


