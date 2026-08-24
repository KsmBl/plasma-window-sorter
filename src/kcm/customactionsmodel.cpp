/*
    plasma-window-sorter - the user's own entries in the panel menu

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "customactionsmodel.h"

#include <KConfigGroup>
#include <KService>
#include <KSharedConfig>

namespace
{
const char s_configFile[] = "plasma-window-sorterrc";
const char s_group[] = "CustomActions";

KConfigGroup rootGroup()
{
    KSharedConfig::Ptr file = KSharedConfig::openConfig(QLatin1String(s_configFile));
    file->reparseConfiguration();
    return file->group(QLatin1String(s_group));
}
}

CustomActionsModel::CustomActionsModel(QObject *parent)
    : QAbstractListModel(parent)
{
    load();
}

int CustomActionsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.count();
}

QVariant CustomActionsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.count()) {
        return {};
    }

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case NameRole:
        return entry.name;
    case IconRole:
        return entry.icon;
    case CommandRole:
        return entry.command;
    case ServiceRole:
        return entry.service;
    default:
        return {};
    }
}

QHash<int, QByteArray> CustomActionsModel::roleNames() const
{
    return {
        {NameRole, QByteArrayLiteral("name")},
        {IconRole, QByteArrayLiteral("iconName")},
        {CommandRole, QByteArrayLiteral("command")},
        {ServiceRole, QByteArrayLiteral("service")},
    };
}

void CustomActionsModel::addApplication(const QString &storageId)
{
    const KService::Ptr service = KService::serviceByStorageId(storageId);
    if (!service) {
        return;
    }

    Entry entry;
    entry.name = service->name();
    entry.icon = service->icon();
    entry.command = service->exec();
    entry.service = service->storageId();

    beginInsertRows({}, m_entries.count(), m_entries.count());
    m_entries.append(entry);
    endInsertRows();

    Q_EMIT countChanged();
    Q_EMIT changed();
}

void CustomActionsModel::addCommand(const QString &name, const QString &command, const QString &icon)
{
    if (name.isEmpty() || command.isEmpty()) {
        return;
    }

    Entry entry;
    entry.name = name;
    entry.command = command;
    entry.icon = icon.isEmpty() ? QStringLiteral("application-x-executable") : icon;

    beginInsertRows({}, m_entries.count(), m_entries.count());
    m_entries.append(entry);
    endInsertRows();

    Q_EMIT countChanged();
    Q_EMIT changed();
}

void CustomActionsModel::update(int row, const QString &name, const QString &command, const QString &icon)
{
    if (row < 0 || row >= m_entries.count()) {
        return;
    }

    Entry &entry = m_entries[row];
    entry.name = name;
    entry.command = command;
    entry.icon = icon;
    // An edited command no longer matches the .desktop file it came from.
    entry.service.clear();

    Q_EMIT dataChanged(index(row), index(row));
    Q_EMIT changed();
}

void CustomActionsModel::remove(int row)
{
    if (row < 0 || row >= m_entries.count()) {
        return;
    }

    beginRemoveRows({}, row, row);
    m_entries.removeAt(row);
    endRemoveRows();

    Q_EMIT countChanged();
    Q_EMIT changed();
}

void CustomActionsModel::move(int row, int offset)
{
    const int target = row + offset;
    if (row < 0 || row >= m_entries.count() || target < 0 || target >= m_entries.count()) {
        return;
    }

    // beginMoveRows wants the index the row lands *before* when moving down.
    beginMoveRows({}, row, row, {}, target > row ? target + 1 : target);
    m_entries.move(row, target);
    endMoveRows();

    Q_EMIT changed();
}

void CustomActionsModel::load()
{
    beginResetModel();
    m_entries.clear();

    const KConfigGroup group = rootGroup();
    const int count = group.readEntry("Count", 0);
    for (int i = 0; i < count; ++i) {
        const KConfigGroup stored = group.group(QString::number(i));
        Entry entry;
        entry.name = stored.readEntry("Name", QString());
        entry.icon = stored.readEntry("Icon", QString());
        entry.command = stored.readEntry("Command", QString());
        entry.service = stored.readEntry("Service", QString());
        if (!entry.name.isEmpty() && !(entry.command.isEmpty() && entry.service.isEmpty())) {
            m_entries.append(entry);
        }
    }

    m_stored = m_entries;
    endResetModel();

    Q_EMIT countChanged();
}

void CustomActionsModel::save()
{
    KConfigGroup group = rootGroup();

    // Drop the old numbering wholesale: entries may have been removed or moved.
    const int previous = group.readEntry("Count", 0);
    for (int i = 0; i < previous; ++i) {
        group.deleteGroup(QString::number(i));
    }

    for (int i = 0; i < m_entries.count(); ++i) {
        const Entry &entry = m_entries.at(i);
        KConfigGroup stored = group.group(QString::number(i));
        stored.writeEntry("Name", entry.name);
        stored.writeEntry("Icon", entry.icon);
        stored.writeEntry("Command", entry.command);
        stored.writeEntry("Service", entry.service);
    }

    group.writeEntry("Count", m_entries.count());
    group.sync();

    m_stored = m_entries;
}

bool CustomActionsModel::isSaveNeeded() const
{
    return m_entries != m_stored;
}

bool CustomActionsModel::isDefaults() const
{
    return m_entries.isEmpty();
}
