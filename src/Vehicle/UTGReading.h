/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QDateTime>
#include <QGeoCoordinate>
#include <QString>

/// Single UTG thickness reading record
class UTGReading
{
public:
    UTGReading() = default;
    UTGReading(double thickness, const QString& unit);

    double          thickness       = 0.0;
    QString         unit            = QStringLiteral("mm");
    QString         notes;
    double          temperature     = 0.0;
    int             measurementMode = 0;
    double          soundVelocity   = 0.0;
    int             gain            = 0;
    QGeoCoordinate  location;
    QDateTime       timestamp;

    QString toString() const;
};
