/*
    plasma-window-sorter - System Settings module

    The panel re-reads this configuration every time its context menu is built,
    so saving here is all that is needed - nothing has to be restarted.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "kcm.h"

#include <KPluginFactory>

#include <QQmlEngine>

K_PLUGIN_CLASS_WITH_JSON(WindowSorterKcm, "kcm_windowsorter.json")

WindowSorterKcm::WindowSorterKcm(QObject *parent, const KPluginMetaData &metaData)
    : KQuickConfigModule(parent, metaData)
    , m_settings(new WindowSorterSettings(this))
{
    qmlRegisterAnonymousType<WindowSorterSettings>("org.kde.plasma.windowsorter", 1);

    connect(m_settings, &WindowSorterSettings::ShowVerticalChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::ShowHorizontalChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::ShowOptimalChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::ShowCascadeChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::IncludeMinimizedChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::TargetAspectChanged, this, &WindowSorterKcm::updateNeedsSave);
    connect(m_settings, &WindowSorterSettings::DebugChanged, this, &WindowSorterKcm::updateNeedsSave);
}

WindowSorterSettings *WindowSorterKcm::settings() const
{
    return m_settings;
}

void WindowSorterKcm::load()
{
    m_settings->load();
    updateNeedsSave();
}

void WindowSorterKcm::save()
{
    m_settings->save();
    setNeedsSave(false);
}

void WindowSorterKcm::defaults()
{
    m_settings->setDefaults();
    updateNeedsSave();
}

void WindowSorterKcm::updateNeedsSave()
{
    setNeedsSave(m_settings->isSaveNeeded());
    setRepresentsDefaults(m_settings->isDefaults());
}

#include "kcm.moc"
