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

class Vehicle;

/// Manages UTG thickness reading history with persistent JSON storage
class UTGReadingManager : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum ReadingRoles {
        DateTimeRole = Qt::UserRole + 1,
        ReadingRole,
        GpsLocationRole,
        NotesRole,
        ThicknessRole,
        UnitRole,
    };
    Q_ENUM(ReadingRoles)

    explicit UTGReadingManager(QObject* parent = nullptr);

    void setVehicle(Vehicle* vehicle);

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
    Q_INVOKABLE QString notesAt(int row) const;
    Q_INVOKABLE QString toJsonString() const;
    Q_INVOKABLE bool loadFromJsonString(const QString& json);
    Q_INVOKABLE QString defaultStoragePath() const;

signals:
    void countChanged();

private:
    void _appendReading(const UTGReading& reading);
    QString _storagePath() const;
    bool _loadFromFile(const QString& path);
    bool _loadFromJsonDocument(const QJsonDocument& doc);
    void _loadFromDisk();
    void _saveToDisk();
    QString _formatGpsLocation(const QGeoCoordinate& coordinate) const;

    Vehicle*            _vehicle = nullptr;
    QList<UTGReading>   _readings;
};
