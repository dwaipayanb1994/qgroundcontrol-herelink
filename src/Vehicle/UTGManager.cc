/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UTGManager.h"
#include "Vehicle.h"
#include "QGCApplication.h"
#include "SettingsManager.h"
#include "QGC.h"
#include <QDebug>

Q_LOGGING_CATEGORY(UTGManagerLog, "UTGManagerLog")

UTGManager::UTGManager(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _settings(nullptr)
    , _connectionTimer(new QTimer(this))
    , _measurementTimer(new QTimer(this))
    , _mavlinkCheckTimer(new QTimer(this))
    , _connected(false)
    , _enabled(false)
    , _currentThickness(0.0f)
    , _status(STATUS_DISCONNECTED)
    , _measuring(false)
    , _cachedBaudRate(9600)
{
    // Safely get UTG settings with null checks
    QGCApplication* app = qgcApp();
    if (app && app->toolbox() && app->toolbox()->settingsManager()) {
        _settings = app->toolbox()->settingsManager()->utgSettings();
    }

    if (!_settings) {
        qCCritical(UTGManagerLog) << "Failed to get UTGSettings - UTGManager will be disabled";
        return;
    }
    
    // Setup timers
    _connectionTimer->setSingleShot(true);
    _measurementTimer->setSingleShot(false);
    _mavlinkCheckTimer->setSingleShot(false);
    _mavlinkCheckTimer->setInterval(100); // Check for MAVLink data every 100ms

    connect(_connectionTimer, &QTimer::timeout, this, &UTGManager::_onConnectionTimer);
    connect(_measurementTimer, &QTimer::timeout, this, &UTGManager::_onMeasurementTimer);
    connect(_mavlinkCheckTimer, &QTimer::timeout, this, &UTGManager::_onMAVLinkDataReceived);

    // Connect to settings changes
    connect(_settings->enabled(), &Fact::rawValueChanged, this, &UTGManager::_processSettings);
    connect(_settings->autoConnect(), &Fact::rawValueChanged, this, &UTGManager::_processSettings);

    // Connect to vehicle MAVLink messages for UTG data
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &UTGManager::_handleMAVLinkMessage);
        connect(_vehicle, &Vehicle::connectionLostChanged, this, &UTGManager::_onVehicleConnectionChanged);
        connect(_vehicle, &Vehicle::communicationLostChanged, this, &UTGManager::_onVehicleConnectionChanged);
    }
    
    // Initial settings processing
    _processSettings();
}

UTGManager::~UTGManager()
{
    disconnectFromUTG();
}

QString UTGManager::statusText() const
{
    switch (_status) {
    case STATUS_DISCONNECTED:
        return tr("Disconnected");
    case STATUS_CONNECTING:
        return tr("Connecting...");
    case STATUS_CONNECTED:
        return tr("Connected");
    case STATUS_ERROR:
        return tr("Error: %1").arg(_lastError);
    case STATUS_MEASURING:
        return tr("Measuring");
    case STATUS_CALIBRATING:
        return tr("Calibrating");
    default:
        return tr("Unknown");
    }
}

void UTGManager::setEnabled(bool enabled)
{
    if (!_settings) {
        qCWarning(UTGManagerLog) << "Cannot set enabled state - settings not available";
        return;
    }

    if (_enabled != enabled) {
        _enabled = enabled;
        _settings->enabled()->setRawValue(enabled);

        if (enabled && _settings->autoConnect()->rawValue().toBool()) {
            connectToUTG();
        } else if (!enabled) {
            disconnectFromUTG();
        }

        emit enabledChanged(_enabled);
    }
}

void UTGManager::connectToUTG()
{
    if (_connected || _status == STATUS_CONNECTING) {
        return;
    }
    
    qCDebug(UTGManagerLog) << "Attempting to connect to UTG";
    _setStatus(STATUS_CONNECTING);
    _setupMAVLinkConnection();
}

void UTGManager::disconnectFromUTG()
{
    if (!_connected && _status != STATUS_CONNECTING) {
        return;
    }
    
    qCDebug(UTGManagerLog) << "Disconnecting from UTG";
    stopMeasurement();
    _closeMAVLinkConnection();
    _setStatus(STATUS_DISCONNECTED);
    _connected = false;
    emit connectedChanged(_connected);
}

void UTGManager::reconnect()
{
    disconnectFromUTG();
    QTimer::singleShot(1000, this, &UTGManager::connectToUTG);
}

void UTGManager::startSingleMeasurement()
{
    if (!_connected) {
        _setError(tr("UTG not connected"));
        return;
    }
    
    _sendCommand(CMD_GET_THICKNESS);
}

void UTGManager::startContinuousMeasurement()
{
    if (!_connected) {
        _setError(tr("UTG not connected"));
        return;
    }
    
    _sendCommand(CMD_START_CONTINUOUS);
    _measuring = true;
    _measurementTimer->start(MEASUREMENT_INTERVAL_MS);
    _setStatus(STATUS_MEASURING);
    emit measuringChanged(_measuring);
}

void UTGManager::stopMeasurement()
{
    if (_measuring) {
        _sendCommand(CMD_STOP_CONTINUOUS);
        _measuring = false;
        _measurementTimer->stop();
        _setStatus(STATUS_CONNECTED);
        emit measuringChanged(_measuring);
    }
}

void UTGManager::triggerMeasurement()
{
    startSingleMeasurement();
}

void UTGManager::setGain(int gain)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(gain));
    _sendCommand(CMD_SET_GAIN, data);
}

void UTGManager::setSoundVelocity(double velocity)
{
    if (!_connected) return;
    
    QByteArray data;
    // Convert velocity to bytes (assuming 4-byte float)
    float vel = static_cast<float>(velocity);
    data.append(reinterpret_cast<const char*>(&vel), sizeof(float));
    _sendCommand(CMD_SET_VELOCITY, data);
}

void UTGManager::setZeroOffset(double offset)
{
    if (!_connected) return;
    
    QByteArray data;
    float off = static_cast<float>(offset);
    data.append(reinterpret_cast<const char*>(&off), sizeof(float));
    _sendCommand(CMD_SET_ZERO_OFFSET, data);
}

void UTGManager::setThreshold(int threshold)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(threshold));
    _sendCommand(CMD_SET_THRESHOLD, data);
}

void UTGManager::setPulseWidth(int width)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(reinterpret_cast<const char*>(&width), sizeof(int));
    _sendCommand(CMD_SET_PULSE_WIDTH, data);
}

void UTGManager::setFrequency(double frequency)
{
    if (!_connected) return;
    
    QByteArray data;
    float freq = static_cast<float>(frequency);
    data.append(reinterpret_cast<const char*>(&freq), sizeof(float));
    _sendCommand(CMD_SET_FREQUENCY, data);
}

void UTGManager::setMeasurementUnit(int unit)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(unit));
    _sendCommand(CMD_SET_UNIT, data);
}

void UTGManager::setMeasurementMode(int mode)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(mode));
    _sendCommand(CMD_SET_MODE, data);
}

void UTGManager::setMaterialType(int material)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(material));
    _sendCommand(CMD_SET_MATERIAL, data);
}

void UTGManager::startCalibration(int mode, double referenceValue)
{
    if (!_connected) return;
    
    QByteArray data;
    data.append(static_cast<char>(mode));
    if (referenceValue > 0.0) {
        float ref = static_cast<float>(referenceValue);
        data.append(reinterpret_cast<const char*>(&ref), sizeof(float));
    }
    
    _setStatus(STATUS_CALIBRATING);
    _sendCommand(CMD_CALIBRATE, data);
}

void UTGManager::performZeroCalibration()
{
    startCalibration(0); // Zero calibration mode
}

void UTGManager::performVelocityCalibration(double knownThickness)
{
    startCalibration(2, knownThickness); // Velocity calibration mode
}

void UTGManager::resetUTG()
{
    if (!_connected) return;
    
    _sendCommand(CMD_RESET);
    // After reset, we might need to reconfigure
    QTimer::singleShot(2000, this, &UTGManager::_updateSettings);
}

void UTGManager::getStatus()
{
    if (!_connected) return;
    
    _sendCommand(CMD_GET_STATUS);
}

void UTGManager::getTemperature()
{
    if (!_connected) return;

    _sendCommand(CMD_GET_TEMPERATURE);
}

void UTGManager::_onMAVLinkDataReceived()
{
    // This method is called periodically to check for MAVLink data
    // The actual data processing happens in _handleMAVLinkMessage
    // This is just a placeholder for the timer-based approach
}



void UTGManager::_onConnectionTimer()
{
    if (_status == STATUS_CONNECTING) {
        connectToUTG();
    } else if (_status == STATUS_ERROR) {
        reconnect();
    }
}

void UTGManager::_onMeasurementTimer()
{
    if (_measuring && _connected) {
        startSingleMeasurement();
    }
}

void UTGManager::_processSettings()
{
    bool wasEnabled = _enabled;
    _enabled = _settings->enabled()->rawValue().toBool();

    if (_enabled != wasEnabled) {
        emit enabledChanged(_enabled);
    }

    // Auto-connect when enabled and vehicle is available
    if (_enabled && !_connected && _vehicle && _vehicle->priorityLink()) {
        connectToUTG();
    } else if (!_enabled && _connected) {
        disconnectFromUTG();
    }
}

void UTGManager::_setupMAVLinkConnection()
{
    _closeMAVLinkConnection();

    if (!_vehicle) {
        _setError(tr("No vehicle available for MAVLink communication"));
        _setStatus(STATUS_ERROR);
        return;
    }

    if (!_vehicle->priorityLink()) {
        _setError(tr("Vehicle has no active communication link"));
        _setStatus(STATUS_ERROR);
        return;
    }

    // Start MAVLink data checking timer
    _mavlinkCheckTimer->start();

    _connected = true;
    _setStatus(STATUS_CONNECTED);
    emit connectedChanged(_connected);

    // Initialize UTG with current settings
    _updateSettings();

    qCDebug(UTGManagerLog) << "Connected to UTG via MAVLink on vehicle" << _vehicle->id();
}

void UTGManager::_closeMAVLinkConnection()
{
    // Stop MAVLink data checking timer
    _mavlinkCheckTimer->stop();

    _receiveBuffer.clear();

    _connected = false;
    _setStatus(STATUS_DISCONNECTED);
    emit connectedChanged(_connected);

    qCDebug(UTGManagerLog) << "Disconnected from UTG MAVLink";
}

void UTGManager::_sendCommand(UTGCommand cmd, const QByteArray& data)
{
    if (!_connected || !_vehicle) {
        qCWarning(UTGManagerLog) << "Cannot send command: not connected to vehicle";
        return;
    }

    QMutexLocker locker(&_commandMutex);

    QByteArray command = _buildCommand(cmd, data);
    _sendMAVLinkData(command);

    qCDebug(UTGManagerLog) << "Sent command:" << QString::number(cmd, 16) << "data size:" << data.size();
}

void UTGManager::_processReceivedData(const QByteArray& data)
{
    // Simple protocol: [START][CMD][LEN][DATA][CHECKSUM]
    // START = 0xAA, CMD = command byte, LEN = data length, DATA = payload, CHECKSUM = XOR of all bytes

    if (data.size() < 4) return; // Minimum: START + CMD + LEN + CHECKSUM

    if (static_cast<unsigned char>(data[0]) != 0xAA) {
        // Look for start byte
        int startIndex = data.indexOf(static_cast<char>(0xAA));
        if (startIndex > 0) {
            _receiveBuffer.remove(0, startIndex);
        } else {
            _receiveBuffer.clear();
        }
        return;
    }

    unsigned char cmd = static_cast<unsigned char>(data[1]);
    unsigned char len = static_cast<unsigned char>(data[2]);

    if (data.size() < 4 + len) return; // Not enough data yet

    QByteArray payload = data.mid(3, len);
    unsigned char receivedChecksum = static_cast<unsigned char>(data[3 + len]);

    // Verify checksum
    unsigned char calculatedChecksum = 0;
    for (int i = 0; i < 3 + len; i++) {
        calculatedChecksum ^= static_cast<unsigned char>(data[i]);
    }

    if (calculatedChecksum != receivedChecksum) {
        qCWarning(UTGManagerLog) << "Checksum mismatch";
        _receiveBuffer.remove(0, 4 + len);
        return;
    }

    // Process valid response
    _handleResponse(static_cast<UTGCommand>(cmd), payload);
    _receiveBuffer.remove(0, 4 + len);
}

void UTGManager::_handleResponse(UTGCommand cmd, const QByteArray& response)
{
    switch (cmd) {
    case CMD_GET_THICKNESS:
        if (response.size() >= sizeof(float)) {
            float thickness = *reinterpret_cast<const float*>(response.data());
            _currentThickness = thickness;
            emit thicknessChanged(thickness);
            emit measurementReceived(thickness, QDateTime::currentMSecsSinceEpoch());
            qCDebug(UTGManagerLog) << "Thickness measurement:" << thickness;
        }
        break;

    case CMD_GET_STATUS:
        if (response.size() >= 1) {
            unsigned char status = static_cast<unsigned char>(response[0]);
            qCDebug(UTGManagerLog) << "UTG status:" << status;
        }
        break;

    case CMD_GET_TEMPERATURE:
        if (response.size() >= sizeof(float)) {
            float temperature = *reinterpret_cast<const float*>(response.data());
            emit temperatureReceived(temperature);
            qCDebug(UTGManagerLog) << "Temperature:" << temperature;
        }
        break;

    case CMD_CALIBRATE:
        if (response.size() >= 1) {
            bool success = response[0] != 0;
            emit calibrationCompleted(success);
            _setStatus(STATUS_CONNECTED);
            qCDebug(UTGManagerLog) << "Calibration" << (success ? "successful" : "failed");
        }
        break;

    default:
        qCDebug(UTGManagerLog) << "Received response for command:" << QString::number(cmd, 16);
        break;
    }
}

void UTGManager::_setStatus(UTGStatus status)
{
    if (_status != status) {
        _status = status;
        emit statusChanged(_status);
    }
}

void UTGManager::_setError(const QString& error)
{
    _lastError = error;
    emit errorChanged(_lastError);
}

void UTGManager::_updateSettings()
{
    if (!_connected) return;

    // Send current settings to UTG
    setGain(_settings->gain()->rawValue().toInt());
    setSoundVelocity(_settings->soundVelocity()->rawValue().toDouble());
    setZeroOffset(_settings->zeroOffset()->rawValue().toDouble());
    setThreshold(_settings->threshold()->rawValue().toInt());
    setPulseWidth(_settings->pulseWidth()->rawValue().toInt());
    setFrequency(_settings->frequency()->rawValue().toDouble());
    setMeasurementUnit(_settings->measurementUnit()->rawValue().toInt());
    setMeasurementMode(_settings->measurementMode()->rawValue().toInt());
    setMaterialType(_settings->materialType()->rawValue().toInt());
}

QByteArray UTGManager::_buildCommand(UTGCommand cmd, const QByteArray& data)
{
    QByteArray command;
    command.append(static_cast<char>(0xAA)); // Start byte
    command.append(static_cast<char>(cmd));  // Command
    command.append(static_cast<char>(data.size())); // Data length
    command.append(data); // Data payload

    // Calculate checksum (XOR of all bytes)
    unsigned char checksum = 0;
    for (char byte : command) {
        checksum ^= static_cast<unsigned char>(byte);
    }
    command.append(static_cast<char>(checksum));

    return command;
}

bool UTGManager::_validateResponse(const QByteArray& response)
{
    return response.size() >= 4 && static_cast<unsigned char>(response[0]) == 0xAA;
}

void UTGManager::_sendMAVLinkData(const QByteArray& data)
{
    if (!_vehicle || data.size() > 70) {  // SERIAL_CONTROL data limit
        qCWarning(UTGManagerLog) << "Cannot send MAVLink data: invalid vehicle or data too large";
        return;
    }

    // Send data via MAVLink SERIAL_CONTROL message
    mavlink_message_t message;
    mavlink_serial_control_t serialControl;

    serialControl.device = SERIAL_CONTROL_DEV_GPS1;  // Use GPS1 as identifier
    serialControl.flags = SERIAL_CONTROL_FLAG_RESPOND;
    serialControl.timeout = 0;
    serialControl.baudrate = 115200;
    serialControl.count = data.size();
    memcpy(serialControl.data, data.constData(), data.size());

    mavlink_msg_serial_control_encode(_vehicle->id(), MAV_COMP_ID_AUTOPILOT1, &message, &serialControl);
    _vehicle->sendMessageOnLink(_vehicle->priorityLink(), message);

    qCDebug(UTGManagerLog) << "Sent MAVLink SERIAL_CONTROL data:" << data.size() << "bytes";
}

void UTGManager::_handleMAVLinkMessage(const mavlink_message_t& message)
{
    if (message.msgid == MAVLINK_MSG_ID_SERIAL_CONTROL) {
        mavlink_serial_control_t serialControl;
        mavlink_msg_serial_control_decode(&message, &serialControl);

        // Check if this is UTG data (using GPS1 device identifier)
        if (serialControl.device == SERIAL_CONTROL_DEV_GPS1 &&
            (serialControl.flags & SERIAL_CONTROL_FLAG_RESPOND) == 0) {

            // Process UTG data received from ArduPilot
            QByteArray data(reinterpret_cast<const char*>(serialControl.data), serialControl.count);
            _receiveBuffer.append(data);

            // Process complete messages
            while (_receiveBuffer.size() >= 4) { // Minimum message size
                _processReceivedData(_receiveBuffer);
                break; // Process one message at a time
            }

            qCDebug(UTGManagerLog) << "Received MAVLink SERIAL_CONTROL data:" << data.size() << "bytes";
        }
    }
}

void UTGManager::_onVehicleConnectionChanged()
{
    if (!_vehicle) return;

    if (_vehicle->connectionLost() || _vehicle->communicationLost()) {
        if (_connected) {
            qCDebug(UTGManagerLog) << "Vehicle connection lost, disconnecting UTG";
            _closeMAVLinkConnection();
        }
    } else if (_enabled && !_connected) {
        qCDebug(UTGManagerLog) << "Vehicle connection restored, attempting UTG connection";
        connectToUTG();
    }
}
