/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

/// @file
/// @brief UTG (Ultrasonic Thickness Gauge) Communication Manager
/// Implements ASCII-based communication with UTG devices via MAVLink SERIAL_CONTROL

#pragma once

#include <QObject>
#include <QTimer>
#include <QQueue>
#include <QMutex>
#include <QStringList>
#include <QDateTime>
#include "QGCLoggingCategory.h"
#include "MAVLinkProtocol.h"

Q_DECLARE_LOGGING_CATEGORY(UTGCommunicationLog)

class Vehicle;
class UTGSettings;
class UTGReadingManager;

/// UTG Communication Manager
/// Handles ASCII-based communication with UTG devices via MAVLink SERIAL_CONTROL messages
class UTGCommunication : public QObject
{
    Q_OBJECT
    
    // Properties for QML binding
    Q_PROPERTY(bool connected READ connected NOTIFY connectionStatusChanged)
    Q_PROPERTY(double currentThickness READ currentThickness NOTIFY measurementReceived)
    Q_PROPERTY(QString deviceVersion READ deviceVersion NOTIFY deviceVersionChanged)
    Q_PROPERTY(QString serialNumber READ serialNumber NOTIFY serialNumberChanged)
    Q_PROPERTY(QString firmwareVersion READ firmwareVersion NOTIFY firmwareVersionChanged)
    Q_PROPERTY(QString mcpLeverVersion READ mcpLeverVersion NOTIFY mcpLeverVersionChanged)
    Q_PROPERTY(QString swid READ swid NOTIFY swidChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorOccurred)
    Q_PROPERTY(double temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(double velocity READ velocity WRITE setVelocity NOTIFY velocityChanged)
    Q_PROPERTY(int gain READ gain WRITE setGain NOTIFY gainChanged)
    Q_PROPERTY(double rangeStart READ rangeStart WRITE setRangeStart NOTIFY rangeChanged)
    Q_PROPERTY(double rangeEnd READ rangeEnd WRITE setRangeEnd NOTIFY rangeChanged)
    Q_PROPERTY(QStringList commandLog READ commandLog NOTIFY commandLogChanged)
    Q_PROPERTY(QString detectedUnit READ detectedUnit NOTIFY detectedUnitChanged)
    Q_PROPERTY(UTGReadingManager* readingManager READ readingManager CONSTANT)

public:
    UTGCommunication(Vehicle* vehicle, QObject* parent = nullptr);
    ~UTGCommunication();

    // UTG Device Constants (per specification)
    static const uint8_t SERIAL_CONTROL_DEV_UTG = 200;
    static const uint8_t SERIAL_CONTROL_FLAG_REPLY = 0x01;
    static const uint8_t SERIAL_CONTROL_FLAG_RESPOND = 0x02;
    static const uint8_t SERIAL_CONTROL_FLAG_EXCLUSIVE = 0x04;
    static const uint8_t SERIAL_CONTROL_FLAG_MULTI = 0x08;
    
    static const uint32_t UTG_BAUDRATE = 9600;
    static const uint16_t UTG_TIMEOUT = 1000;   // 1 second timeout like Python script
    static const uint16_t UTG_CALIBRATION_TIMEOUT = 5000;  // 5 seconds for calibration commands
    static const int MAX_COMMAND_LOG_ENTRIES = 100;

    // Property getters
    bool connected() const { return _connected; }
    double currentThickness() const { return _currentThickness; }
    QString deviceVersion() const { return _deviceVersion; }
    QString serialNumber() const { return _serialNumber; }
    QString firmwareVersion() const { return _firmwareVersion; }
    QString mcpLeverVersion() const { return _mcpLeverVersion; }
    QString swid() const { return _swid; }
    QString lastError() const { return _lastError; }
    double temperature() const { return _temperature; }
    double velocity() const { return _velocity; }
    int gain() const { return _gain; }
    double rangeStart() const { return _rangeStart; }
    double rangeEnd() const { return _rangeEnd; }
    QStringList commandLog() const { return _commandLog; }
    QString detectedUnit() const { return _detectedUnit; }
    UTGReadingManager* readingManager() const { return _readingManager; }

    // Property setters
    void setVelocity(double velocity);
    void setGain(int gain);
    void setRangeStart(double start);
    void setRangeEnd(double end);

public slots:
    // Connection management
    void connectToUTG();
    void disconnectFromUTG();
    bool checkUTGConfiguration();  // Verify ArduPilot parameters
    
    // Information commands per UTG specification
    Q_INVOKABLE void getDeviceInfo();       // I2 - Get device info
    void getVersion();                     // I3 - Get software version (legacy)
    Q_INVOKABLE void getFirmwareVersion(); // I3 - Get firmware version
    Q_INVOKABLE void getSerialNumber();    // I4 - Get serial number
    Q_INVOKABLE void getSWID();            // I5 - Get SWID
    Q_INVOKABLE void getMCPLeverVersion();  // I1 - Get MCP lever version
    void getHelp();             // I0 - List commands
    void getTemperature();      // Custom command (not in spec)
    
    // Measurement commands per UTG specification
    void takeMeasurement();     // S - Get stable thickness
    void measureThickness();    // S - Get stable thickness (alias)
    void getInstantThickness(); // SI - Get instant thickness (faster)
    void startContinuousMeasurement(); // Start continuous fast measurements
    void stopContinuousMeasurement();  // Stop continuous measurements
    
    // Configuration commands (UTG specification)
    Q_INVOKABLE void getVelocity();        // V0 - Get sound velocity
    void setVelocityCommand(double velocity); // V1 - Set sound velocity
    Q_INVOKABLE void getProbeModel();      // P0 - Get probe model
    Q_INVOKABLE void setProbeModel(const QString& model); // P1 - Set probe model
    Q_INVOKABLE void getUnits();           // U0 - Get measurement units (mm/inch)
    Q_INVOKABLE void setUnits(const QString& units);   // U1 - Set measurement units
    // Memory functions (UTG specification)
    Q_INVOKABLE void getMemoryFileCount();     // M0 - Get memory file count
    Q_INVOKABLE void getFileRecordCount(int fileIndex); // M1 - Get file record count
    Q_INVOKABLE void getFileRecords(int fileIndex);     // M2 - Get file records
    Q_INVOKABLE void clearFile(int fileIndex);          // MC - Clear specific file
    Q_INVOKABLE void clearAllFiles();                   // MCA - Clear all files


    
    // Calibration and control commands
    void performZeroCalibration();         // Z - Zero probe calibration (UTG spec)
    void resetDevice();                    // @ - Reset device (UTG spec)
    
    // Generic command sending
    void sendCommand(const QString& command);

    // Log management
    void clearCommandLog();

    // Reading management
    Q_INVOKABLE void saveCurrentReading();
    Q_INVOKABLE void saveReadingWithNotes(const QString& notes);

signals:
    // Core signals per specification
    void connectionStatusChanged(bool connected);
    void measurementReceived(double thickness);
    void responseReceived(const QString& command, const QString& response);
    void errorOccurred(const QString& error);
    
    // Additional property signals
    void deviceVersionChanged(const QString& version);
    void serialNumberChanged(const QString& serialNumber);
    void firmwareVersionChanged(const QString& firmwareVersion);
    void mcpLeverVersionChanged(const QString& mcpLeverVersion);
    void swidChanged(const QString& swid);
    void temperatureChanged(double temperature);
    void velocityChanged(double velocity);
    void gainChanged(int gain);
    void rangeChanged(double start, double end);
    void commandLogChanged();
    void detectedUnitChanged(const QString& unit);

public:
    // MAVLink message handling
    void handleSerialControlMessage(const mavlink_message_t& message);
    void handleStatusTextMessage(const mavlink_message_t& message);

private slots:
    void _onCommandTimeout();
    void _onVehicleConnectionChanged();

private:
    // Internal methods
    void _sendSerialControlMessage(const QString& command, uint16_t timeout = UTG_TIMEOUT);
    void _processResponse(const QString& response);
    void _parseResponse(const QString& response, QString& command, QString& status, QString& data);
    void _setConnected(bool connected);
    void _setError(const QString& error);
    void _addToCommandLog(const QString& entry);
    void _clearCommandQueue();
    void parseDeviceInfoForUnits(const QString& deviceInfo);
    void updateProbeModelSettings(const QString& probeModel);

    // Member variables
    Vehicle* _vehicle;
    UTGSettings* _settings;
    UTGReadingManager* _readingManager;
    bool _connected;
    double _currentThickness;
    QString _deviceVersion;
    QString _serialNumber;
    QString _firmwareVersion;
    QString _mcpLeverVersion;
    QString _swid;
    QString _lastError;
    double _temperature;
    double _velocity;
    int _gain;
    double _rangeStart;
    double _rangeEnd;
    QStringList _commandLog;
    QString _detectedUnit;

    // Command management
    QTimer* _commandTimer;
    QTimer* _continuousTimer;  // For continuous measurements
    QQueue<QString> _commandQueue;
    QString _currentCommand;
    QMutex _commandMutex;
    bool _continuousMeasurement;

    // Response buffer for partial messages
    QString _responseBuffer;
};
