# weftplate — ESP32-C6 Matter dry-contact sensor board, over Thread or Wi-Fi.
#
# Builds against the esp-matter checkout at $ESP_MATTER_PATH (pre-installed in the
# espressif/esp-matter Docker image). This mirrors the boilerplate from
# esp-matter/examples/*/CMakeLists.txt — the device-HAL and connectedhomeip
# component dirs must be wired in exactly this order for cmake to work.
cmake_minimum_required(VERSION 3.16)

if(NOT DEFINED ENV{ESP_MATTER_PATH})
    message(FATAL_ERROR "Please set ESP_MATTER_PATH to the path of the esp-matter repo")
endif()

if(NOT DEFINED ENV{ESP_MATTER_DEVICE_PATH})
    if("${IDF_TARGET}" STREQUAL "esp32c6")
        set(ENV{ESP_MATTER_DEVICE_PATH} $ENV{ESP_MATTER_PATH}/device_hal/device/esp32c6_devkit_c)
    else()
        # Default to the C6 device HAL; this firmware targets the ESP32-C6.
        set(ENV{ESP_MATTER_DEVICE_PATH} $ENV{ESP_MATTER_PATH}/device_hal/device/esp32c6_devkit_c)
    endif()
endif()

# Transport: passed by build.sh via -D WEFTPLATE_TRANSPORT=thread|wifi. Default
# thread. Layers transport/<transport>.defaults over the common sdkconfig.defaults.
# Each transport gets its own generated sdkconfig, because ESP-IDF only applies
# defaults to settings an existing sdkconfig doesn't already have.
if(NOT DEFINED WEFTPLATE_TRANSPORT)
    set(WEFTPLATE_TRANSPORT thread)
endif()
if(NOT WEFTPLATE_TRANSPORT MATCHES "^(thread|wifi)$")
    message(FATAL_ERROR "WEFTPLATE_TRANSPORT must be thread or wifi (got '${WEFTPLATE_TRANSPORT}')")
endif()
set(SDKCONFIG_DEFAULTS
    "${CMAKE_CURRENT_LIST_DIR}/sdkconfig.defaults"
    "${CMAKE_CURRENT_LIST_DIR}/transport/${WEFTPLATE_TRANSPORT}.defaults")
set(SDKCONFIG "${CMAKE_BINARY_DIR}/sdkconfig.${WEFTPLATE_TRANSPORT}")
message(STATUS "weftplate: building for Matter over ${WEFTPLATE_TRANSPORT}")

set(ESP_MATTER_PATH $ENV{ESP_MATTER_PATH})
set(MATTER_SDK_PATH ${ESP_MATTER_PATH}/connectedhomeip/connectedhomeip)

# Must come before using IDF_TARGET.
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
include(${ESP_MATTER_PATH}/examples/common/cmake_common/components_include.cmake)
include($ENV{ESP_MATTER_DEVICE_PATH}/esp_matter_device.cmake)

set(EXTRA_COMPONENT_DIRS
    "${ESP_MATTER_PATH}/examples/common"
    "${MATTER_SDK_PATH}/config/esp32/components"
    "${ESP_MATTER_PATH}/components"
    "${ESP_MATTER_PATH}/device_hal/device"
    ${extra_components_dirs_append})

# CHIP/connectedhomeip needs C++17 and its config define.
idf_build_set_property(CXX_COMPILE_OPTIONS
    "-std=gnu++17;-Os;-DCHIP_HAVE_CONFIG_H;-Wno-overloaded-virtual" APPEND)
idf_build_set_property(C_COMPILE_OPTIONS "-Os" APPEND)
# RISC-V (C6) format-warning flags, matching the esp-matter examples.
idf_build_set_property(COMPILE_OPTIONS "-Wno-format-nonliteral;-Wno-format-security" APPEND)

project(weftplate)
