/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UTGReading.h"

UTGReading::UTGReading(double thickness, const QString& unit)
    : thickness(thickness)
    , unit(unit)
    , timestamp(QDateTime::currentDateTime())
{
}

QString UTGReading::toString() const
{
    return QStringLiteral("%1 %2 @ %3")
            .arg(thickness, 0, 'f', 2)
            .arg(unit)
            .arg(timestamp.toString(Qt::ISODate));
}
