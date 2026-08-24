# plasma-window-sorter
#
# Builds a drop-in replacement for Plasma's org.kde.panel containment: upstream
# QML (staged next to this file by install.sh) plus our Containment subclass.
#
# SPDX-License-Identifier: GPL-2.0-or-later

cmake_minimum_required(VERSION 3.20)

project(plasma-window-sorter VERSION 1.1.0)

set(QT_MIN_VERSION 6.7.0)
set(KF6_MIN_VERSION 6.0.0)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core DBus Gui Qml Quick)
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS Config CoreAddons I18n KCMUtils KIO Service)
find_package(Plasma REQUIRED)

# Same applet id, same QML module URI and same QML sources as the distribution
# package - only the plugin class differs, so this file can replace the
# original org.kde.panel.so.
# The QML is whatever install.sh staged next to this file (fetched to match the
# installed Plasma, or the vendored copy), so a new upstream file does not need
# a change here.
file(GLOB PWS_QML_ABS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.qml" "${CMAKE_CURRENT_SOURCE_DIR}/*.js")
file(GLOB PWS_RESOURCES_ABS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.xml")

set(PWS_QML_SOURCES "")
foreach(_file IN LISTS PWS_QML_ABS)
    file(RELATIVE_PATH _rel "${CMAKE_CURRENT_SOURCE_DIR}" "${_file}")
    list(APPEND PWS_QML_SOURCES "${_rel}")
endforeach()

set(PWS_RESOURCES "")
foreach(_file IN LISTS PWS_RESOURCES_ABS)
    file(RELATIVE_PATH _rel "${CMAKE_CURRENT_SOURCE_DIR}" "${_file}")
    list(APPEND PWS_RESOURCES "${_rel}")
endforeach()

if(NOT "main.qml" IN_LIST PWS_QML_SOURCES)
    message(FATAL_ERROR "No main.qml staged - the upstream panel sources are missing.")
endif()

message(STATUS "Panel QML sources: ${PWS_QML_SOURCES}")

plasma_add_applet(org.kde.panel
    QML_SOURCES
        ${PWS_QML_SOURCES}
    RESOURCES
        ${PWS_RESOURCES}
    CPP_SOURCES
        panelsorter.cpp
)

target_compile_definitions(org.kde.panel PRIVATE PWS_VERSION="${PROJECT_VERSION}")

target_link_libraries(org.kde.panel PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::DBus
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::I18n
    KF6::KIOGui
    KF6::Service
    Plasma::Plasma
)

# System Settings module: Window Management -> Window Sorting.
# Staged next to this file by install.sh; skipped when building the panel alone.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/kcm/CMakeLists.txt")
    add_subdirectory(kcm)
endif()
