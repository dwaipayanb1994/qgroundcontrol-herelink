#include <QtQml>
#include <QQmlEngine>
#include <QDateTime>
#include "QGCSettings.h"
#include "MAVLinkLogManager.h"

#include "CustomPlugin.h"

#include "QGCApplication.h"
#include "SettingsManager.h"
#include "AppMessages.h"
#include "QmlComponentInfo.h"
#include "QGCPalette.h"

#include <cstring>

QGC_LOGGING_CATEGORY(CameraControl, "CameraControl")

constexpr ushort VALUE_IGNORE_CHANNEL = 0xFFFF;
constexpr ushort VALUE_RELEASE_CHANNEL_1_TO_8 = 0;
constexpr ushort VALUE_RELEASE_CHANNEL_9_TO_18 = 0xFFFF-1;

CustomOptions::CustomOptions(CustomPlugin*, QObject* parent) : QGCOptions(parent)
{
}

//-----------------------------------------------------------------------------
CustomPlugin::CustomPlugin(QGCApplication *app, QGCToolbox* toolbox) : QGCCorePlugin(app, toolbox)
{          
    for(int i = 0; i < MAX_CHANNELS_COUNT; i++)
    {
        _channels[i] = VALUE_IGNORE_CHANNEL;
    }

    _timerId = 0;

    _pOptions = new CustomOptions(this, this);

    // Load settings (setNbCameras, ...) before connecting signals
    loadSetting();

    connect(this, &CustomPlugin::nbCamerasChanged, this, &CustomPlugin::onSettingsChanged);
    connect(this, &CustomPlugin::targetSystemIdChanged, this, &CustomPlugin::onSettingsChanged);
    connect(this, &CustomPlugin::targetComponentIdChanged, this, &CustomPlugin::onSettingsChanged);

    connect(qApp, &QGCApplication::aboutToQuit, this, [this]()
    {
       // TODO: set only channels that are configured
       for(int i = 0; i < MAX_CHANNELS_COUNT; i++)
           _channels[i] = i < 9 ? VALUE_RELEASE_CHANNEL_1_TO_8 : VALUE_RELEASE_CHANNEL_9_TO_18;

       updateRCChannels();
    });
}

QGCOptions* CustomPlugin::options()
{
    return _pOptions;
}

QQmlApplicationEngine* CustomPlugin::createRootWindow(QObject *parent)
{
    QQmlApplicationEngine* pEngine = new QQmlApplicationEngine(parent);
    pEngine->addImportPath("qrc:/qml");
    pEngine->rootContext()->setContextProperty("joystickManager", qgcApp()->toolbox()->joystickManager());
    pEngine->rootContext()->setContextProperty("debugMessageModel", AppMessages::getModel());
    pEngine->rootContext()->setContextProperty("customPlugin", this);
    pEngine->load(QUrl(QStringLiteral("qrc:/qml/MainRootWindow.qml")));
    return pEngine;
}

QVariantList &CustomPlugin::settingsPages()
{
    // Override settings page to add our Cemara Controls setting section
    if(_customSettingsList.isEmpty())
    {
        _customSettingsList = QGCCorePlugin::settingsPages();

        _customSettingsList << QVariant::fromValue(new QmlComponentInfo("Camera Control",
                                           QUrl::fromUserInput("qrc:/custom/CameraControlSettings.qml"),
                                           QUrl(),
                                           this));
    }

    return _customSettingsList;
}

void CustomPlugin::onSettingsChanged()
{
    // If camera count changes, we should start/stop timer to not waist resources.
    if(_timerId == 0 && _nbCameras != 0)
    {
        // No timer is running and there's at least one cam control -> start timer
        _timerId = startTimer(20);
    }
    else if(_timerId != 0 && _nbCameras == 0)
    {
        // No cam control and timer running -> stop timer
         killTimer(_timerId);
         _timerId = 0;
    }

    // Then save settings
    saveSettings();
}

void CustomPlugin::updateRCChannels()
{
    if(_activeVehicle)
    {
        mavlink_message_t msg;

        auto mavlink = qgcApp()->toolbox()->mavlinkProtocol();

        mavlink_msg_rc_channels_override_pack
                (
                    mavlink->getSystemId(),
                    mavlink->getComponentId(),
                    &msg,
                    _targetSysId,
                    _targetCompId,
                    _channels[0],
                    _channels[1],
                    _channels[2],
                    _channels[3],
                    _channels[4],
                    _channels[5],
                    _channels[6],
                    _channels[7],
                    _channels[8],
                    _channels[9],
                    _channels[10],
                    _channels[11],
                    _channels[12],
                    _channels[13],
                    _channels[14],
                    _channels[15],
                    _channels[16],
                    _channels[17]
               );

        _activeVehicle->sendMessageOnLink(_activeVehicle->priorityLink(), msg);
    }
    else
    {
        qDebug() << "CameraControl" << "No Vehicule connected!";
    }
}

void CustomPlugin::loadSetting()
{
    QSettings settings;

    _nbCameras = settings.value("CameraControls/nbCameras", 0).toInt();
    _targetSysId = settings.value("CameraControls/targetSystemId", 1).toInt();
    _targetCompId = settings.value("CameraControls/targetComponentId", 1).toInt();

    // Make sure settings values are correct (incase they get correpted)
    if(_nbCameras < 0 || _nbCameras > MAX_CAMERAS_COUNT)
        _nbCameras = 0;

    if(_targetSysId < 0 || _targetSysId > 255)
        _targetSysId = 1;

    if(_targetCompId < 0 || _targetCompId > 255)
        _targetCompId = 1;

    onSettingsChanged();
}

void CustomPlugin::saveSettings()
{
    QSettings settings;
    settings.beginGroup("CameraControls");
    settings.setValue("nbCameras", _nbCameras);
    settings.setValue("targetSystemId", _targetSysId);
    settings.setValue("targetComponentId", _targetCompId);
    settings.sync();
}

void CustomPlugin::timerEvent(QTimerEvent *event)
{
    updateRCChannels();
}

void CustomPlugin::setChannelValue(int channel, int value)
{
    qDebug().nospace() << "CameraControl CH" << channel << " = " << value;

    if(channel < 5 || channel > 18)
    {
        qDebug() << "CameraControl" << "Error: Channel out of range 5-18!";
        return;
    }

    if((value != 0 && value < 1000) || value > 2000)
    {
        qDebug() << "CameraControl" << "Error:" << value << "is an invalid value!";
        return;
    }

    _channels[channel - 1] = value != 0 ? value : VALUE_IGNORE_CHANNEL;
}
