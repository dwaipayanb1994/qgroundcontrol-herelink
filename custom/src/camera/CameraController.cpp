#include "CameraController.h"

#include <QDateTime>
#include <QDebug>
#include <QHostAddress>
#include <QVariantMap>

#include "AppMessages.h"
#include "CameraCommandRegistry.h"
#include "CameraTransport.h"

namespace {
static constexpr int MAX_LOG_ENTRIES = 200;

void cameraWarn(const QString& message)
{
    const QString fullMessage = QStringLiteral("[CameraController] %1").arg(message);
    qWarning().noquote() << fullMessage;
    AppLogModel::log(fullMessage);
}
} // namespace

CameraController::CameraController(QObject* parent)
    : QObject(parent)
    , _transport(new CameraTransport(this))
{
    _definitions = CameraCommandRegistry::all();
    cameraWarn(QStringLiteral("Constructed with %1 command definitions").arg(_definitions.size()));
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
    const TransportMode newMode = static_cast<TransportMode>(mode);
    if (_transportMode == newMode) {
        return;
    }
    _transportMode = newMode;
    cameraWarn(QStringLiteral("Transport mode changed -> %1").arg(mode));
    emit activeTransportModeChanged(mode);
}

bool CameraController::connectSerial(const QString& portName, int baudRate)
{
    cameraWarn(QStringLiteral("Attempting serial connect %1 @ %2").arg(portName, QString::number(baudRate)));

    QString error;
    if (!_transport->openSerial(portName, baudRate, &error)) {
        _lastError = error;
        cameraWarn(QStringLiteral("Serial connect failed: %1").arg(error));
        emit errorOccurred(_lastError);
        return false;
    }

    emit serialConnectionChanged(true);
    _appendLog(tr("[Serial] Connected to %1 @ %2").arg(portName).arg(baudRate));
    cameraWarn(QStringLiteral("Serial connected %1").arg(portName));
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
    cameraWarn(QStringLiteral("Serial disconnected %1").arg(port));
}

bool CameraController::configureUdp(const QString& deviceIp,
                                    quint16 devicePort,
                                    quint16 localPort)
{
    cameraWarn(QStringLiteral("Configuring UDP device=%1:%2 local=%3")
               .arg(deviceIp)
               .arg(devicePort)
               .arg(localPort));

    QHostAddress address(deviceIp);
    if (address.isNull()) {
        _lastError = tr("Invalid device IP address: %1").arg(deviceIp);
        cameraWarn(QStringLiteral("UDP configuration failed: %1").arg(_lastError));
        emit errorOccurred(_lastError);
        return false;
    }

    QString error;
    if (!_transport->configureUdp(address, devicePort, localPort, &error)) {
        _lastError = error;
        cameraWarn(QStringLiteral("UDP configure failed: %1").arg(error));
        emit errorOccurred(_lastError);
        return false;
    }

    emit udpConnectionChanged(true);
    const QString remoteAddress = address.toString();
    _appendLog(tr("[UDP] Bound to %1 (local %2) -> remote %3:%4")
               .arg(remoteAddress)
               .arg(localPort)
               .arg(remoteAddress)
               .arg(devicePort));
    cameraWarn(QStringLiteral("UDP configured remote=%1:%2 local=%3")
               .arg(remoteAddress)
               .arg(devicePort)
               .arg(localPort));
    return true;
}

void CameraController::disconnectUdp()
{
    if (!udpConnected()) {
        return;
    }
    const quint16 localPort = _transport->localUdpPort();
    _transport->closeUdp();
    emit udpConnectionChanged(false);
    _appendLog(tr("[UDP] Socket on %1 closed").arg(localPort));
    cameraWarn(QStringLiteral("UDP socket closed %1").arg(localPort));
}

bool CameraController::sendCommand(const QString& key,
                                   const QString& dataOverride)
{
    if (dataOverride.isEmpty()) {
        return sendCommandWithParameters(key, QVariantMap());
    }
    return sendCommandWithParameters(key, {{ QStringLiteral("data"), dataOverride }});
}

bool CameraController::sendCommandWithParameters(const QString& key,
                                                 const QVariantMap& parameters)
{
    const CameraCommandDefinition* definition = _definitionForKey(key);
    if (!definition) {
        _lastError = tr("Unknown command key: %1").arg(key);
        cameraWarn(QStringLiteral("Unknown command key %1").arg(key));
        emit errorOccurred(_lastError);
        return false;
    }

    QString explicitData;
    if (parameters.contains(QStringLiteral("data"))) {
        explicitData = parameters.value(QStringLiteral("data")).toString();
    }

    const QString resolvedData = _resolveDataForCommand(*definition, explicitData, parameters);
    cameraWarn(QStringLiteral("Preparing command %1 explicit=%2 resolved=%3")
               .arg(key, explicitData, resolvedData));

    QString error;
    CameraProtocol::TransportSource source = CameraProtocol::TransportSource::Serial;
    QString transportLabel = tr("Serial");

    switch (_transportMode) {
    case Auto:
        if (udpConnected()) {
            source = CameraProtocol::TransportSource::Udp;
            transportLabel = tr("UDP");
        } else if (serialConnected()) {
            source = CameraProtocol::TransportSource::Serial;
            transportLabel = tr("Serial");
        } else {
            error = tr("No transport configured for sending commands");
        }
        break;
    case SerialOnly:
        if (!serialConnected()) {
            error = tr("Serial transport not connected");
        }
        source = CameraProtocol::TransportSource::Serial;
        transportLabel = tr("Serial");
        break;
    case UdpOnly:
        if (!udpConnected()) {
            error = tr("UDP transport not configured");
        }
        source = CameraProtocol::TransportSource::Udp;
        transportLabel = tr("UDP");
        break;
    }

    if (!error.isEmpty()) {
        _lastError = error;
        cameraWarn(QStringLiteral("Transport unavailable: %1").arg(error));
        emit errorOccurred(_lastError);
        return false;
    }

    const QByteArray frame = CameraProtocol::buildFrame(*definition, resolvedData, source, &error);
    if (frame.isEmpty()) {
        _lastError = error.isEmpty() ? tr("Failed to build frame for %1").arg(key) : error;
        cameraWarn(QStringLiteral("Frame build failed for %1: %2").arg(key, _lastError));
        emit errorOccurred(_lastError);
        return false;
    }

    const QString preview = QString::fromLatin1(frame.toHex(' ')).toUpper();
    _lastFrame = preview;
    emit lastFrameChanged(_lastFrame);
    cameraWarn(QStringLiteral("Built frame %1 -> %2").arg(key, preview));

    bool success = false;
    if (source == CameraProtocol::TransportSource::Serial) {
        success = _transport->sendSerial(frame, &error);
    } else {
        success = _transport->sendUdp(frame, &error);
    }

    if (!success) {
        _lastError = error;
        cameraWarn(QStringLiteral("Transport send failed for %1: %2").arg(key, error));
        emit errorOccurred(_lastError);
        return false;
    }

    _appendLog(tr("[TX][%1] %2").arg(transportLabel, preview));
    cameraWarn(QStringLiteral("Command %1 sent via %2").arg(key, transportLabel));
    return true;
}

QString CameraController::previewCommand(const QString& key,
                                         const QString& dataOverride) const
{
    const CameraCommandDefinition* definition = _definitionForKey(key);
    if (!definition) {
        return QString();
    }

    CameraProtocol::TransportSource source = CameraProtocol::TransportSource::Serial;
    if (_transportMode == UdpOnly || (_transportMode == Auto && udpConnected())) {
        source = CameraProtocol::TransportSource::Udp;
    }

    const QString payload = dataOverride.isEmpty()
            ? _resolveDataForCommand(*definition, QString(), QVariantMap())
            : dataOverride;

    QString error;
    const QByteArray frame = CameraProtocol::buildFrame(*definition, payload, source, &error);
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
    cameraWarn(QStringLiteral("Traffic log cleared"));
}

void CameraController::_handleTransportData(const QByteArray& payload)
{
    cameraWarn(QStringLiteral("RX payload %1 bytes").arg(payload.size()));
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
    cameraWarn(QStringLiteral("Transport error: %1").arg(message));
}

const CameraCommandDefinition* CameraController::_definitionForKey(const QString& key) const
{
    for (const CameraCommandDefinition& def : _definitions) {
        if (def.key == key) {
            return &def;
        }
    }
    cameraWarn(QStringLiteral("Definition lookup failed for %1").arg(key));
    return nullptr;
}

QString CameraController::_resolveDataForCommand(const CameraCommandDefinition& definition,
                                                 const QString& explicitData,
                                                 const QVariantMap& parameters) const
{
    if (!explicitData.isEmpty()) {
        return explicitData;
    }

    if (parameters.contains(QStringLiteral("optionData"))) {
        const QString optionData = parameters.value(QStringLiteral("optionData")).toString();
        if (!optionData.isEmpty()) {
            return optionData;
        }
    }

    if (parameters.contains(QStringLiteral("data"))) {
        const QString parameterData = parameters.value(QStringLiteral("data")).toString();
        if (!parameterData.isEmpty()) {
            return parameterData;
        }
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
        cameraWarn(QStringLiteral("Category %1 commands=%2").arg(category).arg(commands.size()));
    }

    _commandCatalog = categories;
    emit commandCatalogChanged();
    cameraWarn(QStringLiteral("Catalog rebuilt with %1 categories").arg(_commandCatalog.size()));
}
