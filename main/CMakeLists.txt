idf_component_register(
    SRCS "app_main.cpp"
    INCLUDE_DIRS "."
)

# CHIP/connectedhomeip requires this define across esp-matter TUs.
target_compile_options(${COMPONENT_LIB} PRIVATE "-DCHIP_HAVE_CONFIG_H")

# Loop count: passed by build.sh via -D WEFTPLATE_NUM_LOOPS=N on the idf.py
# command line, which lands here as a CMake cache variable. Default 6.
# (EXTRA_CPPFLAGS does NOT reliably reach a component's compile, so we apply the
# define explicitly with target_compile_definitions.)
if(NOT DEFINED WEFTPLATE_NUM_LOOPS)
    set(WEFTPLATE_NUM_LOOPS 6)
endif()
target_compile_definitions(${COMPONENT_LIB} PRIVATE "WEFTPLATE_NUM_LOOPS=${WEFTPLATE_NUM_LOOPS}")
message(STATUS "weftplate: building for ${WEFTPLATE_NUM_LOOPS} loop(s)")
