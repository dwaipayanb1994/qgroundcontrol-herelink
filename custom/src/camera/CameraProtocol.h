#pragma once

#include <QObject>
#include <QByteArray>

#include "CameraCommandDefinition.h"

class CameraProtocol
{
public:
    enum class TransportSource {
        Serial,
        Udp
    };

    /// Builds a frame for the given command definition and data payload.
    /// @param definition Command metadata
    /// @param dataPayload Data string provided by the caller. For ASCII commands this is appended as-is.
    ///        For hex-payload commands, the string is interpreted as hexadecimal byte pairs.
    /// @param source Indicates whether the command is sent via serial (source address U) or UDP (source address P).
    /// @param outError Optional pointer to receive validation error messages.
    /// @return Fully formatted frame ready to send, or empty QByteArray on failure.
    static QByteArray buildFrame(const CameraCommandDefinition& definition,
                                 const QString& dataPayload,
                                 TransportSource source,
                                 QString* outError = nullptr);

private:
    static bool appendLengthField(QByteArray& frame,
                                  int dataLength,
                                  int lengthFieldWidth,
                                  QString* outError);
    static bool buildDataBytes(const CameraCommandDefinition& definition,
                               const QString& dataPayload,
                               QByteArray& outData,
                               QString* outError);
    static QString computeCrc(const QByteArray& frameWithoutCrc);
};
