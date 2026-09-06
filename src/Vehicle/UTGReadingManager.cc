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
#include <QFutureWatcher>
#include <QLoggingCategory>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QtConcurrent>

Q_LOGGING_CATEGORY(UTGReadingManagerLog, "UTGReadingManagerLog")

namespace {

static const int kSaveDebounceMs = 500;

QString _csvEscape(const QString& field)
{
    if (field.contains(QLatin1Char(',')) || field.contains(QLatin1Char('"')) || field.contains(QLatin1Char('\n'))) {
        return QStringLiteral("\"") + QString(field).replace(QLatin1Char('"'), QStringLiteral("\"\"")) + QStringLiteral("\"");
    }
    return field;
}

QStringList _parseCsvRow(const QString& line)
{
    QStringList fields;
    QString field;
    bool inQuotes = false;

    for (int i = 0; i < line.size(); ++i) {
        const QChar c = line.at(i);
        if (inQuotes) {
            if (c == QLatin1Char('"')) {
                if (i + 1 < line.size() && line.at(i + 1) == QLatin1Char('"')) {
                    field += QLatin1Char('"');
                    ++i;
                } else {
                    inQuotes = false;
                }
            } else {
                field += c;
            }
        } else if (c == QLatin1Char('"')) {
            inQuotes = true;
        } else if (c == QLatin1Char(',')) {
            fields.append(field);
            field.clear();
        } else {
            field += c;
        }
    }

    fields.append(field);
    return fields;
}

bool _hasValidAltitude(const QGeoCoordinate& coordinate)
{
    return coordinate.isValid() && !qIsNaN(coordinate.altitude());
}

QList<UTGReading> _parseCsvDocument(const QString& csv)
{
    QList<UTGReading> readings;
    const QStringList lines = csv.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), QString::SkipEmptyParts);
    if (lines.isEmpty()) {
        return readings;
    }

    int startIndex = 0;
    if (lines.first().startsWith(QStringLiteral("Date/Time"), Qt::CaseInsensitive)) {
        startIndex = 1;
    }

    for (int i = startIndex; i < lines.size(); ++i) {
        const QStringList fields = _parseCsvRow(lines.at(i));
        if (fields.size() < 2) {
            continue;
        }

        bool ok = false;
        const double thickness = fields.at(1).toDouble(&ok);
        if (!ok || thickness <= 0.0) {
            continue;
        }

        const QString unit = fields.size() > 2 ? fields.at(2).trimmed() : QStringLiteral("mm");
        UTGReading reading(thickness, unit.isEmpty() ? QStringLiteral("mm") : unit);

        if (fields.size() > 6) {
            reading.notes = fields.at(6).trimmed();
        } else if (fields.size() > 3) {
            reading.notes = fields.last().trimmed();
        }

        const QString timestamp = fields.at(0).trimmed();
        if (!timestamp.isEmpty()) {
            reading.timestamp = QDateTime::fromString(timestamp, Qt::ISODate);
            if (!reading.timestamp.isValid()) {
                reading.timestamp = QDateTime::fromString(timestamp, Qt::DefaultLocaleShortDate);
            }
        }

        if (fields.size() >= 6) {
            bool latOk = false;
            bool lonOk = false;
            const double latitude = fields.at(3).trimmed().toDouble(&latOk);
            const double longitude = fields.at(4).trimmed().toDouble(&lonOk);
            if (latOk && lonOk) {
                double altitude = qQNaN();
                if (!fields.at(5).trimmed().isEmpty()) {
                    bool altOk = false;
                    altitude = fields.at(5).trimmed().toDouble(&altOk);
                    if (!altOk) {
                        altitude = qQNaN();
                    }
                }
                reading.location = QGeoCoordinate(latitude, longitude, altitude);
            }
        }

        readings.append(reading);
    }

    return readings;
}

QList<UTGReading> _loadReadingsFromFile(const QString& path)
{
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return {};
    }

    const QList<UTGReading> readings = _parseCsvDocument(QString::fromUtf8(file.readAll()));
    file.close();
    return readings;
}

QList<UTGReading> _loadReadingsFromPaths(const QString& path, const QString& legacyPath)
{
    QList<UTGReading> readings = _loadReadingsFromFile(path);
    if (!readings.isEmpty()) {
        qCDebug(UTGReadingManagerLog) << "Loaded" << readings.count() << "readings from" << path;
        return readings;
    }

    if (!legacyPath.isEmpty() && legacyPath != path) {
        readings = _loadReadingsFromFile(legacyPath);
        if (!readings.isEmpty()) {
            qCDebug(UTGReadingManagerLog) << "Loaded" << readings.count() << "readings from legacy CSV" << legacyPath;
        }
    }

    return readings;
}

bool _writeCsvToPath(const QString& path, const QString& csv)
{
    QFile file(path);
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(UTGReadingManagerLog) << "Failed to save readings CSV to" << path << file.errorString();
        return false;
    }

    file.write(csv.toUtf8());
    file.close();
    return true;
}

} // namespace

Q_DECLARE_METATYPE(QList<UTGReading>)

UTGReadingManager::UTGReadingManager(QObject* parent)
    : QAbstractListModel(parent)
{
    _saveTimer = new QTimer(this);
    _saveTimer->setSingleShot(true);
    _saveTimer->setInterval(kSaveDebounceMs);
    connect(_saveTimer, &QTimer::timeout, this, &UTGReadingManager::_saveToDisk);
}

UTGReadingManager::~UTGReadingManager()
{
    if (_saveTimer && _saveTimer->isActive()) {
        _saveTimer->stop();
    }

    const QString csv = toCsvString();
    const QString path = _storagePath();
    _writeCsvToPath(path, csv);
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
    case AltitudeRole:
        return _formatAltitude(reading.location);
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
        {DateTimeRole,    "datetime"},
        {ReadingRole,     "reading"},
        {GpsLocationRole, "gpsLocation"},
        {AltitudeRole,    "altitude"},
        {NotesRole,       "notes"},
        {ThicknessRole,   "thickness"},
        {UnitRole,        "unit"},
    };
}

void UTGReadingManager::onNewReading(double thickness, const QString& unit, int measurementMode)
{
    UTGReading reading(thickness, unit);
    reading.measurementMode = measurementMode;
    _applyVehicleLocation(reading);
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
    _applyVehicleLocation(reading);
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
    _scheduleSaveToDisk();
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
    _scheduleSaveToDisk();
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
    _scheduleSaveToDisk();
}

void UTGReadingManager::reload()
{
    reloadAsync();
}

void UTGReadingManager::reloadAsync()
{
    ++_loadGeneration;
    const int generation = _loadGeneration;

    if (_loadWatcher) {
        disconnect(_loadWatcher, nullptr, this, nullptr);
        _loadWatcher->deleteLater();
        _loadWatcher = nullptr;
    }

    if (!_loadInProgress) {
        _loadInProgress = true;
        emit loadingChanged(true);
    }

    const QString path = _storagePath();
    QString legacyPath;
#ifdef Q_OS_ANDROID
    if (path != QStringLiteral("/sdcard/UTG_Readings.csv")) {
        legacyPath = QStringLiteral("/sdcard/UTG_Readings.csv");
    }
#endif

    _loadWatcher = new QFutureWatcher<QList<UTGReading>>(this);
    connect(_loadWatcher, &QFutureWatcher<QList<UTGReading>>::finished, this, [this, generation]() {
        if (generation != _loadGeneration) {
            return;
        }

        _applyLoadedReadings(_loadWatcher->result());
        _loadWatcher->deleteLater();
        _loadWatcher = nullptr;
        _loadInProgress = false;
        emit loadingChanged(false);
        emit countChanged();
        emit readingsLoaded();
    });

    _loadWatcher->setFuture(QtConcurrent::run(_loadReadingsFromPaths, path, legacyPath));
}

QString UTGReadingManager::notesAt(int row) const
{
    if (row < 0 || row >= _readings.count()) {
        return {};
    }
    return _readings.at(row).notes;
}

QString UTGReadingManager::toCsvString() const
{
    QString csv = QStringLiteral("Date/Time,Thickness,Unit,GPS Latitude,GPS Longitude,GPS Altitude (m),Notes\n");

    for (const UTGReading& reading : _readings) {
        const QString dateTime = reading.timestamp.toString(Qt::ISODate);
        const QString thickness = QString::number(reading.thickness, 'f', 2);
        const QString unit = reading.unit;
        const QString latitude = reading.location.isValid()
                ? QString::number(reading.location.latitude(), 'f', 6)
                : QString();
        const QString longitude = reading.location.isValid()
                ? QString::number(reading.location.longitude(), 'f', 6)
                : QString();
        const QString altitude = _hasValidAltitude(reading.location)
                ? QString::number(reading.location.altitude(), 'f', 2)
                : QString();

        csv += _csvEscape(dateTime) + QLatin1Char(',')
                + _csvEscape(thickness) + QLatin1Char(',')
                + _csvEscape(unit) + QLatin1Char(',')
                + _csvEscape(latitude) + QLatin1Char(',')
                + _csvEscape(longitude) + QLatin1Char(',')
                + _csvEscape(altitude) + QLatin1Char(',')
                + _csvEscape(reading.notes) + QLatin1Char('\n');
    }

    return csv;
}

bool UTGReadingManager::importCsvFromString(const QString& csv)
{
    if (csv.trimmed().isEmpty()) {
        return false;
    }

    beginResetModel();
    _readings = _parseCsvDocument(csv);
    endResetModel();
    emit countChanged();

    if (!_readings.isEmpty()) {
        qCDebug(UTGReadingManagerLog) << "Imported" << _readings.count() << "readings from CSV string";
        _scheduleSaveToDisk();
    }
    return !_readings.isEmpty();
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
    _scheduleSaveToDisk();
    emit countChanged();
}

void UTGReadingManager::_applyVehicleLocation(UTGReading& reading) const
{
    if (_vehicle && _vehicle->coordinate().isValid()) {
        reading.location = _vehicle->coordinate();
    }
}

void UTGReadingManager::_applyLoadedReadings(const QList<UTGReading>& readings)
{
    beginResetModel();
    _readings = readings;
    endResetModel();
}

QString UTGReadingManager::_storagePath() const
{
    QGCApplication* app = qgcApp();
    if (app && app->toolbox() && app->toolbox()->settingsManager()) {
        UTGSettings* settings = app->toolbox()->settingsManager()->utgSettings();
        if (settings) {
            QString configuredPath = settings->logFilePath()->rawValue().toString().trimmed();
            if (!configuredPath.isEmpty()) {
                if (!configuredPath.endsWith(QStringLiteral(".csv"), Qt::CaseInsensitive)) {
                    configuredPath += QStringLiteral(".csv");
                }
                return configuredPath;
            }
        }
    }

#ifdef Q_OS_ANDROID
    return QStringLiteral("/sdcard/UTG_Readings.csv");
#else
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dataDir + QStringLiteral("/UTG_Readings.csv");
#endif
}

bool UTGReadingManager::_loadFromCsvDocument(const QString& csv)
{
    _readings = _parseCsvDocument(csv);
    return !_readings.isEmpty();
}

bool UTGReadingManager::_loadFromFile(const QString& path)
{
    _readings = _loadReadingsFromFile(path);
    return !_readings.isEmpty();
}

void UTGReadingManager::_loadFromDisk()
{
    _readings.clear();

    const QString path = _storagePath();
    if (_loadFromFile(path)) {
        return;
    }

#ifdef Q_OS_ANDROID
    const QString legacyCsvPath = QStringLiteral("/sdcard/UTG_Readings.csv");
    if (path != legacyCsvPath && _loadFromFile(legacyCsvPath)) {
        qCDebug(UTGReadingManagerLog) << "Loaded" << _readings.count() << "readings from legacy CSV" << legacyCsvPath;
    }
#endif
}

void UTGReadingManager::_scheduleSaveToDisk()
{
    if (_saveTimer) {
        _saveTimer->start();
    }
}

void UTGReadingManager::_saveToDisk()
{
    const QString csv = toCsvString();
    const QString path = _storagePath();

    QtConcurrent::run([csv, path]() {
        _writeCsvToPath(path, csv);
    });

    qCDebug(UTGReadingManagerLog) << "Scheduled save of readings to" << path;
}

QString UTGReadingManager::_formatGpsLocation(const QGeoCoordinate& coordinate) const
{
    if (!coordinate.isValid()) {
        return QStringLiteral("N/A");
    }
    return QStringLiteral("%1, %2")
            .arg(coordinate.latitude(), 0, 'f', 6)
            .arg(coordinate.longitude(), 0, 'f', 6);
}

QString UTGReadingManager::_formatAltitude(const QGeoCoordinate& coordinate) const
{
    if (!_hasValidAltitude(coordinate)) {
        return QStringLiteral("N/A");
    }
    return QStringLiteral("%1 m").arg(coordinate.altitude(), 0, 'f', 2);
}
