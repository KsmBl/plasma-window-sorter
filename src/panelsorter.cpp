/*
    plasma-window-sorter - panel containment with window sorting actions

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "panelsorter.h"

#include <QAction>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QRectF>
#include <QStandardPaths>
#include <QTimer>

#include <KConfigGroup>
#include <KLocalizedString>
#include <KPluginFactory>
#include <KSharedConfig>

namespace
{
// Where the KWin payload lives once installed; overridable for development.
QString scriptLibraryPath()
{
    const QString fromEnv = qEnvironmentVariable("PLASMA_WINDOW_SORTER_SCRIPT");
    if (!fromEnv.isEmpty()) {
        return fromEnv;
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("plasma-window-sorter/sorter.js"));
}

QString jsBool(bool value)
{
    return value ? QStringLiteral("true") : QStringLiteral("false");
}
}

// Build marker. install.sh greps the binary for this to tell a patched panel
// from the distribution's own, so it never backs up its own build as "original".
extern "C" Q_DECL_EXPORT const char plasma_window_sorter_version[] = "plasma-window-sorter " PWS_VERSION;

PanelSorter::PanelSorter(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Containment(parent, data, args)
{
    m_separator = new QAction(this);
    m_separator->setSeparator(true);

    m_sortActions = {
        {QStringLiteral("ShowVertical"),
         createSortAction(QStringLiteral("vertical"),
                          i18nc("@action:inmenu panel context menu", "Sort Windows Vertically"),
                          QStringLiteral("view-split-top-bottom"))},
        {QStringLiteral("ShowHorizontal"),
         createSortAction(QStringLiteral("horizontal"),
                          i18nc("@action:inmenu panel context menu", "Sort Windows Horizontally"),
                          QStringLiteral("view-split-left-right"))},
        {QStringLiteral("ShowOptimal"),
         createSortAction(QStringLiteral("optimal"),
                          i18nc("@action:inmenu panel context menu", "Sort Windows Optimally"),
                          QStringLiteral("view-grid"))},
        {QStringLiteral("ShowCascade"),
         createSortAction(QStringLiteral("cascade"),
                          i18nc("@action:inmenu panel context menu", "Sort Windows Cascading"),
                          QStringLiteral("window-duplicate"))},
    };
}

KConfigGroup PanelSorter::settings()
{
    // Re-read every time: the settings module writes this file from another
    // process, and these paths run rarely enough for the cost not to matter.
    KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("plasma-window-sorterrc"));
    config->reparseConfiguration();
    return config->group(QStringLiteral("General"));
}

PanelSorter::~PanelSorter() = default;

QAction *PanelSorter::createSortAction(const QString &mode, const QString &text, const QString &iconName)
{
    auto *action = new QAction(QIcon::fromTheme(iconName), text, this);
    action->setObjectName(QStringLiteral("sortwindows_") + mode);
    connect(action, &QAction::triggered, this, [this, mode] {
        sortWindows(mode);
    });
    return action;
}

QList<QAction *> PanelSorter::contextualActions()
{
    QList<QAction *> actions = Plasma::Containment::contextualActions();

    const KConfigGroup config = settings();
    QList<QAction *> enabled;
    for (const SortAction &entry : std::as_const(m_sortActions)) {
        if (config.readEntry(entry.configKey, true)) {
            enabled << entry.action;
        }
    }

    // No separator when every entry has been switched off in the settings.
    if (!enabled.isEmpty()) {
        actions << m_separator;
        actions << enabled;
    }
    return actions;
}

QString PanelSorter::buildScript(const QString &mode) const
{
    const QString libraryPath = scriptLibraryPath();
    if (libraryPath.isEmpty()) {
        qWarning() << "plasma-window-sorter: sorter.js not found; is the package installed?";
        return QString();
    }

    QFile library(libraryPath);
    if (!library.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "plasma-window-sorter: cannot read" << libraryPath << library.errorString();
        return QString();
    }
    const QByteArray body = library.readAll();

    const KConfigGroup config = settings();
    const bool includeMinimized = config.readEntry("IncludeMinimized", false);
    const double targetAspect = config.readEntry("TargetAspect", 4.0 / 3.0);
    const bool debug = config.readEntry("Debug", false);

    // The panel knows which screen it is on, so right-clicking a panel sorts
    // that screen's windows even when the pointer has wandered elsewhere.
    const QRectF geometry = screenGeometry();

    QString header = QStringLiteral("var PWS_MODE = \"%1\";\n").arg(mode);
    header += QStringLiteral("var PWS_OUTPUT_NAME = \"\";\n");
    if (geometry.isValid()) {
        header += QStringLiteral("var PWS_OUTPUT_RECT = { x: %1, y: %2, width: %3, height: %4 };\n")
                      .arg(geometry.x())
                      .arg(geometry.y())
                      .arg(geometry.width())
                      .arg(geometry.height());
    } else {
        header += QStringLiteral("var PWS_OUTPUT_RECT = null;\n");
    }
    header += QStringLiteral("var PWS_INCLUDE_MINIMIZED = %1;\n").arg(jsBool(includeMinimized));
    header += QStringLiteral("var PWS_TARGET_ASPECT = %1;\n").arg(targetAspect);
    header += QStringLiteral("var PWS_DEBUG = %1;\n").arg(jsBool(debug));

    QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtimeDir.isEmpty()) {
        runtimeDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QDir().mkpath(runtimeDir);

    const QString path = QStringLiteral("%1/plasma-window-sorter-%2-%3.js").arg(runtimeDir, mode).arg(QDateTime::currentMSecsSinceEpoch());
    QFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        qWarning() << "plasma-window-sorter: cannot write" << path << out.errorString();
        return QString();
    }
    out.write(header.toUtf8());
    out.write(body);
    out.close();

    return path;
}

void PanelSorter::sortWindows(const QString &mode)
{
    const QString scriptPath = buildScript(mode);
    if (scriptPath.isEmpty()) {
        return;
    }

    // A fresh plugin name per run: KWin caches a script under its name, and we
    // want it to read the parameters we just wrote.
    const QString pluginName = QStringLiteral("plasma-window-sorter-%1-%2").arg(mode).arg(QDateTime::currentMSecsSinceEpoch());

    auto *kwin = new QDBusInterface(QStringLiteral("org.kde.KWin"),
                                    QStringLiteral("/Scripting"),
                                    QStringLiteral("org.kde.kwin.Scripting"),
                                    QDBusConnection::sessionBus(),
                                    this);

    const auto cleanUp = [kwin, pluginName, scriptPath] {
        kwin->asyncCall(QStringLiteral("unloadScript"), pluginName);
        QFile::remove(scriptPath);
        kwin->deleteLater();
    };

    auto *loadWatcher = new QDBusPendingCallWatcher(kwin->asyncCall(QStringLiteral("loadScript"), scriptPath, pluginName), this);
    connect(loadWatcher, &QDBusPendingCallWatcher::finished, this, [kwin, scriptPath, cleanUp](QDBusPendingCallWatcher *watcher) {
        watcher->deleteLater();
        const QDBusPendingReply<int> reply = *watcher;
        if (reply.isError()) {
            qWarning() << "plasma-window-sorter: KWin refused the script:" << reply.error().message();
            QFile::remove(scriptPath);
            kwin->deleteLater();
            return;
        }

        auto *startWatcher = new QDBusPendingCallWatcher(kwin->asyncCall(QStringLiteral("start")), kwin);
        QObject::connect(startWatcher, &QDBusPendingCallWatcher::finished, kwin, [kwin, cleanUp](QDBusPendingCallWatcher *watcher) {
            watcher->deleteLater();
            // start() returns once the script has run; give KWin a moment to
            // settle the new geometries before unloading it again.
            QTimer::singleShot(2000, kwin, cleanUp);
        });
    });
}

K_PLUGIN_CLASS_WITH_JSON(PanelSorter, "metadata.json")

#include "panelsorter.moc"
