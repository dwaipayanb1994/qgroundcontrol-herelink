#include "CameraCommandRegistry.h"

#include <QObject>

namespace {

CameraCommandDefinition makeCommand(const QString& key,
                                    const QString& category,
                                    const QString& label,
                                    const QString& identifier,
                                    const QString& defaultData,
                                    QChar destination,
                                    QChar control,
                                    const QString& description = QString(),
                                    const QString& header = QStringLiteral("#tp"))
{
    CameraCommandDefinition def;
    def.key = key;
    def.category = category;
    def.label = label;
    def.description = description;
    def.header = header;
    def.destination = destination;
    def.serialSource = QChar('U');
    def.udpSource = QChar('P');
    def.control = control;
    def.identifier = identifier;
    def.defaultData = defaultData;
    def.allowEmptyData = defaultData.isEmpty();
    return def;
}

CameraCommandOption makeOption(const QString& label,
                               const QString& data,
                               const QString& description = QString())
{
    CameraCommandOption option;
    option.label = label;
    option.data = data;
    option.description = description;
    return option;
}

}

const QVector<CameraCommandDefinition>& CameraCommandRegistry::all()
{
    static const QVector<CameraCommandDefinition> s_definitions = []() {
        QVector<CameraCommandDefinition> defs;
        defs.reserve(120);

        const QString lensZoomCategory = QObject::tr("Lens · Zoom & Focus");
        const QString lensModeCategory = QObject::tr("Lens · Modes & Info");
        const QString gimbalBasicCategory = QObject::tr("Gimbal · Basic Motion");
        const QString gimbalSpeedCategory = QObject::tr("Gimbal · Speed Control");
        const QString gimbalAngleCategory = QObject::tr("Gimbal · Angle Control");
        const QString gimbalStatusCategory = QObject::tr("Gimbal · Status & Toggles");
        const QString videoCaptureCategory = QObject::tr("Video · Capture & Recording");
        const QString videoSettingCategory = QObject::tr("Video · Resolution & Bitrate");
        const QString displayCategory = QObject::tr("Display · PIP & Zoom");
        const QString temperatureCategory = QObject::tr("Imaging · Temperature & Palette");
        const QString storageNetworkCategory = QObject::tr("System · Storage & Network");
        const QString timeGpsCategory = QObject::tr("System · Time & Position");
        const QString laserCategory = QObject::tr("Laser & Range");
        const QString advancedCategory = QObject::tr("Advanced · Raw Frames");

        // --- Lens Zoom & Focus ---
        defs.append(makeCommand("ZOOM_STOP", lensZoomCategory, QObject::tr("Zoom Stop"), "ZMC", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("ZOOM_OUT", lensZoomCategory, QObject::tr("Zoom Out"), "ZMC", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("ZOOM_IN", lensZoomCategory, QObject::tr("Zoom In"), "ZMC", "02", QChar('M'), QChar('w')));

        {
            auto cmd = makeCommand("ZOOM_POSITION_QUERY", lensZoomCategory, QObject::tr("Query Zoom Position"), "ZOM", "00", QChar('M'), QChar('r'), QObject::tr("Reads signed zoom position (two's complement)."));
            defs.append(cmd);
        }

        defs.append(makeCommand("FOCUS_STOP", lensZoomCategory, QObject::tr("Focus Stop"), "FCC", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_NEAR", lensZoomCategory, QObject::tr("Focus +"), "FCC", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_FAR", lensZoomCategory, QObject::tr("Focus -"), "FCC", "02", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_AUTO", lensZoomCategory, QObject::tr("Auto Focus"), "FCC", "10", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_MANUAL", lensZoomCategory, QObject::tr("Manual Focus"), "FCC", "11", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_MANUAL_SAVE", lensZoomCategory, QObject::tr("Manual Focus · Save"), "FCC", "12", QChar('M'), QChar('w')));
        defs.append(makeCommand("FOCUS_AUTO_SAVE", lensZoomCategory, QObject::tr("Auto Focus · Save"), "FCC", "13", QChar('M'), QChar('w')));

        {
            auto cmd = makeCommand("FOCUS_POSITION_QUERY", lensZoomCategory, QObject::tr("Query Focus Position"), "FOC", "00", QChar('M'), QChar('r'), QObject::tr("Reads signed focus position (two's complement)."));
            defs.append(cmd);
        }

        {
            auto cmd = makeCommand("ZOOM_FOCUS_SET", lensZoomCategory, QObject::tr("Set Zoom & Focus Position"), "ZFP", QStringLiteral("NNNNNNNN"), QChar('M'), QChar('w'), QObject::tr("Enter zoom (4 hex chars) followed by focus (4 hex chars). Use NNNN to auto focus."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Example: FFB40032 (zoom=-76, focus=50)");
            defs.append(cmd);
        }

        {
            auto cmd = makeCommand("REMOTE_DEVICE_ACT", lensModeCategory, QObject::tr("Remote Device Activation"), "SWH", QStringLiteral("500"), QChar('M'), QChar('w'), QObject::tr("Control auxiliary peripherals. X0 selects device (5=5V, C=12V), X1 toggles (0=off,1=on)."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: X0X1 (e.g. 51 to enable 5V accessory)");
            defs.append(cmd);
        }

        defs.append(makeCommand("DAY_MODE", lensModeCategory, QObject::tr("Day Mode"), "IRC", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("NIGHT_MODE", lensModeCategory, QObject::tr("Night Mode"), "IRC", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("DAY_NIGHT_TOGGLE", lensModeCategory, QObject::tr("Toggle IR Cut"), "IRC", "0A", QChar('M'), QChar('w')));

        defs.append(makeCommand("ATE_DISABLE", lensModeCategory, QObject::tr("ATE Disable"), "ATE", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("ATE_ENABLE", lensModeCategory, QObject::tr("ATE Enable"), "ATE", "01", QChar('M'), QChar('w')));

        defs.append(makeCommand("LENS_VERSION_QUERY", lensModeCategory, QObject::tr("Query Lens Version"), "VSN", "00", QChar('M'), QChar('r')));

        {
            auto cmd = makeCommand("OPTICAL_MAG_SET", lensModeCategory, QObject::tr("Set Optical Magnification"), "MUL", QStringLiteral("0123"), QChar('M'), QChar('w'), QObject::tr("4 characters, unit 0.1x (e.g. 0123 → 12.3x)."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Enter magnification as four digits (0.1x units)");
            defs.append(cmd);
        }
        defs.append(makeCommand("OPTICAL_MAG_QUERY", lensModeCategory, QObject::tr("Query Optical Magnification"), "MUL", "00", QChar('M'), QChar('r')));

        defs.append(makeCommand("APERTURE_STOP", lensModeCategory, QObject::tr("Aperture Stop"), "APC", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("APERTURE_OPEN", lensModeCategory, QObject::tr("Aperture +"), "APC", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("APERTURE_CLOSE", lensModeCategory, QObject::tr("Aperture -"), "APC", "02", QChar('M'), QChar('w')));

        // --- Gimbal Basic Motion ---
        defs.append(makeCommand("PTZ_STOP", gimbalBasicCategory, QObject::tr("Stop"), "PTZ", "00", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_UP", gimbalBasicCategory, QObject::tr("Up"), "PTZ", "01", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_DOWN", gimbalBasicCategory, QObject::tr("Down"), "PTZ", "02", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_LEFT", gimbalBasicCategory, QObject::tr("Left"), "PTZ", "03", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_RIGHT", gimbalBasicCategory, QObject::tr("Right"), "PTZ", "04", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_HOME", gimbalBasicCategory, QObject::tr("Go Home"), "PTZ", "05", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_LOCK", gimbalBasicCategory, QObject::tr("Lock Mode"), "PTZ", "06", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_FOLLOW", gimbalBasicCategory, QObject::tr("Follow Mode"), "PTZ", "07", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_LOCK_FOLLOW_SWITCH", gimbalBasicCategory, QObject::tr("Lock/Follow Switch"), "PTZ", "08", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("PTZ_CALIBRATE", gimbalBasicCategory, QObject::tr("One-click Calibration"), "PTZ", "0A", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));

        // --- Gimbal Speed Control ---
        {
            auto cmd = makeCommand("GSY_SPEED", gimbalSpeedCategory, QObject::tr("Yaw Speed"), "GSY", QStringLiteral("00"), QChar('G'), QChar('w'), QObject::tr("Signed 8-bit value (hex) ×0.1°/s. Positive=right."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Example: E2 → -30 (left)");
            defs.append(cmd);
        }
        {
            auto cmd = makeCommand("GSP_SPEED", gimbalSpeedCategory, QObject::tr("Pitch Speed"), "GSP", QStringLiteral("00"), QChar('G'), QChar('w'), QObject::tr("Signed 8-bit value (hex) ×0.1°/s. Positive=down."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Example: 1E → +30 (down)");
            defs.append(cmd);
        }
        {
            auto cmd = makeCommand("GSR_SPEED", gimbalSpeedCategory, QObject::tr("Roll Speed"), "GSR", QStringLiteral("00"), QChar('G'), QChar('w'), QObject::tr("Signed 8-bit value (hex) ×0.1°/s."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            defs.append(cmd);
        }
        {
            auto cmd = makeCommand("GSM_SPEED", gimbalSpeedCategory, QObject::tr("Yaw & Pitch Speed"), "GSM", QStringLiteral("0000"), QChar('G'), QChar('w'), QObject::tr("Y0Y1 (yaw) followed by P0P1 (pitch), signed hex."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            defs.append(cmd);
        }
        {
            auto cmd = makeCommand("RPS_SPEED", gimbalSpeedCategory, QObject::tr("Roll & Pitch Speed"), "RPS", QStringLiteral("0000"), QChar('G'), QChar('w'), QObject::tr("R0R1 (roll) + P0P1 (pitch), signed hex."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            defs.append(cmd);
        }
        {
            auto cmd = makeCommand("YPR_SPEED", gimbalSpeedCategory, QObject::tr("Yaw/Pitch/Roll Speed"), "YPR", QStringLiteral("000000"), QChar('G'), QChar('w'), QObject::tr("Y0Y1 + P0P1 + R0R1, signed hex."), QStringLiteral("#TP"));
            cmd.dataEditable = true;
            defs.append(cmd);
        }

        // --- Gimbal Angle Control ---
        auto addAngleCmd = [&](const QString& key, const QString& label, const QString& identifier, const QString& description) {
            CameraCommandDefinition cmd = makeCommand(key, gimbalAngleCategory, label, identifier, QStringLiteral("000000"), QChar('G'), QChar('w'), description);
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: angle×0.01° (signed hex) + speed (00-63)");
            defs.append(cmd);
        };
        addAngleCmd("GAY_SET", QObject::tr("Absolute Yaw Angle"), "GAY", QObject::tr("Yaw relative to aircraft (magnetic encoder)."));
        addAngleCmd("GAP_SET", QObject::tr("Absolute Pitch Angle"), "GAP", QObject::tr("Pitch relative to aircraft."));
        addAngleCmd("GAR_SET", QObject::tr("Absolute Roll Angle"), "GAR", QObject::tr("Roll relative to aircraft."));
        {
            CameraCommandDefinition cmd = makeCommand("GAM_SET", gimbalAngleCategory, QObject::tr("Absolute Yaw & Pitch"), "GAM", QStringLiteral("0000000000"), QChar('G'), QChar('w'), QObject::tr("Yaw angle + speed, then pitch angle + speed."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: Y-angle(4)Y-speed(2)P-angle(4)P-speed(2)");
            defs.append(cmd);
        }

        auto addGyroCmd = [&](const QString& key, const QString& label, const QString& identifier, const QString& description) {
            CameraCommandDefinition cmd = makeCommand(key, gimbalAngleCategory, label, identifier, QStringLiteral("000000"), QChar('G'), QChar('w'), description);
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: angle×0.01° (signed hex) + speed (00-63)");
            defs.append(cmd);
        };
        addGyroCmd("GIY_SET", QObject::tr("Gyro Yaw Angle"), "GIY", QObject::tr("Yaw relative to earth frame."));
        addGyroCmd("GIP_SET", QObject::tr("Gyro Pitch Angle"), "GIP", QObject::tr("Pitch relative to earth frame."));
        addGyroCmd("GIR_SET", QObject::tr("Gyro Roll Angle"), "GIR", QObject::tr("Roll relative to earth frame."));
        {
            CameraCommandDefinition cmd = makeCommand("GIM_SET", gimbalAngleCategory, QObject::tr("Gyro Yaw & Pitch"), "GIM", QStringLiteral("0000000000"), QChar('G'), QChar('w'), QObject::tr("Yaw angle + speed, pitch angle + speed (earth frame)."));
            cmd.dataEditable = true;
            defs.append(cmd);
        }

        // --- Gimbal Status & Toggles ---
        defs.append(makeCommand("GAC_QUERY", gimbalStatusCategory, QObject::tr("Query Encoder Attitude"), "GAC", "00", QChar('G'), QChar('r')));

        defs.append(makeCommand("GAA_ENABLE", gimbalStatusCategory, QObject::tr("Enable Attitude Broadcast"), "GAA", "01", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("GAA_DISABLE", gimbalStatusCategory, QObject::tr("Disable Attitude Broadcast"), "GAA", "00", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("GAA_QUERY", gimbalStatusCategory, QObject::tr("Query Broadcast State"), "GAA", "00", QChar('G'), QChar('r'), QString(), QStringLiteral("#TP")));

        defs.append(makeCommand("GIC_QUERY", gimbalStatusCategory, QObject::tr("Query Gyro Attitude"), "GIC", "00", QChar('G'), QChar('r')));

        defs.append(makeCommand("GIA_ENABLE", gimbalStatusCategory, QObject::tr("Enable Gyro Broadcast"), "GIA", "01", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("GIA_DISABLE", gimbalStatusCategory, QObject::tr("Disable Gyro Broadcast"), "GIA", "00", QChar('G'), QChar('w'), QString(), QStringLiteral("#TP")));
        defs.append(makeCommand("GIA_QUERY", gimbalStatusCategory, QObject::tr("Query Gyro Broadcast"), "GIA", "00", QChar('G'), QChar('r'), QString(), QStringLiteral("#TP")));

        defs.append(makeCommand("GMS_OPEN", gimbalStatusCategory, QObject::tr("Enable Gimbal Motors"), "GMS", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("GMS_CLOSE", gimbalStatusCategory, QObject::tr("Disable Gimbal Motors"), "GMS", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("GMS_QUERY", gimbalStatusCategory, QObject::tr("Query Motor State"), "GMS", "00", QChar('M'), QChar('r')));

        defs.append(makeCommand("SERIAL_NUMBER_QUERY", gimbalStatusCategory, QObject::tr("Query Serial Number"), "VER", "00", QChar('G'), QChar('r'), QObject::tr("Returns 14-character serial.")));

        // --- Video Capture & Recording ---
        defs.append(makeCommand("REC_STOP", videoCaptureCategory, QObject::tr("Stop Recording"), "REC", "00", QChar('D'), QChar('w')));
        defs.append(makeCommand("REC_START", videoCaptureCategory, QObject::tr("Start Recording"), "REC", "01", QChar('D'), QChar('w')));
        defs.append(makeCommand("REC_TOGGLE", videoCaptureCategory, QObject::tr("Toggle Recording"), "REC", "0A", QChar('D'), QChar('w')));
        defs.append(makeCommand("REC_QUERY", videoCaptureCategory, QObject::tr("Query Recording State"), "REC", "00", QChar('D'), QChar('r')));

        defs.append(makeCommand("CAPTURE_VIS_THERM", videoCaptureCategory, QObject::tr("Capture VIS+Thermal"), "CAP", "01", QChar('D'), QChar('w')));
        defs.append(makeCommand("CAPTURE_VIS", videoCaptureCategory, QObject::tr("Capture Visible"), "CAP", "02", QChar('D'), QChar('w')));
        defs.append(makeCommand("CAPTURE_THERMAL", videoCaptureCategory, QObject::tr("Capture Thermal"), "CAP", "03", QChar('D'), QChar('w')));
        defs.append(makeCommand("CAPTURE_ALL", videoCaptureCategory, QObject::tr("Capture VIS+Thermal+Temp"), "CAP", "05", QChar('D'), QChar('w')));

        // --- Video Settings ---
        {
            CameraCommandDefinition cmd = makeCommand("VID_SET_VIDEO", videoSettingCategory, QObject::tr("Set Video Resolution"), "VID", QStringLiteral("00"), QChar('D'), QChar('w'), QObject::tr("Select main video recording resolution."));
            cmd.options = {
                makeOption(QObject::tr("3840×2160"), QStringLiteral("00")),
                makeOption(QObject::tr("1920×1080"), QStringLiteral("01")),
                makeOption(QObject::tr("1280×720"), QStringLiteral("02")),
                makeOption(QObject::tr("640×480"), QStringLiteral("03"))
            };
            cmd.dataEditable = false;
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("VID_SET_PHOTO", videoSettingCategory, QObject::tr("Set Photo Resolution"), "VID", QStringLiteral("10"), QChar('D'), QChar('w'), QObject::tr("Select still photo resolution."));
            cmd.options = {
                makeOption(QObject::tr("3840×2160"), QStringLiteral("10")),
                makeOption(QObject::tr("1920×1080"), QStringLiteral("11")),
                makeOption(QObject::tr("1280×720"), QStringLiteral("12")),
                makeOption(QObject::tr("640×480"), QStringLiteral("13"))
            };
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("VID_SET_RTSP", videoSettingCategory, QObject::tr("Set RTSP Resolution"), "VID", QStringLiteral("20"), QChar('D'), QChar('w'), QObject::tr("Select streaming (RTSP) resolution."));
            cmd.options = {
                makeOption(QObject::tr("3840×2160"), QStringLiteral("20")),
                makeOption(QObject::tr("1920×1080"), QStringLiteral("21")),
                makeOption(QObject::tr("1280×720"), QStringLiteral("22")),
                makeOption(QObject::tr("640×480"), QStringLiteral("23"))
            };
            defs.append(cmd);
        }
        defs.append(makeCommand("VID_QUERY", videoSettingCategory, QObject::tr("Query Resolutions"), "VID", "00", QChar('D'), QChar('r')));

        {
            CameraCommandDefinition cmd = makeCommand("BITRATE_SET", videoSettingCategory, QObject::tr("Set Bitrate"), "BIT", QStringLiteral("K00050"), QChar('D'), QChar('w'), QObject::tr("Six characters. Use presets 1-8 or Kxxxxx for kbps."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Examples: 01 (1 Mbps) or K01234 (1234 kbps)");
            defs.append(cmd);
        }
        defs.append(makeCommand("BITRATE_QUERY", videoSettingCategory, QObject::tr("Query Bitrate"), "BIT", "00", QChar('D'), QChar('r')));

        defs.append(makeCommand("SDC_REMAINING", storageNetworkCategory, QObject::tr("Query TF Remaining"), "SDC", "00", QChar('D'), QChar('r')));
        defs.append(makeCommand("SDC_TOTAL", storageNetworkCategory, QObject::tr("Query TF Capacity"), "SDC", "01", QChar('D'), QChar('r')));

        defs.append(makeCommand("ROT_0", displayCategory, QObject::tr("Set Flip 0°"), "ROT", "00", QChar('D'), QChar('w')));
        defs.append(makeCommand("ROT_180", displayCategory, QObject::tr("Set Flip 180°"), "ROT", "02", QChar('D'), QChar('w')));
        defs.append(makeCommand("ROT_QUERY", displayCategory, QObject::tr("Query Flip"), "ROT", "00", QChar('D'), QChar('r')));

        {
            CameraCommandDefinition cmd = makeCommand("NETWORK_SET_IP", storageNetworkCategory, QObject::tr("Set Device IP"), "IPV", QStringLiteral("192.168.31.66"), QChar('D'), QChar('w'), QObject::tr("Enter IP in dotted format."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("e.g. 192.168.31.66");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("NETWORK_SET_GATEWAY", storageNetworkCategory, QObject::tr("Set Gateway"), "GTW", QStringLiteral("192.168.31.1"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("e.g. 192.168.31.1");
            defs.append(cmd);
        }
        defs.append(makeCommand("NETWORK_RESET", storageNetworkCategory, QObject::tr("Reset Network"), "RST", "01", QChar('D'), QChar('w')));

        // --- Display Controls ---
        {
            CameraCommandDefinition cmd = makeCommand("PIP_MODE", displayCategory, QObject::tr("Picture-in-Picture"), "PIP", QStringLiteral("0A"), QChar('D'), QChar('w'));
            cmd.options = {
                makeOption(QObject::tr("Main Only"), QStringLiteral("00")),
                makeOption(QObject::tr("Main + Sub"), QStringLiteral("01")),
                makeOption(QObject::tr("Sub + Main"), QStringLiteral("02")),
                makeOption(QObject::tr("Sub Only"), QStringLiteral("03")),
                makeOption(QObject::tr("Next Mode"), QStringLiteral("0A")),
                makeOption(QObject::tr("Previous Mode"), QStringLiteral("0B"))
            };
            defs.append(cmd);
        }

        {
            CameraCommandDefinition cmd = makeCommand("DIGITAL_ZOOM_SET_VISIBLE", displayCategory, QObject::tr("Digital Zoom · Visible"), "DZM", QStringLiteral("0000"), QChar('D'), QChar('w'), QObject::tr("Directly set visible-light digital zoom (0.0–8.8×)."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: 0 + magnification*10 (e.g. 025 → 2.5x)");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("DIGITAL_ZOOM_SET_THERMAL", displayCategory, QObject::tr("Digital Zoom · Thermal"), "DZM", QStringLiteral("1000"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: 1 + magnification*10 (e.g. 135 → 3.5x)");
            defs.append(cmd);
        }
        defs.append(makeCommand("DIGITAL_ZOOM_VISIBLE_IN", displayCategory, QObject::tr("Zoom In Visible"), "DZM", "00A", QChar('D'), QChar('w')));
        defs.append(makeCommand("DIGITAL_ZOOM_VISIBLE_OUT", displayCategory, QObject::tr("Zoom Out Visible"), "DZM", "00B", QChar('D'), QChar('w')));
        defs.append(makeCommand("DIGITAL_ZOOM_VISIBLE_STOP", displayCategory, QObject::tr("Zoom Stop Visible"), "DZM", "00E", QChar('D'), QChar('w')));
        defs.append(makeCommand("DIGITAL_ZOOM_THERMAL_IN", displayCategory, QObject::tr("Zoom In Thermal"), "DZM", "10A", QChar('D'), QChar('w')));
        defs.append(makeCommand("DIGITAL_ZOOM_THERMAL_OUT", displayCategory, QObject::tr("Zoom Out Thermal"), "DZM", "10B", QChar('D'), QChar('w')));
        defs.append(makeCommand("DIGITAL_ZOOM_THERMAL_STOP", displayCategory, QObject::tr("Zoom Stop Thermal"), "DZM", "10E", QChar('D'), QChar('w')));

        {
            CameraCommandDefinition cmd = makeCommand("EFOG_MODE", displayCategory, QObject::tr("Electronic Fog"), "DFG", QStringLiteral("100"), QChar('D'), QChar('w'), QObject::tr("X0=0(off)/1(auto)/2(manual). Intensity 00-FF."));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Auto: 100. Manual: 2 + intensity (e.g. 232)");
            defs.append(cmd);
        }

        {
            CameraCommandDefinition cmd = makeCommand("PSEUDO_COLOR", temperatureCategory, QObject::tr("Thermal Palette"), "IMG", QStringLiteral("00"), QChar('D'), QChar('w'));
            cmd.options = {
                makeOption(QObject::tr("White Hot"), QStringLiteral("00")),
                makeOption(QObject::tr("Lava"), QStringLiteral("01")),
                makeOption(QObject::tr("Iron Red"), QStringLiteral("02")),
                makeOption(QObject::tr("Hot Iron"), QStringLiteral("03")),
                makeOption(QObject::tr("Medical"), QStringLiteral("04")),
                makeOption(QObject::tr("Arctic"), QStringLiteral("05")),
                makeOption(QObject::tr("Rainbow 1"), QStringLiteral("06")),
                makeOption(QObject::tr("Rainbow 2"), QStringLiteral("07")),
                makeOption(QObject::tr("Reddening"), QStringLiteral("08")),
                makeOption(QObject::tr("Black Hot"), QStringLiteral("09")),
                makeOption(QObject::tr("Next Palette"), QStringLiteral("0A")),
                makeOption(QObject::tr("Previous Palette"), QStringLiteral("0B"))
            };
            defs.append(cmd);
        }
        defs.append(makeCommand("PSEUDO_COLOR_QUERY", temperatureCategory, QObject::tr("Query Palette"), "IMG", "00", QChar('D'), QChar('r')));

        {
            CameraCommandDefinition cmd = makeCommand("TEMP_AREA_REQUEST", temperatureCategory, QObject::tr("Measure Area Temperature"), "TMP", QStringLiteral("0000000000"), QChar('D'), QChar('r'), QObject::tr("XXX(top-left X) YYY(top-left Y) WW width HH height (0 for point)."));
            cmd.dataEditable = true;
            cmd.lengthFieldWidth = 2;
            cmd.dataHint = QObject::tr("Format: XXXYYYWWHH (e.g. 0100100505)");
            defs.append(cmd);
        }
        defs.append(makeCommand("TEMP_MODE_SET", temperatureCategory, QObject::tr("Temperature Range Mode"), "TMR", "00", QChar('D'), QChar('w'), QObject::tr("00:-20~150°C, 01:-20~550°C")));

        // --- System Time & Position ---
        {
            CameraCommandDefinition cmd = makeCommand("TIME_SET_BEIJING", timeGpsCategory, QObject::tr("Set Local Time"), "TIM", QString(), QChar('D'), QChar('w'), QObject::tr("Auto fills current local time (YYYYMMDDHHMMSS)."));
            cmd.dataEditable = true;
            cmd.autoGenerateData = true;
            cmd.dataHint = QObject::tr("Override if needed: YYYYMMDDHHMMSS");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("TIME_SET_UTC", timeGpsCategory, QObject::tr("Set UTC Time"), "UTC", QString(), QChar('D'), QChar('w'), QObject::tr("Auto fills current UTC (HHMMSSDDMMYY)."));
            cmd.dataEditable = true;
            cmd.autoGenerateData = true;
            cmd.dataHint = QObject::tr("Override if needed: HHMMSSDDMMYY");
            defs.append(cmd);
        }

        {
            CameraCommandDefinition cmd = makeCommand("GPS_LONGITUDE", timeGpsCategory, QObject::tr("Send Longitude"), "LON", QStringLiteral("E12345.6789"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: E/W + dddmm.mmmm");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("GPS_LATITUDE", timeGpsCategory, QObject::tr("Send Latitude"), "LAT", QStringLiteral("N2234.5678"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("Format: N/S + ddmm.mmmm");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("GPS_ALTITUDE", timeGpsCategory, QObject::tr("Send Altitude"), "ALT", QStringLiteral("0000.0"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("-9999.9 to 9999.9m");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("GPS_HEADING", timeGpsCategory, QObject::tr("Send Heading"), "AZI", QStringLiteral("000.0"), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.dataHint = QObject::tr("000.0-359.9 degrees");
            defs.append(cmd);
        }

        {
            CameraCommandDefinition cmd = makeCommand("GPS_PACKET", timeGpsCategory, QObject::tr("Send GPS Packet"), "GPS", QString(), QChar('D'), QChar('w'), QObject::tr("Hex payload per struct (frameHead excluded)."));
            cmd.dataEditable = true;
            cmd.lengthFieldWidth = 2;
            cmd.dataIsHexPayload = true;
            cmd.allowEmptyData = false;
            cmd.dataHint = QObject::tr("Enter full hex payload (ASCII hex)");
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("UAV_ATTITUDE", timeGpsCategory, QObject::tr("Send UAV Attitude"), "UAV", QString(), QChar('D'), QChar('w'));
            cmd.dataEditable = true;
            cmd.lengthFieldWidth = 2;
            cmd.dataIsHexPayload = true;
            cmd.allowEmptyData = false;
            cmd.dataHint = QObject::tr("Enter hex payload per UAV struct");
            defs.append(cmd);
        }

        // --- Laser ---
        defs.append(makeCommand("LRF_STOP", laserCategory, QObject::tr("Laser Stop"), "LRF", "00", QChar('M'), QChar('w')));
        defs.append(makeCommand("LRF_START", laserCategory, QObject::tr("Laser On"), "LRF", "01", QChar('M'), QChar('w')));
        defs.append(makeCommand("LRF_SINGLE", laserCategory, QObject::tr("Single Measure"), "LRF", "02", QChar('M'), QChar('w')));
        defs.append(makeCommand("LRF_CONTINUOUS", laserCategory, QObject::tr("Continuous Measure"), "LRF", "03", QChar('M'), QChar('w')));

        // --- Advanced ---
        {
            CameraCommandDefinition cmd = makeCommand("RAW_ASCII", advancedCategory, QObject::tr("Raw ASCII Frame"), "ZMC", QString(), QChar('M'), QChar('w'), QObject::tr("Build custom ASCII payload using default header/destination."));
            cmd.dataEditable = true;
            cmd.allowEmptyData = true;
            defs.append(cmd);
        }
        {
            CameraCommandDefinition cmd = makeCommand("RAW_HEX", advancedCategory, QObject::tr("Raw Hex Payload"), "ZMC", QString(), QChar('M'), QChar('w'), QObject::tr("Send raw binary payload (hex)."));
            cmd.dataEditable = true;
            cmd.dataIsHexPayload = true;
            cmd.allowEmptyData = false;
            defs.append(cmd);
        }

        return defs;
    }();

    return s_definitions;
}

const CameraCommandDefinition* CameraCommandRegistry::find(const QString& key)
{
    const QVector<CameraCommandDefinition>& defs = all();
    for (const CameraCommandDefinition& def : defs) {
        if (def.key == key) {
            return &def;
        }
    }
    return nullptr;
}
