#pragma once

#include <QVector>
#include <QString>

#include "CameraCommandDefinition.h"

class CameraCommandRegistry
{
public:
    static const QVector<CameraCommandDefinition>& all();
    static const CameraCommandDefinition* find(const QString& key);
};
