#pragma once

#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"

class CustomPlugin;
class CustomSettings;

constexpr int MAX_CAMERAS_COUNT = 2;
constexpr int MAX_CHANNELS_COUNT = 18;

Q_DECLARE_LOGGING_CATEGORY(CameraControl)

//-----------------------------------------------------------------------------
//-- Our own, custom options
class CustomOptions : public QGCOptions
{
public:
    CustomOptions(CustomPlugin*, QObject* parent = nullptr);
    QUrl flyViewOverlay() const final { return QUrl::fromUserInput("qrc:/custom/CameraControlFlyView.qml"); }
};

//-----------------------------------------------------------------------------
class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    Q_PROPERTY(int maxCameras READ maxCameras CONSTANT)
    Q_PROPERTY(int nbCameras READ nbCameras WRITE setNbCameras NOTIFY nbCamerasChanged)
    Q_PROPERTY(int targetSystemId READ targetSystemId WRITE setTargetSystemId NOTIFY targetSystemIdChanged)
    Q_PROPERTY(int targetComponentId READ targetComponentId WRITE setTargetComponentId NOTIFY targetComponentIdChanged)

    CustomPlugin(QGCApplication* app, QGCToolbox *toolbox);

    int maxCameras() const {return MAX_CAMERAS_COUNT;}
    int nbCameras() const {return _nbCameras;}
    int targetSystemId() const {return _targetSysId;}
    int targetComponentId() const {return _targetCompId;}

    void setNbCameras(int nbCameras) {_nbCameras = nbCameras; emit nbCamerasChanged(nbCameras); }
    void setTargetSystemId(int targetSystemId) {_targetSysId = targetSystemId; emit targetSystemIdChanged(targetSystemId); }
    void setTargetComponentId(int targetComponentId) {_targetCompId = targetComponentId; emit targetComponentIdChanged(targetComponentId);}

    /**
     * @brief Overrides the channel RAW value.
     * @param channel
     * @param value 0 means ignore this channel value.
     */
    Q_INVOKABLE void setChannelValue(int channel, int value);

    // Overrides from QGCCorePlugin
    QGCOptions*             options() final;
    QQmlApplicationEngine*  createRootWindow(QObject* parent) final;
    QVariantList&           settingsPages() override;

protected:
    void timerEvent(QTimerEvent *event) override;

signals:
    void nbCamerasChanged(int);
    void targetSystemIdChanged(int);
    void targetComponentIdChanged(int);

private slots:
    void onSettingsChanged();

private:
    void updateRCChannels();
    void loadSetting();
    void saveSettings();

private:
    QVariantList   _customSettingsList;

    int _nbCameras, _targetSysId, _targetCompId;
    int _channels[MAX_CHANNELS_COUNT];
    int _timerId;

    CustomOptions* _pOptions = nullptr;


};
