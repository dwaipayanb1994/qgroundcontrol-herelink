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
#include "QGCPalette.h"

class CustomPlugin;

//-----------------------------------------------------------------------------
class CustomOptions : public QGCOptions
{
public:
    CustomOptions(CustomPlugin*, QObject* parent = nullptr);
    QUrl        flyViewOverlay                  () const final { return QUrl::fromUserInput("qrc:/custom/CustomThicknessReadingFlyView.qml"); }
    QColor      toolbarBackgroundLight          () const final;
    QColor      toolbarBackgroundDark           () const final;
};

//-----------------------------------------------------------------------------
class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    CustomPlugin(QGCApplication* app, QGCToolbox *toolbox);
    ~CustomPlugin();

    QGCOptions*             options                         () final;
    QQmlApplicationEngine*  createRootWindow                (QObject* parent) final;
    void                    paletteOverride                 (QString colorName, QGCPalette::PaletteColorInfo_t& colorInfo) final;
    QVariantList&           settingsPages                   () final;

    const static QColor     _windowShadeEnabledLightColor;
    const static QColor     _windowShadeEnabledDarkColor;

private:
    CustomOptions* _pOptions = nullptr;
    QVariantList   _customSettingsList;
};
