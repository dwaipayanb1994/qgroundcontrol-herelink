#include "CameraController.h"

#include <QHostAddress>
#include <QVariantMap>
#include <QDateTime>

#include "CameraTransport.h"
#include "CameraCommandRegistry.h"

namespace {
static constexpr int MAX_LOG_ENTRIES = 200;
}

CameraController::CameraController(QObject* parent)
    : QObject(parent)
    , _transport(new CameraTransport(this))
{
    const QVector<CameraCommandDefinition>& defs = CameraCommandRegistry::all();
    _definitions = defs;
    _rebuildCatalog();

    connect(_transport, &CameraTransport::dataReceived, this, &CameraController::_handleTransportData);
    connect(_transport, &CameraTransport::errorOccurred, this, &CameraController::_handleTransportError);
}

CameraController::~CameraController() = default;

bool CameraController::serialConnected() const
{
    return _transport->isSerialOpen();
}

bool CameraController::udpConnected() const
{
    return _transport->isUdpReady();
}

int CameraController::activeTransportMode() const
{
    return static_cast<int>(_transportMode);
}

void CameraController::setActiveTransportMode(int mode)
{
    TransportMode newMode = static_cast<TransportMode>(mode);
    if (_transportMode == newMode) {
        return;
    }
    _transportMode = newMode;
    emit activeTransportModeChanged(mode);
}

bool CameraController::connectSerial(const QString& portName, int baudRate)
{
    QString error;
    if (!_transport->openSerial(portName, baudRate, &error)) {
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }
    emit serialConnectionChanged(true);
    _appendLog(tr("[Serial] Connected to %1 @ %2 baud").arg(portName).arg(baudRate));
    return true;
}

void CameraController::disconnectSerial()
{
    if (!serialConnected()) {
        return;
    }
    const QString port = _transport->serialPortName();
    _transport->closeSerial();
    emit serialConnectionChanged(false);
    _appendLog(tr("[Serial] Disconnected from %1").arg(port));
}

bool CameraController::configureUdp(const QString& deviceIp,
                                    quint16 devicePort,
                                    quint16 localPort)
{
    QString error;
    QHostAddress address(deviceIp);
    if (address.isNull()) {
        error = tr("Invalid device IP address: %1").arg(deviceIp);
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }

    if (!_transport->configureUdp(address, devicePort, localPort, &error)) {
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }

    emit udpConnectionChanged(true);
    _appendLog(tr("[UDP] Bound to %1 (local %2) -> remote %3:%4")
               .arg(address.toString())
               .arg(localPort)
               .arg(address.toString())
               .arg(devicePort));
    return true;
}

void CameraController::disconnectUdp()
{
    if (!udpConnected()) {
        return;
    }
    quint16 localPort = _transport->localUdpPort();
    _transport->closeUdp();
    emit udpConnectionChanged(false);
    _appendLog(tr("[UDP] Socket on %1 closed").arg(localPort));
}

bool CameraController::sendCommand(const QString& key,
                                   const QString& dataOverride)
{
    return sendCommandWithParameters(key, {{ QStringLiteral("data"), dataOverride }});
}

bool CameraController::sendCommandWithParameters(const QString& key,
                                                 const QVariantMap& parameters)
{
    const CameraCommandDefinition* definition = _definitionForKey(key);
    if (!definition) {
        _lastError = tr("Unknown command key: %1").arg(key);
        emit errorOccurred(_lastError);
        return false;
    }

    const QString explicitData = parameters.value(QStringLiteral("data")).toString();
    const QString resolvedData = _resolveDataForCommand(*definition, explicitData, parameters);

    QString error;
    CameraProtocol::TransportSource source = CameraProtocol::TransportSource::Serial;
    if (_transportMode == Auto) {
        if (udpConnected()) {
            source = CameraProtocol::TransportSource::Udp;
        } else if (serialConnected()) {
            source = CameraProtocol::TransportSource::Serial;
        } else {
            error = tr("No transport configured for sending commands");
        }
    } else if (_transportMode == SerialOnly) {
        if (!serialConnected()) {
            error = tr("Serial transport not connected");
        }
        source = CameraProtocol::TransportSource::Serial;
    } else if (_transportMode == UdpOnly) {
        if (!udpConnected()) {
            error = tr("UDP transport not configured");
        }
        source = CameraProtocol::TransportSource::Udp;
    }

    if (!error.isEmpty()) {
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }

    QByteArray frame = CameraProtocol::buildFrame(*definition, resolvedData, source, &error);
    if (frame.isEmpty()) {
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }

    const QString preview = QString::fromLatin1(frame.toHex(' ')).toUpper();
    _lastFrame = preview;
    emit lastFrameChanged(_lastFrame);

    bool success = false;
    if (source == CameraProtocol::TransportSource::Serial) {
        success = _transport->sendSerial(frame, &error);
    } else {
        success = _transport->sendUdp(frame, &error);
    }

    if (!success) {
        _lastError = error;
        emit errorOccurred(_lastError);
        return false;
    }

    const QString transportLabel = (source == CameraProtocol::TransportSource::Serial) ? QStringLiteral("Serial") : QStringLiteral("UDP");
    _appendLog(tr("[TX][%1] %2").arg(transportLabel, preview));
    return true;
}

QString CameraController::previewCommand(const QString& key,
                                         const QString& dataOverride) const
{
    const CameraCommandDefinition* definition = _definitionForKey(key);
    if (!definition) {
        return QString();
    }

    QString dummyError;
    CameraProtocol::TransportSource source = CameraProtocol::TransportSource::Serial;
    if (_transportMode == UdpOnly || (_transportMode == Auto && udpConnected())) {
        source = CameraProtocol::TransportSource::Udp;
    }

    QByteArray frame = CameraProtocol::buildFrame(*definition, dataOverride, source, &dummyError);
    if (frame.isEmpty()) {
        return QString();
    }
    return QString::fromLatin1(frame.toHex(' ')).toUpper();
}

void CameraController::clearLog()
{
    if (_logEntries.isEmpty()) {
        return;
    }
    _logEntries.clear();
    emit logChanged();
}

void CameraController::_handleTransportData(const QByteArray& payload)
{
    QString readable = QString::fromLatin1(payload.toHex(' ')).toUpper();
    if (readable.isEmpty()) {
        readable = QStringLiteral("<empty>");
    }
    _appendLog(tr("[RX] %1").arg(readable));
}

void CameraController::_handleTransportError(const QString& message)
{
    _lastError = message;
    _appendLog(tr("[ERR] %1").arg(message));
    emit errorOccurred(_lastError);
}

const CameraCommandDefinition* CameraController::_definitionForKey(const QString& key) const
{
    for (const CameraCommandDefinition& def : _definitions) {
        if (def.key == key) {
            return &def;
        }
    }
    return nullptr;
}

QString CameraController::_resolveDataForCommand(const CameraCommandDefinition& definition,
                                                 const QString& explicitData,
                                                 const QVariantMap& parameters) const
{
    if (!explicitData.isEmpty()) {
        return explicitData;
    }

    if (parameters.contains(QStringLiteral("data"))) {
        return parameters.value(QStringLiteral("data")).toString();
    }

    if (parameters.contains(QStringLiteral("optionData"))) {
        return parameters.value(QStringLiteral("optionData")).toString();
    }

    if (definition.autoGenerateData) {
        return _generateAutoData(definition);
    }

    return definition.defaultData;
}

QString CameraController::_generateAutoData(const CameraCommandDefinition& definition) const
{
    if (definition.key == QStringLiteral("TIME_SET_BEIJING")) {
        const QDateTime now = QDateTime::currentDateTime();
        return now.toString(QStringLiteral("yyyyMMddhhmmss"));
    }
    if (definition.key == QStringLiteral("TIME_SET_UTC")) {
        const QDateTime nowUtc = QDateTime::currentDateTimeUtc();
        return nowUtc.toString(QStringLiteral("hhmmssddMMyy"));
    }
    return definition.defaultData;
}

void CameraController::_appendLog(const QString& line)
{
    _logEntries.append(QStringLiteral("%1 %2")
                       .arg(QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")))
                       .arg(line));
    while (_logEntries.size() > MAX_LOG_ENTRIES) {
        _logEntries.removeFirst();
    }
    emit logChanged();
}

void CameraController::_rebuildCatalog()
{
    QVariantList categories;
    QStringList order;

    for (const CameraCommandDefinition& def : _definitions) {
        if (!order.contains(def.category)) {
            order.append(def.category);
        }
    }

    for (const QString& category : order) {
        QVariantList commands;
        for (const CameraCommandDefinition& def : _definitions) {
            if (def.category == category) {
                commands.append(cameraCommandDefinitionToVariant(def));
            }
        }
        QVariantMap entry;
        entry.insert(QStringLiteral("name"), category);
        entry.insert(QStringLiteral("commands"), commands);
        categories.append(entry);
    }

    _commandCatalog = categories;
    emit commandCatalogChanged();
}
