#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QDateTime>

#include "CameraCommandDefinition.h"
#include "CameraProtocol.h"

class CameraTransport;

class CameraController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool serialConnected READ serialConnected NOTIFY serialConnectionChanged)
    Q_PROPERTY(bool udpConnected READ udpConnected NOTIFY udpConnectionChanged)
    Q_PROPERTY(int activeTransportMode READ activeTransportMode WRITE setActiveTransportMode NOTIFY activeTransportModeChanged)
    Q_PROPERTY(QVariantList commandCatalog READ commandCatalog NOTIFY commandCatalogChanged)
    Q_PROPERTY(QStringList logEntries READ logEntries NOTIFY logChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorOccurred)
    Q_PROPERTY(QString lastFrame READ lastFrame NOTIFY lastFrameChanged)

public:
    enum TransportMode {
        Auto = 0,
        SerialOnly,
        UdpOnly
    };
    Q_ENUM(TransportMode)

    explicit CameraController(QObject* parent = nullptr);
    ~CameraController() override;

    bool serialConnected() const;
    bool udpConnected() const;

    int activeTransportMode() const;
    void setActiveTransportMode(int mode);

    QVariantList commandCatalog() const { return _commandCatalog; }
    QStringList logEntries() const { return _logEntries; }
    QString lastError() const { return _lastError; }
    QString lastFrame() const { return _lastFrame; }

    Q_INVOKABLE bool connectSerial(const QString& portName, int baudRate = 115200);
    Q_INVOKABLE void disconnectSerial();
    Q_INVOKABLE bool configureUdp(const QString& deviceIp, quint16 devicePort, quint16 localPort = 9004);
    Q_INVOKABLE void disconnectUdp();

    Q_INVOKABLE bool sendCommand(const QString& key,
                                 const QString& dataOverride = QString());
    Q_INVOKABLE bool sendCommandWithParameters(const QString& key,
                                               const QVariantMap& parameters);
    Q_INVOKABLE QString previewCommand(const QString& key,
                                       const QString& dataOverride = QString()) const;
    Q_INVOKABLE void clearLog();

signals:
    void serialConnectionChanged(bool connected);
    void udpConnectionChanged(bool connected);
    void activeTransportModeChanged(int mode);
    void commandCatalogChanged();
    void logChanged();
    void errorOccurred(const QString& message);
    void lastFrameChanged(const QString& frame);

private slots:
    void _handleTransportData(const QByteArray& payload);
    void _handleTransportError(const QString& message);

private:
    const CameraCommandDefinition* _definitionForKey(const QString& key) const;
    QString _resolveDataForCommand(const CameraCommandDefinition& definition,
                                   const QString& explicitData,
                                   const QVariantMap& parameters) const;
    QString _generateAutoData(const CameraCommandDefinition& definition) const;
    void _appendLog(const QString& line);
    void _rebuildCatalog();

    CameraTransport* _transport;
    TransportMode _transportMode = Auto;

    QVector<CameraCommandDefinition> _definitions;
    QVariantList _commandCatalog;
    QStringList _logEntries;
    QString _lastError;
    QString _lastFrame;
};
