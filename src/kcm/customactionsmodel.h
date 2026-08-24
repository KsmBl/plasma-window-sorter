/*
    plasma-window-sorter - the user's own entries in the panel menu

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>

class CustomActionsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        IconRole,
        CommandRole,
        ServiceRole,
    };

    explicit CustomActionsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /*! Takes name, icon and command straight from the .desktop file. */
    Q_INVOKABLE void addApplication(const QString &storageId);
    Q_INVOKABLE void addCommand(const QString &name, const QString &command, const QString &icon);
    Q_INVOKABLE void update(int row, const QString &name, const QString &command, const QString &icon);
    Q_INVOKABLE void remove(int row);
    Q_INVOKABLE void move(int row, int offset);

    void load();
    void save();
    bool isSaveNeeded() const;
    bool isDefaults() const;

Q_SIGNALS:
    void countChanged();
    void changed();

private:
    struct Entry {
        QString name;
        QString icon;
        QString command;
        QString service;

        // Written out rather than defaulted: this builds as C++17.
        bool operator==(const Entry &other) const
        {
            return name == other.name && icon == other.icon && command == other.command && service == other.service;
        }
    };

    QList<Entry> m_entries;
    QList<Entry> m_stored;
};
