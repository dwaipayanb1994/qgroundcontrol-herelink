#pragma once

#include <QObject>
#include <QHostAddress>
#include <QtSerialPort/QSerialPort>

QT_BEGIN_NAMESPACE
class QUdpSocket;
QT_END_NAMESPACE

class CameraTransport : public QObject
{
    Q_OBJECT
public:
    explicit CameraTransport(QObject* parent = nullptr);
    ~CameraTransport() override;

    bool openSerial(const QString& portName,
                    int baudRate = 115200,
                    QString* outError = nullptr);
    void closeSerial();
    bool sendSerial(const QByteArray& payload, QString* outError = nullptr);
    bool isSerialOpen() const;
    QString serialPortName() const;

    bool configureUdp(const QHostAddress& remoteAddress,
                      quint16 remotePort,
                      quint16 localPort,
                      QString* outError = nullptr);
    void closeUdp();
    bool sendUdp(const QByteArray& payload, QString* outError = nullptr);
    bool isUdpReady() const;
    QHostAddress remoteUdpAddress() const;
    quint16 remoteUdpPort() const;
    quint16 localUdpPort() const;

signals:
    void serialOpened();
    void serialClosed();
    void udpBound();
    void udpClosed();
    void dataReceived(const QByteArray& payload);
    void bytesWritten(qint64 bytes);
    void errorOccurred(const QString& message);

private slots:
    void _onSerialReadyRead();
    void _onSerialError(QSerialPort::SerialPortError error);
    void _onUdpReadyRead();

private:
    void _destroySerial();
    void _destroyUdp();

    QSerialPort* _serial = nullptr;
    QUdpSocket* _udp = nullptr;
    QHostAddress _remoteAddress;
    quint16 _remotePort = 0;
};
