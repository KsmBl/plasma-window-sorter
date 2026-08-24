# System Settings module for the panel's window sorting entries
#
# SPDX-License-Identifier: GPL-2.0-or-later

kcmutils_add_qml_kcm(kcm_windowsorter SOURCES
    kcm.cpp
    applicationsmodel.cpp
    customactionsmodel.cpp
)

kconfig_add_kcfg_files(kcm_windowsorter windowsortersettings.kcfgc GENERATE_MOC)

target_link_libraries(kcm_windowsorter PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    KF6::ConfigGui
    KF6::CoreAddons
    KF6::I18n
    KF6::KCMUtils
    KF6::KCMUtilsQuick
    KF6::Service
)
