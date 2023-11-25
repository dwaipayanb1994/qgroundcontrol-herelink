/****************************************************************************
 *
 * (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 *   @brief Custom QGCCorePlugin Declaration
 *   @author Gus Grubba <gus@auterion.com>
 */

#pragma once

#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include "QGCLoggingCategory.h"
#include "VideoReceiver.h"
#include "SettingsManager.h"

#include <QTranslator>

class CustomPlugin;
class CustomSettings;

Q_DECLARE_LOGGING_CATEGORY(CustomLog)

//-----------------------------------------------------------------------------
//-- Our own, custom options
class CustomOptions : public QGCOptions
{
public:
    CustomOptions(CustomPlugin*, QObject* parent = nullptr);
    
    QUrl        flyViewOverlay                  () const final { return QUrl::fromUserInput("qrc:/custom/CustomThicknessReadingFlyView.qml"); }
};


//-----------------------------------------------------------------------------
class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT
public:
    CustomPlugin(QGCApplication* app, QGCToolbox *toolbox);
    ~CustomPlugin();

    // Overrides from QGCCorePlugin
    QGCOptions*             options                         () final;
    QQmlApplicationEngine*  createRootWindow                (QObject* parent) final;

private:
    Q_PROPERTY(bool  isThicknessReadingEnabled READ isThicknessGaugeEnabled CONSTANT)
    Q_PROPERTY(float getThicknessReading READ getThicknessReading WRITE setThicknessReading NOTIFY readingUpdated)
    Q_PROPERTY(int   connectContext READ connectContext)

    bool isThicknessReadingEnabled = true;
    float thicknessReading = 0.0;

    CustomOptions* _pOptions = nullptr;

    Vehicle* activeVehicle = nullptr;

    int connectContext();
    float getThicknessReading();
    void setThicknessReading(float reading);
    bool isThicknessGaugeEnabled();

private slots:
    void onThicknessReadingChange(float);

signals:
    void readingUpdated();
};
