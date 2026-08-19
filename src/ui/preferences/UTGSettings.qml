/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Controls 2.12

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.Palette   1.0
import QGroundControl.ScreenTools 1.0

/// Application settings page for UTG (Herelink MAVLink path — no direct serial config)
Rectangle {
    id:     root
    color:  qgcPal.window
    anchors.fill: parent

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        anchors.fill:       parent
        anchors.margins:    ScreenTools.defaultFontPixelWidth
        contentHeight:      settingsPanel.height
        contentWidth:       width

        UTGSettingsPanel {
            id:             settingsPanel
            width:          parent.width
        }
    }
}
