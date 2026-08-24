/*
    plasma-window-sorter - installed applications, for picking menu entries

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "applicationsmodel.h"

#include <KApplicationTrader>

#include <QCollator>

ApplicationsModel::ApplicationsModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_all = KApplicationTrader::query([](const KService::Ptr &service) {
        return service->isApplication() && !service->noDisplay() && !service->exec().isEmpty();
    });

    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(m_all.begin(), m_all.end(), [&collator](const KService::Ptr &left, const KService::Ptr &right) {
        return collator.compare(left->name(), right->name()) < 0;
    });

    m_shown = m_all;
}

int ApplicationsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_shown.count();
}

QVariant ApplicationsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_shown.count()) {
        return {};
    }

    const KService::Ptr service = m_shown.at(index.row());
    switch (role) {
    case NameRole:
        return service->name();
    case IconRole:
        return service->icon();
    case StorageIdRole:
        return service->storageId();
    case CommentRole:
        return service->comment().isEmpty() ? service->genericName() : service->comment();
    default:
        return {};
    }
}

QHash<int, QByteArray> ApplicationsModel::roleNames() const
{
    return {
        {NameRole, QByteArrayLiteral("name")},
        {IconRole, QByteArrayLiteral("iconName")},
        {StorageIdRole, QByteArrayLiteral("storageId")},
        {CommentRole, QByteArrayLiteral("comment")},
    };
}

QString ApplicationsModel::filter() const
{
    return m_filter;
}

void ApplicationsModel::setFilter(const QString &filter)
{
    if (m_filter == filter) {
        return;
    }
    m_filter = filter;
    applyFilter();
    Q_EMIT filterChanged();
}

void ApplicationsModel::applyFilter()
{
    beginResetModel();
    if (m_filter.trimmed().isEmpty()) {
        m_shown = m_all;
    } else {
        const QString needle = m_filter.trimmed();
        m_shown.clear();
        for (const KService::Ptr &service : std::as_const(m_all)) {
            if (service->name().contains(needle, Qt::CaseInsensitive) //
                || service->genericName().contains(needle, Qt::CaseInsensitive) //
                || service->exec().contains(needle, Qt::CaseInsensitive)) {
                m_shown.append(service);
            }
        }
    }
    endResetModel();
}
