/*
    plasma-window-sorter - System Settings module

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

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

            ColumnLayout {
                Kirigami.FormData.label: i18nc("@label", "Extra entries:")
                Kirigami.FormData.labelAlignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: kcm.customActions

                    delegate: RowLayout {
                        id: entryRow

                        required property int index
                        required property string name
                        required property string iconName
                        required property string command

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: entryRow.iconName
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }

                        ColumnLayout {
                            // preferredWidth 0 lets the labels elide instead of
                            // pushing the buttons out of the page.
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            spacing: 0

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: entryRow.name
                                elide: Text.ElideRight
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: entryRow.command
                                elide: Text.ElideMiddle
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                        }

                        QQC2.ToolButton {
                            icon.name: "go-up"
                            enabled: entryRow.index > 0
                            display: QQC2.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Move up")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            onClicked: kcm.customActions.move(entryRow.index, -1)
                        }

                        QQC2.ToolButton {
                            icon.name: "go-down"
                            enabled: entryRow.index < kcm.customActions.count - 1
                            display: QQC2.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Move down")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            onClicked: kcm.customActions.move(entryRow.index, 1)
                        }

                        QQC2.ToolButton {
                            icon.name: "edit-delete-remove"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Remove")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            onClicked: kcm.customActions.remove(entryRow.index)
                        }
                    }
                }

                QQC2.Label {
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                    visible: kcm.customActions.count === 0
                    text: i18nc("@info", "Nothing yet. Add an application, and it turns up in the panel's context menu.")
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        icon.name: "list-add"
                        text: i18nc("@action:button", "Add Application…")
                        onClicked: applicationSheet.open()
                    }

                    QQC2.Button {
                        icon.name: "utilities-terminal"
                        text: i18nc("@action:button", "Add Command…")
                        onClicked: commandSheet.open()
                    }
                }
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

    Kirigami.Dialog {
        id: applicationSheet

        title: i18nc("@title:window", "Add Application")
        preferredWidth: Kirigami.Units.gridUnit * 24
        preferredHeight: Kirigami.Units.gridUnit * 22
        standardButtons: QQC2.Dialog.Cancel

        onOpened: {
            kcm.applications.filter = "";
            applicationSearch.text = "";
            applicationSearch.forceActiveFocus();
        }

        header: ColumnLayout {
            spacing: 0

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                text: applicationSheet.title
                level: 2
            }

            Kirigami.SearchField {
                id: applicationSearch
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                onTextChanged: kcm.applications.filter = text
            }
        }

        ListView {
            id: applicationList
            model: kcm.applications
            clip: true
            implicitWidth: Kirigami.Units.gridUnit * 24
            implicitHeight: Kirigami.Units.gridUnit * 18

            delegate: QQC2.ItemDelegate {
                id: applicationDelegate

                required property string name
                required property string iconName
                required property string storageId
                required property string comment

                width: ListView.view.width
                icon.name: applicationDelegate.iconName
                text: applicationDelegate.name

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: applicationDelegate.iconName
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: applicationDelegate.name
                            elide: Text.ElideRight
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: applicationDelegate.comment
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }

                onClicked: {
                    kcm.customActions.addApplication(applicationDelegate.storageId);
                    applicationSheet.close();
                }
            }
        }
    }

    Kirigami.Dialog {
        id: commandSheet

        title: i18nc("@title:window", "Add Command")
        preferredWidth: Kirigami.Units.gridUnit * 24
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        property string chosenIcon: "application-x-executable"

        onOpened: {
            commandName.text = "";
            commandLine.text = "";
            chosenIcon = "application-x-executable";
            commandName.forceActiveFocus();
        }

        onAccepted: {
            kcm.customActions.addCommand(commandName.text, commandLine.text, chosenIcon);
        }

        Kirigami.FormLayout {
            QQC2.TextField {
                id: commandName
                Kirigami.FormData.label: i18nc("@label:textbox", "Menu entry:")
                placeholderText: i18nc("@info:placeholder", "System Monitor")
            }

            QQC2.TextField {
                id: commandLine
                Kirigami.FormData.label: i18nc("@label:textbox", "Command:")
                placeholderText: i18nc("@info:placeholder", "plasma-systemmonitor")
            }

            QQC2.Button {
                Kirigami.FormData.label: i18nc("@label:chooser", "Icon:")
                icon.name: commandSheet.chosenIcon
                text: i18nc("@action:button", "Choose…")
                onClicked: iconChooser.open()
            }
        }

        KIconThemes.IconDialog {
            id: iconChooser
            onIconNameChanged: if (iconName.length > 0) {
                commandSheet.chosenIcon = iconName;
            }
        }
    }
}
