# QGroundControl Ground Control Station

## Custom Build Example

To build this sample custom version, simply rename the directory from `custom-example` to `custom` before running `qmake` (or launching Qt Creator.) The build system will automatically find anything in `custom` and incorporate it into the build. If you had already run a build before renaming the directory, delete the build directory before running `qmake`. To restore the build to a stock QGroundControl one, rename the directory back to `custom-example` (making sure to clean the build directory again.)

## Topotek Camera Control Module

The `custom/src/camera` module adds an end-to-end implementation of the Topotek SIP camera protocol, including transport management, frame packing, and a QML-driven operator console. The feature is available from the **Topotek Camera** entry inside *Settings ➜ General* once the custom build is running.

### Capabilities

- **One-button coverage:** Every documented camera, gimbal, laser, and imaging function is represented as an actionable button generated from the command registry (`CameraCommandRegistry`).
- **Transport abstraction:** `CameraTransport` supports both serial (UART) and UDP links with runtime switching, status reporting, and error surfacing.
- **Protocol framing:** `CameraProtocol` converts command metadata into correctly framed ASCII packets, including length, CRC, identifier, and optional hex payloads.
- **Operator console:** `custom/src/ui/qml/CameraControlPanel.qml` renders grouped sections with optional data entry, drop-down presets, activity logs, and live frame previews.
- **Metadata for QML:** `CameraCommandDefinition` exposes command descriptors to QML without duplicating protocol knowledge.

### Directory layout

| Path | Purpose |
| ---- | ------- |
| `custom/src/camera/CameraCommandDefinition.*` | Data structures describing commands, options, and QML conversion helpers. |
| `custom/src/camera/CameraCommandRegistry.*` | Central catalogue of all camera, gimbal, laser, temperature, and system commands. |
| `custom/src/camera/CameraProtocol.*` | Frame builder responsible for header selection, length encoding, and CRC generation. |
| `custom/src/camera/CameraTransport.*` | Serial/UDP transport abstraction with Qt signal hooks for telemetry/logging. |
| `custom/src/camera/CameraController.*` | QML-facing controller exposing command catalogue, log stream, and transport APIs. |
| `custom/src/ui/qml/CameraControlPanel.qml` | Rich UI that instantiates `CameraController` and renders interactive command groups. |

### Quick start

1. Open the **Topotek Camera** settings panel.
2. Select the desired transport mode (Auto, Serial only, or UDP only).
3. Configure UART (port + baud) or UDP (device/local ports) and connect/bind.
4. Expand any category to access its commands. Options and data fields adapt to each command’s metadata.
5. Observe transmit/receive logs and the most recent frame preview in the lower activity panel.

> Tip: Commands that require custom payloads expose inline text fields with hints. Enum-style commands provide a drop-down selector and populate the payload automatically.

### Command coverage checklist

The registry currently publishes **100+** commands, grouped to mirror the protocol reference:

- Lens zoom, focus, aperture, and optical magnification controls.
- Gimbal motion, speed, absolute angle, and broadcast toggles.
- Video capture, resolution, bitrate, and pip/zoom display management.
- Thermal imaging: pseudo-color palettes, temperature area requests, range modes.
- System utilities for network settings, GPS/time synchronisation, and UAV telemetry packets.
- Laser rangefinder activation modes plus raw command helpers for advanced troubleshooting.

Each entry includes a unique key, identifier, default payload, and optional description so the UI can remain generic while staying protocol-accurate.

---

### Custom Builds

The root project file (`qgroundcontrol.pro`) will look and see if `custom/custom.pri` exists. If it does, it will load it before anything else is setup. This allows you to modify the build in any way necessary for a custom build. This example shows you how to:

* Fully brand your build
* Define a single flight stack to avoid carrying over unnecessary code
* Implement your own, autopilot and firmware plugin overrides
* Implement your own camera manager and plugin overrides
* Implement your own QtQuick interface module
* Implement your own toolbar, toolbar indicators and UI navigation
* Implement your own Fly View overlay (and how to hide elements from QGC such as the flight widget)
* Implement your own, custom QtQuick camera control
* Implement your own, custom Pre-flight Checklist
* Define your own resources for all of the above

Note that within `qgroundcontrol.pro`, most main build steps are surrounded by flags, which you can define to override them. For example, if you want to have your own Android build, done in some completely different way, you simply:

```
DEFINES += DISABLE_BUILTIN_ANDROID
```

With this defined within your `custom.pri` file, it is up to you to define how to do the Android build. You can either replace the entire process or prepare it before invoking QGC’s own Android project file on your own. You would do this if you want to have your own branding within the Android manifest. The same applies to iOS (`DISABLE_BUILTIN_IOS`).
