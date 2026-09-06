/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "UTGReading.h"

#include <QAbstractListModel>
#include <QObject>

class QTimer;
template<typename T> class QFutureWatcher;

class Vehicle;

/// Manages UTG thickness reading history with persistent CSV storage
class UTGReadingManager : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int  count   READ rowCount      NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading       NOTIFY loadingChanged)

public:
    enum ReadingRoles {
        DateTimeRole = Qt::UserRole + 1,
        ReadingRole,
        GpsLocationRole,
        AltitudeRole,
        NotesRole,
        ThicknessRole,
        UnitRole,
    };
    Q_ENUM(ReadingRoles)

    explicit UTGReadingManager(QObject* parent = nullptr);
    ~UTGReadingManager();

    void setVehicle(Vehicle* vehicle);

    bool loading() const { return _loadInProgress; }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void onNewReading(double thickness, const QString& unit, int measurementMode);
    void addReading(const UTGReading& reading);

    Q_INVOKABLE void addReadingWithNotes(double thickness, const QString& unit, const QString& notes);
    Q_INVOKABLE void removeReading(int row);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void setNotes(int row, const QString& notes);
    Q_INVOKABLE void reload();
    Q_INVOKABLE void reloadAsync();
    Q_INVOKABLE QString notesAt(int row) const;
    Q_INVOKABLE QString toCsvString() const;
    Q_INVOKABLE bool importCsvFromString(const QString& csv);
    Q_INVOKABLE QString defaultStoragePath() const;

signals:
    void countChanged();
    void loadingChanged(bool loading);
    void readingsLoaded();

private:
    void _appendReading(const UTGReading& reading);
    void _applyVehicleLocation(UTGReading& reading) const;
    void _applyLoadedReadings(const QList<UTGReading>& readings);
    QString _storagePath() const;
    bool _loadFromFile(const QString& path);
    bool _loadFromCsvDocument(const QString& csv);
    void _loadFromDisk();
    void _scheduleSaveToDisk();
    void _saveToDisk();
    QString _formatGpsLocation(const QGeoCoordinate& coordinate) const;
    QString _formatAltitude(const QGeoCoordinate& coordinate) const;

    Vehicle*                                _vehicle = nullptr;
    QList<UTGReading>                       _readings;
    QTimer*                                 _saveTimer = nullptr;
    QFutureWatcher<QList<UTGReading>>*      _loadWatcher = nullptr;
    bool                                    _loadInProgress = false;
    int                                     _loadGeneration = 0;
};
