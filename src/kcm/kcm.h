/*
    plasma-window-sorter - System Settings module

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KQuickConfigModule>

// Full definitions: moc needs them for the pointer properties below.
#include "applicationsmodel.h"
#include "customactionsmodel.h"
#include "windowsortersettings.h"

class WindowSorterKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(WindowSorterSettings *settings READ settings CONSTANT)
    Q_PROPERTY(CustomActionsModel *customActions READ customActions CONSTANT)
    Q_PROPERTY(ApplicationsModel *applications READ applications CONSTANT)

public:
    WindowSorterKcm(QObject *parent, const KPluginMetaData &metaData);

    WindowSorterSettings *settings() const;
    CustomActionsModel *customActions() const;
    ApplicationsModel *applications() const;

    void load() override;
    void save() override;
    void defaults() override;

private:
    void updateNeedsSave();

    WindowSorterSettings *m_settings;
    CustomActionsModel *m_customActions;
    ApplicationsModel *m_applications;
};
