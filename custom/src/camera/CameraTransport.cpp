#include "CameraTransport.h"

#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>
#include <QtNetwork/QUdpSocket>
#include <QtNetwork/QAbstractSocket>

#include <QDebug>

CameraTransport::CameraTransport(QObject* parent)
    : QObject(parent)
{
}

CameraTransport::~CameraTransport()
{
    closeSerial();
    closeUdp();
}

bool CameraTransport::openSerial(const QString& portName,
                                 int baudRate,
                                 QString* outError)
{
    if (portName.isEmpty()) {
        if (outError) {
            *outError = tr("Serial port name cannot be empty");
        }
        return false;
    }

    if (!_serial) {
        _serial = new QSerialPort(this);
        connect(_serial, &QSerialPort::readyRead, this, &CameraTransport::_onSerialReadyRead);
    #if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
        connect(_serial, &QSerialPort::errorOccurred, this, &CameraTransport::_onSerialError);
    #else
        connect(_serial,
                QOverload<QSerialPort::SerialPortError>::of(&QSerialPort::error),
                this,
                &CameraTransport::_onSerialError);
    #endif
    }

    if (_serial->isOpen()) {
        if (_serial->portName() == portName && _serial->baudRate() == baudRate) {
            return true;
        }
        _serial->close();
    }

    _serial->setPortName(portName);
    _serial->setBaudRate(baudRate);
    _serial->setDataBits(QSerialPort::Data8);
    _serial->setStopBits(QSerialPort::OneStop);
    _serial->setParity(QSerialPort::NoParity);
    _serial->setFlowControl(QSerialPort::NoFlowControl);

    if (!_serial->open(QIODevice::ReadWrite)) {
        if (outError) {
            *outError = tr("Failed to open %1: %2").arg(portName, _serial->errorString());
        }
        _serial->deleteLater();
        _serial = nullptr;
        return false;
    }

    emit serialOpened();
    return true;
}

void CameraTransport::closeSerial()
{
    if (_serial) {
        if (_serial->isOpen()) {
            _serial->close();
            emit serialClosed();
        }
        _serial->deleteLater();
        _serial = nullptr;
    }
}

bool CameraTransport::sendSerial(const QByteArray& payload, QString* outError)
{
    if (!_serial || !_serial->isOpen()) {
        if (outError) {
            *outError = tr("Serial port is not open");
        }
        return false;
    }

    const qint64 written = _serial->write(payload);
    if (written != payload.size()) {
        if (outError) {
            *outError = tr("Only %1 of %2 bytes written to serial port").arg(written).arg(payload.size());
        }
        return false;
    }
    emit bytesWritten(written);
    return true;
}

bool CameraTransport::isSerialOpen() const
{
    return _serial && _serial->isOpen();
}

QString CameraTransport::serialPortName() const
{
    return _serial ? _serial->portName() : QString();
}

bool CameraTransport::configureUdp(const QHostAddress& remoteAddress,
                                   quint16 remotePort,
                                   quint16 localPort,
                                   QString* outError)
{
    if (remoteAddress.isNull() || remotePort == 0) {
        if (outError) {
            *outError = tr("Invalid remote UDP endpoint");
        }
        return false;
    }

    if (!_udp) {
        _udp = new QUdpSocket(this);
        connect(_udp, &QUdpSocket::readyRead, this, &CameraTransport::_onUdpReadyRead);
    } else {
        _udp->close();
    }

    QAbstractSocket::BindMode bindMode = QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint;
    if (!_udp->bind(QHostAddress::AnyIPv4, localPort, bindMode)) {
        if (outError) {
            *outError = tr("Failed to bind UDP socket on port %1: %2").arg(localPort).arg(_udp->errorString());
        }
        _udp->deleteLater();
        _udp = nullptr;
        return false;
    }

    _remoteAddress = remoteAddress;
    _remotePort = remotePort;
    emit udpBound();
    return true;
}

void CameraTransport::closeUdp()
{
    if (_udp) {
        _udp->close();
        emit udpClosed();
        _udp->deleteLater();
        _udp = nullptr;
    }
}

bool CameraTransport::sendUdp(const QByteArray& payload, QString* outError)
{
    if (!_udp) {
        if (outError) {
            *outError = tr("UDP socket is not configured");
        }
        return false;
    }
    if (_remoteAddress.isNull() || _remotePort == 0) {
        if (outError) {
            *outError = tr("Remote UDP endpoint not set");
        }
        return false;
    }

    const qint64 written = _udp->writeDatagram(payload, _remoteAddress, _remotePort);
    if (written != payload.size()) {
        if (outError) {
            *outError = tr("Only %1 of %2 bytes written to UDP socket").arg(written).arg(payload.size());
        }
        return false;
    }
    emit bytesWritten(written);
    return true;
}

bool CameraTransport::isUdpReady() const
{
    return _udp && _udp->state() == QAbstractSocket::BoundState;
}

QHostAddress CameraTransport::remoteUdpAddress() const
{
    return _remoteAddress;
}

quint16 CameraTransport::remoteUdpPort() const
{
    return _remotePort;
}

quint16 CameraTransport::localUdpPort() const
{
    return _udp ? _udp->localPort() : 0;
}

void CameraTransport::_onSerialReadyRead()
{
    if (!_serial) {
        return;
    }
    const QByteArray payload = _serial->readAll();
    if (!payload.isEmpty()) {
        emit dataReceived(payload);
    }
}

void CameraTransport::_onSerialError(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::NoError) {
        return;
    }

    if (_serial) {
        emit errorOccurred(tr("Serial error on %1: %2").arg(_serial->portName(), _serial->errorString()));
    } else {
        emit errorOccurred(tr("Serial error: %1").arg(int(error)));
    }
}

void CameraTransport::_onUdpReadyRead()
{
    if (!_udp) {
        return;
    }
    while (_udp->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(int(_udp->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort = 0;
        _udp->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);
        Q_UNUSED(sender)
        Q_UNUSED(senderPort)
        if (!datagram.isEmpty()) {
            emit dataReceived(datagram);
        }
    }
}
