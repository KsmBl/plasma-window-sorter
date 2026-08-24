/*
    plasma-window-sorter - installed applications, for picking menu entries

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KService>

#include <QAbstractListModel>
#include <QList>
#include <QString>

class ApplicationsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        IconRole,
        StorageIdRole,
        CommentRole,
    };

    explicit ApplicationsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString filter() const;
    void setFilter(const QString &filter);

Q_SIGNALS:
    void filterChanged();

private:
    void applyFilter();

    QList<KService::Ptr> m_all;
    QList<KService::Ptr> m_shown;
    QString m_filter;
};
