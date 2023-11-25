/****************************************************************************
 *
 * (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 *   @brief Custom QGCCorePlugin Implementation
 *   @author Gus Grubba <gus@auterion.com>
 */

#include <QtQml>
#include <QQmlEngine>
#include <QDateTime>
#include "QGCSettings.h"
#include "MAVLinkLogManager.h"

#include "CustomPlugin.h"
//#include "CustomQuickInterface.h"

#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "SettingsManager.h"
#include "AppMessages.h"
#include "QmlComponentInfo.h"
#include "QGCPalette.h"

QGC_LOGGING_CATEGORY(CustomLog, "CustomLog")

//-----------------------------------------------------------------------------
CustomOptions::CustomOptions(CustomPlugin*, QObject* parent)
    : QGCOptions(parent)
{
}

//-----------------------------------------------------------------------------
CustomPlugin::CustomPlugin(QGCApplication *app, QGCToolbox* toolbox)
    : QGCCorePlugin(app, toolbox)
{
    _pOptions = new CustomOptions(this, this);
}

//-----------------------------------------------------------------------------
CustomPlugin::~CustomPlugin()
{
}

int CustomPlugin::connectContext()
{
    activeVehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    connect(activeVehicle, &Vehicle::thicknessReadingChanged, this, &CustomPlugin::onThicknessReadingChange);
    return 0;
}

void CustomPlugin::onThicknessReadingChange(float thicknessReading)
{
    setThicknessReading(thicknessReading);
}

float CustomPlugin::getThicknessReading()
{
    return thicknessReading;
}

void CustomPlugin::setThicknessReading(float reading)
{
    thicknessReading = reading;
    emit readingUpdated();
}

bool CustomPlugin::isThicknessGaugeEnabled()
{
    return isThicknessReadingEnabled;
}

//-----------------------------------------------------------------------------
QGCOptions*
CustomPlugin::options()
{
    return _pOptions;
}

//-----------------------------------------------------------------------------
QQmlApplicationEngine*
CustomPlugin::createRootWindow(QObject *parent)
{
    QQmlApplicationEngine* pEngine = new QQmlApplicationEngine(parent);
    pEngine->addImportPath("qrc:/qml");
    pEngine->addImportPath("qrc:/Custom/Widgets");
    pEngine->rootContext()->setContextProperty("joystickManager",   qgcApp()->toolbox()->joystickManager());
    pEngine->rootContext()->setContextProperty("debugMessageModel", AppMessages::getModel());
    pEngine->rootContext()->setContextProperty("customPlugin", this);
    pEngine->load(QUrl(QStringLiteral("qrc:/qml/MainRootWindow.qml")));
    return pEngine;
}
