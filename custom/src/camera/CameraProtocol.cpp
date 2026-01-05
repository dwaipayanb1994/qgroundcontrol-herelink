#include "CameraProtocol.h"

#include <QtCore/QRegularExpression>

namespace {
static constexpr char DEFAULT_SERIAL_SOURCE = 'U';
static constexpr char DEFAULT_UDP_SOURCE = 'P';
}

QByteArray CameraProtocol::buildFrame(const CameraCommandDefinition& definition,
                                      const QString& dataPayload,
                                      CameraProtocol::TransportSource source,
                                      QString* outError)
{
    const QString header = definition.header.isEmpty() ? QStringLiteral("#tp") : definition.header;
    if (header.size() != 3 || header.at(0) != QLatin1Char('#')) {
        if (outError) {
            *outError = QStringLiteral("Invalid frame header: %1").arg(header);
        }
        return QByteArray();
    }

    const QChar sourceChar = (source == TransportSource::Serial)
            ? (definition.serialSource.isNull() ? QChar(DEFAULT_SERIAL_SOURCE) : definition.serialSource)
            : (definition.udpSource.isNull() ? QChar(DEFAULT_UDP_SOURCE) : definition.udpSource);

    if (definition.destination.isNull()) {
        if (outError) {
            *outError = QStringLiteral("Destination address not specified for command %1").arg(definition.key);
        }
        return QByteArray();
    }

    QByteArray frame;
    frame.reserve(64);
    frame.append(header.toLatin1());
    frame.append(sourceChar.toLatin1());
    frame.append(definition.destination.toLatin1());

    QByteArray dataBytes;
    if (!buildDataBytes(definition, dataPayload, dataBytes, outError)) {
        return QByteArray();
    }

    const int dataLength = dataBytes.size();
    if (!appendLengthField(frame, dataLength, definition.lengthFieldWidth, outError)) {
        return QByteArray();
    }

    if (definition.control.isNull()) {
        if (outError) {
            *outError = QStringLiteral("Control byte missing for command %1").arg(definition.key);
        }
        return QByteArray();
    }
    frame.append(definition.control.toLatin1());

    if (definition.identifier.size() != 3) {
        if (outError) {
            *outError = QStringLiteral("Identifier for %1 must be three characters").arg(definition.key);
        }
        return QByteArray();
    }
    frame.append(definition.identifier.toLatin1());

    frame.append(dataBytes);

    const QString crc = computeCrc(frame);
    frame.append(crc.toLatin1());
    return frame;
}

bool CameraProtocol::appendLengthField(QByteArray& frame,
                                       int dataLength,
                                       int lengthFieldWidth,
                                       QString* outError)
{
    if (lengthFieldWidth <= 0) {
        lengthFieldWidth = 1;
    }

    QString lengthString = QString::number(dataLength, 16).toUpper();
    if (lengthString.size() > lengthFieldWidth) {
        if (outError) {
            *outError = QStringLiteral("Data length %1 exceeds field width %2").arg(dataLength).arg(lengthFieldWidth);
        }
        return false;
    }
    lengthString = lengthString.rightJustified(lengthFieldWidth, QLatin1Char('0'));
    frame.append(lengthString.toLatin1());
    return true;
}

bool CameraProtocol::buildDataBytes(const CameraCommandDefinition& definition,
                                    const QString& dataPayload,
                                    QByteArray& outData,
                                    QString* outError)
{
    QString payload = dataPayload;
    if (payload.isEmpty()) {
        payload = definition.defaultData;
    }

    if (payload.isEmpty()) {
        if (!definition.allowEmptyData) {
            if (outError) {
                *outError = QStringLiteral("Command %1 requires data").arg(definition.key);
            }
            return false;
        }
        outData.clear();
        return true;
    }

    if (!definition.dataIsHexPayload) {
        outData = payload.toLatin1();
        return true;
    }

    QString sanitized = payload;
    sanitized.remove(QLatin1Char(' '));
    sanitized.remove(QLatin1Char('-'));
    sanitized.remove(QLatin1Char(':'));

    if (sanitized.size() % 2 != 0) {
        if (outError) {
            *outError = QStringLiteral("Hex payload for %1 must contain an even number of digits").arg(definition.key);
        }
        return false;
    }

    outData.clear();
    outData.reserve(sanitized.size() / 2);
    for (int i = 0; i < sanitized.size(); i += 2) {
        bool ok = false;
        const QStringRef byteStr(&sanitized, i, 2);
        int value = byteStr.toInt(&ok, 16);
        if (!ok) {
            if (outError) {
                *outError = QStringLiteral("Invalid hex value '%1' for command %2").arg(byteStr.toString(), definition.key);
            }
            outData.clear();
            return false;
        }
        outData.append(static_cast<char>(value & 0xFF));
    }

    return true;
}

QString CameraProtocol::computeCrc(const QByteArray& frameWithoutCrc)
{
    quint32 sum = 0;
    for (unsigned char byte : frameWithoutCrc) {
        sum += byte;
    }
    const quint8 crc = static_cast<quint8>(sum & 0xFF);
    return QStringLiteral("%1").arg(crc, 2, 16, QLatin1Char('0')).toUpper();
}
