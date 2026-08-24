/*
    plasma-window-sorter - System Settings module

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    implicitWidth: Kirigami.Units.gridUnit * 34

    readonly property bool nothingShown: !kcm.settings.showVertical
        && !kcm.settings.showHorizontal
        && !kcm.settings.showOptimal
        && !kcm.settings.showCascade

    // No anchors: SimpleKCM puts its children in a scroll view and lays them
    // out itself, so anchoring here would collapse the form to nothing.
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "With none of the entries ticked, the panel's context menu goes back to looking exactly as it did before.")
            visible: root.nothingShown
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                Kirigami.FormData.label: i18nc("@label", "Panel menu shows:")
                text: i18nc("@option:check sorting entry", "Sort Windows Vertically")
                checked: kcm.settings.showVertical
                onToggled: kcm.settings.showVertical = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "ShowVertical"
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "Full-width rows, stacked top to bottom.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            QQC2.CheckBox {
                text: i18nc("@option:check sorting entry", "Sort Windows Horizontally")
                checked: kcm.settings.showHorizontal
                onToggled: kcm.settings.showHorizontal = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "ShowHorizontal"
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "Full-height columns, side by side.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            QQC2.CheckBox {
                text: i18nc("@option:check sorting entry", "Sort Windows Optimally")
                checked: kcm.settings.showOptimal
                onToggled: kcm.settings.showOptimal = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "ShowOptimal"
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "An even grid that fills the screen.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            QQC2.CheckBox {
                text: i18nc("@option:check sorting entry", "Sort Windows Cascading")
                checked: kcm.settings.showCascade
                onToggled: kcm.settings.showCascade = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "ShowCascade"
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "One diagonal pile, every window the same size.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            Item {
                Kirigami.FormData.isSection: true
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18nc("@label", "Windows:")
                text: i18nc("@option:check", "Bring back minimized windows")
                checked: kcm.settings.includeMinimized
                onToggled: kcm.settings.includeMinimized = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "IncludeMinimized"
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "Off by default, so windows you put away stay away.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            QQC2.SpinBox {
                id: aspectBox
                Kirigami.FormData.label: i18nc("@label:spinbox", "Grid cell shape:")

                from: 50
                to: 300
                stepSize: 5
                value: Math.round(kcm.settings.targetAspect * 100)
                onValueModified: kcm.settings.targetAspect = value / 100
                textFromValue: (value, locale) => (value / 100).toLocaleString(locale, 'f', 2)
                valueFromText: (text, locale) => Math.round(Number.fromLocaleString(locale, text) * 100)

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "TargetAspect"
                    extraEnabledConditions: kcm.settings.showOptimal
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: i18nc("@info", "Width divided by height of a cell the optimal grid aims for. Higher means wider, flatter cells and therefore fewer rows.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
            }

            Item {
                Kirigami.FormData.isSection: true
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18nc("@label", "Diagnostics:")
                text: i18nc("@option:check", "Log every sort to the system journal")
                checked: kcm.settings.debug
                onToggled: kcm.settings.debug = checked

                KCM.SettingStateBinding {
                    configObject: kcm.settings
                    settingName: "Debug"
                }
            }
        }
    }
}
