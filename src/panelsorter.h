/*
    plasma-window-sorter - panel containment with window sorting actions

    A drop-in replacement for Plasma's org.kde.panel containment. The QML is
    upstream's, untouched; the only difference is this Plasma::Containment
    subclass, which adds the window-sorting entries to the panel's context menu.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <Plasma/Containment>

#include <KConfigGroup>

#include <QList>
#include <QString>

class QAction;

class PanelSorter : public Plasma::Containment
{
    Q_OBJECT

public:
    PanelSorter(QObject *parent, const KPluginMetaData &data, const QVariantList &args);
    ~PanelSorter() override;

    /*!
     * Upstream's actions (none, for a panel) plus our sorting entries.
     * The contextmenu containmentaction plugin inserts these directly above
     * "Show Panel Configuration".
     */
    QList<QAction *> contextualActions() override;

private:
    QAction *createSortAction(const QString &mode, const QString &text, const QString &iconName);

    /*! Hands the layout job to KWin, the only thing allowed to move windows on Wayland. */
    void sortWindows(const QString &mode);

    /*! Writes the parameterised KWin script for this run, returns its path. */
    QString buildScript(const QString &mode) const;

    /*! The settings group, re-read from disk on each access. */
    static KConfigGroup settings();

    /*! One menu entry, with the settings key that decides whether it is shown. */
    struct SortAction
    {
        QString configKey;
        QAction *action;
    };

    QList<SortAction> m_sortActions;
    QAction *m_separator;
};
