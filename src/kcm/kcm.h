/*
    plasma-window-sorter - System Settings module

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KQuickConfigModule>

// Full definition: moc needs it for the pointer property below.
#include "windowsortersettings.h"

class WindowSorterKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(WindowSorterSettings *settings READ settings CONSTANT)

public:
    WindowSorterKcm(QObject *parent, const KPluginMetaData &metaData);

    WindowSorterSettings *settings() const;

    void load() override;
    void save() override;
    void defaults() override;

private:
    void updateNeedsSave();

    WindowSorterSettings *m_settings;
};
