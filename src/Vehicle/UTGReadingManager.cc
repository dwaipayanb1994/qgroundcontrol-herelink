/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UTGReadingManager.h"
#include "Vehicle.h"
#include "QGCApplication.h"
#include "SettingsManager.h"
#include "UTGSettings.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(UTGReadingManagerLog, "UTGReadingManagerLog")

UTGReadingManager::UTGReadingManager(QObject* parent)
    : QAbstractListModel(parent)
{
#ifndef Q_OS_ANDROID
    _loadFromDisk();
#endif
}

void UTGReadingManager::setVehicle(Vehicle* vehicle)
{
    _vehicle = vehicle;
}

int UTGReadingManager::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return _readings.count();
}

QVariant UTGReadingManager::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= _readings.count()) {
        return {};
    }

    const UTGReading& reading = _readings.at(index.row());
    switch (role) {
    case DateTimeRole:
        return reading.timestamp.toLocalTime().toString(Qt::DefaultLocaleShortDate);
    case ReadingRole:
        return QString::number(reading.thickness, 'f', 2);
    case GpsLocationRole:
        return _formatGpsLocation(reading.location);
    case NotesRole:
        return reading.notes;
    case ThicknessRole:
        return reading.thickness;
    case UnitRole:
        return reading.unit;
    default:
        return {};
    }
}

QHash<int, QByteArray> UTGReadingManager::roleNames() const
{
    return {
        {DateTimeRole,  "datetime"},
        {ReadingRole,   "reading"},
        {GpsLocationRole, "gpsLocation"},
        {NotesRole,     "notes"},
        {ThicknessRole, "thickness"},
        {UnitRole,      "unit"},
    };
}

void UTGReadingManager::onNewReading(double thickness, const QString& unit, int measurementMode)
{
    UTGReading reading(thickness, unit);
    reading.measurementMode = measurementMode;
    if (_vehicle && _vehicle->coordinate().isValid()) {
        reading.location = _vehicle->coordinate();
    }
    _appendReading(reading);
}

void UTGReadingManager::addReading(const UTGReading& reading)
{
    _appendReading(reading);
}

void UTGReadingManager::addReadingWithNotes(double thickness, const QString& unit, const QString& notes)
{
    UTGReading reading(thickness, unit);
    reading.notes = notes;
    if (_vehicle && _vehicle->coordinate().isValid()) {
        reading.location = _vehicle->coordinate();
    }
    _appendReading(reading);
}

void UTGReadingManager::removeReading(int row)
{
    if (row < 0 || row >= _readings.count()) {
        return;
    }

    beginRemoveRows(QModelIndex(), row, row);
    _readings.removeAt(row);
    endRemoveRows();
    _saveToDisk();
    emit countChanged();
}

void UTGReadingManager::clearAll()
{
    if (_readings.isEmpty()) {
        return;
    }

    beginResetModel();
    _readings.clear();
    endResetModel();
    _saveToDisk();
    emit countChanged();
}

void UTGReadingManager::setNotes(int row, const QString& notes)
{
    if (row < 0 || row >= _readings.count()) {
        return;
    }

    _readings[row].notes = notes;
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx, {NotesRole});
    _saveToDisk();
}

void UTGReadingManager::reload()
{
    beginResetModel();
    _loadFromDisk();
    endResetModel();
    emit countChanged();
}

QString UTGReadingManager::notesAt(int row) const
{
    if (row < 0 || row >= _readings.count()) {
        return {};
    }
    return _readings.at(row).notes;
}

QString UTGReadingManager::toJsonString() const
{
    QJsonArray readingsArray;
    for (const UTGReading& reading : _readings) {
        QJsonObject obj;
        // Legacy QML-compatible fields for SD card files
        obj.insert(QStringLiteral("datetime"), reading.timestamp.toLocalTime().toString(Qt::DefaultLocaleShortDate));
        obj.insert(QStringLiteral("reading"), QString::number(reading.thickness, 'f', 2));
        obj.insert(QStringLiteral("gpsLocation"), _formatGpsLocation(reading.location));
        obj.insert(QStringLiteral("notes"), reading.notes);

        // Extended C++ fields
        obj.insert(QStringLiteral("thickness"), reading.thickness);
        obj.insert(QStringLiteral("unit"), reading.unit);
        obj.insert(QStringLiteral("temperature"), reading.temperature);
        obj.insert(QStringLiteral("measurementMode"), reading.measurementMode);
        obj.insert(QStringLiteral("soundVelocity"), reading.soundVelocity);
        obj.insert(QStringLiteral("gain"), reading.gain);
        obj.insert(QStringLiteral("timestamp"), reading.timestamp.toString(Qt::ISODate));

        if (reading.location.isValid()) {
            QJsonObject locationObj;
            locationObj.insert(QStringLiteral("latitude"), reading.location.latitude());
            locationObj.insert(QStringLiteral("longitude"), reading.location.longitude());
            obj.insert(QStringLiteral("location"), locationObj);
        }

        readingsArray.append(obj);
    }

    QJsonObject root;
    root.insert(QStringLiteral("readings"), readingsArray);
    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
}

bool UTGReadingManager::loadFromJsonString(const QString& json)
{
    if (json.trimmed().isEmpty()) {
        return false;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject()) {
        qCWarning(UTGReadingManagerLog) << "Failed to parse readings JSON";
        return false;
    }

    beginResetModel();
    _readings.clear();
    const bool loaded = _loadFromJsonDocument(doc);
    endResetModel();
    emit countChanged();

    if (loaded) {
        qCDebug(UTGReadingManagerLog) << "Loaded" << _readings.count() << "readings from JSON string";
    }
    return loaded;
}

QString UTGReadingManager::defaultStoragePath() const
{
    return _storagePath();
}

void UTGReadingManager::_appendReading(const UTGReading& reading)
{
    beginInsertRows(QModelIndex(), _readings.count(), _readings.count());
    _readings.append(reading);
    endInsertRows();
    _saveToDisk();
    emit countChanged();
}

QString UTGReadingManager::_storagePath() const
{
    QGCApplication* app = qgcApp();
    if (app && app->toolbox() && app->toolbox()->settingsManager()) {
        UTGSettings* settings = app->toolbox()->settingsManager()->utgSettings();
        if (settings) {
            const QString configuredPath = settings->logFilePath()->rawValue().toString().trimmed();
            if (!configuredPath.isEmpty()) {
                return configuredPath;
            }
        }
    }

#ifdef Q_OS_ANDROID
    return QStringLiteral("/sdcard/UTG_Readings.json");
#else
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dataDir + QStringLiteral("/UTG_Readings.json");
#endif
}

bool UTGReadingManager::_loadFromJsonDocument(const QJsonDocument& doc)
{
    if (!doc.isObject()) {
        return false;
    }

    const QJsonArray readingsArray = doc.object().value(QStringLiteral("readings")).toArray();
    for (const QJsonValue& value : readingsArray) {
        const QJsonObject obj = value.toObject();

        double thickness = obj.value(QStringLiteral("thickness")).toDouble();
        if (thickness <= 0.0) {
            thickness = obj.value(QStringLiteral("reading")).toString().toDouble();
        }
        if (thickness <= 0.0) {
            continue;
        }

        UTGReading reading(thickness, obj.value(QStringLiteral("unit")).toString(QStringLiteral("mm")));
        reading.notes = obj.value(QStringLiteral("notes")).toString();
        reading.temperature = obj.value(QStringLiteral("temperature")).toDouble();
        reading.measurementMode = obj.value(QStringLiteral("measurementMode")).toInt();
        reading.soundVelocity = obj.value(QStringLiteral("soundVelocity")).toDouble();
        reading.gain = obj.value(QStringLiteral("gain")).toInt();

        const QString timestamp = obj.value(QStringLiteral("timestamp")).toString();
        const QString legacyDateTime = obj.value(QStringLiteral("datetime")).toString();
        if (!timestamp.isEmpty()) {
            reading.timestamp = QDateTime::fromString(timestamp, Qt::ISODate);
        } else if (!legacyDateTime.isEmpty()) {
            reading.timestamp = QDateTime::fromString(legacyDateTime, Qt::DefaultLocaleShortDate);
        }

        const QJsonObject locationObj = obj.value(QStringLiteral("location")).toObject();
        if (!locationObj.isEmpty()) {
            reading.location = QGeoCoordinate(
                        locationObj.value(QStringLiteral("latitude")).toDouble(),
                        locationObj.value(QStringLiteral("longitude")).toDouble());
        } else {
            const QString gpsLocation = obj.value(QStringLiteral("gpsLocation")).toString();
            const QStringList coords = gpsLocation.split(QLatin1Char(','), QString::SkipEmptyParts);
            if (coords.size() >= 2) {
                reading.location = QGeoCoordinate(coords.at(0).trimmed().toDouble(),
                                                coords.at(1).trimmed().toDouble());
            }
        }

        _readings.append(reading);
    }

    return !_readings.isEmpty();
}

bool UTGReadingManager::_loadFromFile(const QString& path)
{
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    return _loadFromJsonDocument(doc);
}

void UTGReadingManager::_loadFromDisk()
{
    _readings.clear();

    const QString path = _storagePath();
    if (_loadFromFile(path)) {
        qCDebug(UTGReadingManagerLog) << "Loaded" << _readings.count() << "readings from" << path;
        return;
    }

#ifdef Q_OS_ANDROID
    const QString legacyPath = QStringLiteral("/sdcard/UTG_Readings.json");
    if (path != legacyPath && _loadFromFile(legacyPath)) {
        qCDebug(UTGReadingManagerLog) << "Loaded" << _readings.count() << "readings from legacy path" << legacyPath;
    }
#endif
}

void UTGReadingManager::_saveToDisk()
{
#ifdef Q_OS_ANDROID
    // SD card writes are handled in QML via XMLHttpRequest (QFile cannot write /sdcard)
    return;
#endif

    const QString json = toJsonString();
    const QString path = _storagePath();
    QFile file(path);
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(UTGReadingManagerLog) << "Failed to save readings to" << path << file.errorString();
        return;
    }
    file.write(json.toUtf8());
    file.close();
    qCDebug(UTGReadingManagerLog) << "Saved" << _readings.count() << "readings to" << path;
}

QString UTGReadingManager::_formatGpsLocation(const QGeoCoordinate& coordinate) const
{
    if (!coordinate.isValid()) {
        return QStringLiteral("0.0, 0.0");
    }
    return QStringLiteral("%1, %2")
            .arg(coordinate.latitude(), 0, 'f', 6)
            .arg(coordinate.longitude(), 0, 'f', 6);
}
