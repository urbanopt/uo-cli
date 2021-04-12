cmake_minimum_required(VERSION 3.10.2)
cmake_policy(SET CMP0048 NEW)

project(UrbanOptCLI VERSION 0.5.1)

include(FindOpenStudioSDK.cmake)

get_target_property(os_cli_location openstudio::openstudio LOCATION)
set(os_cli_install_name "openstudio${CMAKE_EXECUTABLE_SUFFIX}")

# Set a default build type if none was specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release"
    "MinSizeRel" "RelWithDebInfo")
endif()

if ( APPLE )
  find_library(SECURITY_FRAMEWORK Security)
endif()

include(ExternalProject)
include(CPackComponent)

###############################################################################
#                       P R O J E C T    V E R S I O N                        #
###############################################################################
# Project version information

set(PROJECT_VERSION_BUILD "Unknown" CACHE STRING "Build number") # git sha
find_package(Git)

if(NOT GIT_FOUND)
  find_program(GIT_EXECUTABLE git HINTS "$ENV{LOCALAPPDATA}/Programs/git/bin" "C:/Program Files/Git/bin")
  if(NOT GIT_EXECUTABLE_NOTFOUND)
    set(GIT_FOUND TRUE)
  endif()
endif()

if(GIT_FOUND)
  execute_process(COMMAND "${GIT_EXECUTABLE}" "rev-parse" "--short=10" "HEAD"
                  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                  TIMEOUT 10
                  RESULT_VARIABLE RESULT
                  OUTPUT_VARIABLE GIT_VERSION
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(${RESULT} EQUAL 0 AND NOT "${GIT_VERSION}" EQUAL "${PROJECT_VERSION_BUILD}")
    set(PROJECT_VERSION_BUILD ${GIT_VERSION} CACHE STRING "Build number" FORCE) # git sha
  endif()

  get_filename_component(GIT_DIR "${GIT_EXECUTABLE}" DIRECTORY)
else()
  set(GIT_DIR "")
endif()

# UrbanOpt version: Allows to add a pre1 tag as needed.
set(URBANOPT_CLI_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
# TODO JM 2019-07-12: Comment out (or delete) if prerelease tag not needed
set(URBANOPT_CLI_PRERELEASE_TAG "")
if (NOT "${URBANOPT_CLI_PRERELEASE_TAG}" STREQUAL "")
  message(STATUS "We have a prerelease tag set to '${URBANOPT_CLI_PRERELEASE_TAG}'")
  set(URBANOPT_CLI_VERSION "${URBANOPT_CLI_VERSION}-${URBANOPT_CLI_PRERELEASE_TAG}")
else()
  message(STATUS "We do not have a prerelease tag")
endif()
set(URBANOPT_CLI_LONG_VERSION "${URBANOPT_CLI_VERSION}.${PROJECT_VERSION_BUILD}")
message(STATUS "URBANOPT_CLI_VERSION=${URBANOPT_CLI_VERSION}")
message(STATUS "URBANOPT_CLI_LONG_VERSION=${URBANOPT_CLI_LONG_VERSION}")


###############################################################################
#                         B U I L D    O P T I O N S                          #
###############################################################################

option(BUILD_PACKAGE "Build package" OFF)



###############################################################################
#                           D E P E N D E N C I E S                           #
###############################################################################

# Required dependencies

# CI will build and upload urbanopt-cli-gems to s3 at (TBD)
# need to  update the MD5sum for each platform and url below
if(UNIX)
   if(APPLE)
     set(URBANOPT_CLI_GEMS_ZIP_FILENAME "urbanopt-cli-gems-20210315-darwin.tar.gz")
     set(URBANOPT_CLI_GEMS_ZIP_EXPECTED_MD5 "5df336da22c90534c8940c41e6489b37")
   else()
     set(URBANOPT_CLI_GEMS_ZIP_FILENAME "urbanopt-cli-gems-20210315-linux.tar.gz")
     set(URBANOPT_CLI_GEMS_ZIP_EXPECTED_MD5 "6e92becdac2d67046340daf16faea8b2")
   endif()
elseif(WIN32)
  if(CMAKE_CL_64)
    set(URBANOPT_CLI_GEMS_ZIP_FILENAME "urbanopt-cli-gems-20210315-windows.tar.gz")
    set(URBANOPT_CLI_GEMS_ZIP_EXPECTED_MD5 "be2cde77dde2891d8111454bb280bbdc")
  endif()
endif()

set(URBANOPT_CLI_GEMS_ZIP_LOCAL_PATH "${PROJECT_BINARY_DIR}/${URBANOPT_CLI_GEMS_ZIP_FILENAME}")
set(URBANOPT_CLI_GEMS_DIR "${PROJECT_BINARY_DIR}/urbanopt-cli-gems")
if(EXISTS "${URBANOPT_CLI_GEMS_ZIP_LOCAL_PATH}")
  file(MD5 "${URBANOPT_CLI_GEMS_ZIP_LOCAL_PATH}" URBANOPT_CLI_GEMS_ZIP_MD5)
endif()

if(NOT URBANOPT_CLI_GEMS_ZIP_MD5 STREQUAL URBANOPT_CLI_GEMS_ZIP_EXPECTED_MD5)
  message(STATUS "Downloading UrbanOpt-CLI Gems: ${URBANOPT_CLI_GEMS_ZIP_FILENAME}")
  file(DOWNLOAD "https://urbanopt-cli-resources.s3-us-west-2.amazonaws.com/gems/${URBANOPT_CLI_GEMS_ZIP_FILENAME}"
    ${URBANOPT_CLI_GEMS_ZIP_LOCAL_PATH}
    INACTIVITY_TIMEOUT 300 # 5 minute timeout
    SHOW_PROGRESS
    EXPECTED_MD5 ${URBANOPT_CLI_GEMS_ZIP_EXPECTED_MD5})
#  file(REMOVE_RECURSE "${URBANOPT_CLI_GEMS_DIR}")
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xfz ${URBANOPT_CLI_GEMS_ZIP_LOCAL_PATH} WORKING_DIRECTORY "${PROJECT_BINARY_DIR}")

endif()


set(RUBY_DIR "${PROJECT_BINARY_DIR}/ruby")

if(UNIX)
   if(APPLE)
     set(RUBY_ZIP_FILENAME "ruby-2.5.5-darwin.tar.gz")
     set(RUBY_ZIP_EXPECTED_MD5 "27e3e91bd19f4edf1c04d31c7345ce5d")
   else()
     set(RUBY_ZIP_FILENAME "ruby-2.5.5-linux.tar.gz")
     set(RUBY_ZIP_EXPECTED_MD5 "5c9ab1aeb3366e6e579592cbb72ddbef")
   endif()
elseif(WIN32)
     set(RUBY_ZIP_FILENAME "ruby-2.5.1-win32.tar.gz")
     set(RUBY_ZIP_EXPECTED_MD5 "96495c32f5933250663df7561fdd6226")
endif()

set(RUBY_ZIP_LOCAL_PATH "${PROJECT_BINARY_DIR}/${RUBY_ZIP_FILENAME}")
set(RUBY_DIR "${PROJECT_BINARY_DIR}/ruby")

if(EXISTS "${RUBY_ZIP_LOCAL_PATH}")
  file(MD5 "${RUBY_ZIP_LOCAL_PATH}" RUBY_ZIP_MD5)
endif()

if(NOT RUBY_ZIP_MD5 STREQUAL RUBY_ZIP_EXPECTED_MD5)
  message(STATUS "Downloading Ruby: ${RUBY_ZIP_FILENAME}")
  file(DOWNLOAD "https://urbanopt-cli-resources.s3-us-west-2.amazonaws.com/ruby/${RUBY_ZIP_FILENAME}"
    ${RUBY_ZIP_LOCAL_PATH}
    INACTIVITY_TIMEOUT 300 # 5 minute timeout
    SHOW_PROGRESS
    EXPECTED_MD5 ${RUBY_ZIP_EXPECTED_MD5})

  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xfz ${RUBY_ZIP_LOCAL_PATH} WORKING_DIRECTORY "${PROJECT_BINARY_DIR}")
endif()




###############################################################################
#                              I N S T A L L E R                              #
###############################################################################

######### Install SDK dependencies here ################

install(DIRECTORY "${OPENSTUDIO_SDK_PATH}/" DESTINATION "OpenStudio" COMPONENT "OpenStudio" USE_SOURCE_PERMISSIONS)
#install(DIRECTORY "${URBANOPT_CLI_GEMS_DIR}/" DESTINATION ".gems" COMPONENT "UrbanOpt" USE_SOURCE_PERMISSIONS)


if(UNIX)
  install(PROGRAMS ${PROJECT_SOURCE_DIR}/scripts/setup-env-unix.sh DESTINATION "." COMPONENT "UrbanOpt" RENAME "setup-env.sh")
elseif(WIN32)
  install(PROGRAMS ${PROJECT_SOURCE_DIR}/scripts/setup-env-gitbash.sh DESTINATION "." COMPONENT "UrbanOpt" RENAME "setup-env.sh")
  install(PROGRAMS ${PROJECT_SOURCE_DIR}/scripts/setup-env.ps1 DESTINATION "." COMPONENT "UrbanOpt")
  install(PROGRAMS ${PROJECT_SOURCE_DIR}/scripts/setup-env.bat DESTINATION "." COMPONENT "UrbanOpt")
endif()

install(DIRECTORY "${PROJECT_BINARY_DIR}/ruby" DESTINATION "." COMPONENT "Ruby" USE_SOURCE_PERMISSIONS)
install(DIRECTORY "${PROJECT_BINARY_DIR}/urbanopt-cli-gems/" DESTINATION "gems" COMPONENT "UrbanOpt" USE_SOURCE_PERMISSIONS)

#if(WIN32)
#  install(PROGRAMS "${OPENSTUDIO_SDK_PATH}/bin/install_utility.exe" DESTINATION bin COMPONENT "CLI")
#else()
#  install(PROGRAMS "${OPENSTUDIO_SDK_PATH}/bin/install_utility" DESTINATION bin COMPONENT "CLI")
#endif()


set(CPACK_PACKAGE_VENDOR "National Renewable Energy Laboratory")
# These are ok, even if we have a prerelease tag
set(CPACK_PACKAGE_VERSION_MAJOR ${URBANOPT_CLI_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${URBANOPT_CLI_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${URBANOPT_CLI_VERSION_PATCH})

# TODO:/URBANOPT_CLI_VERSION
# CPACK_DEBIAN_PACKAGE_DESCRIPTION defaults to this one too. dpkg-deb -I xxx.deb will show this description
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "UrbanOptCLI ${URBANOPT_CLI_VERSION} is a CLI software tool to support whole building energy modeling using EnergyPlus and advanced daylight analysis using Radiance")

# The actual package file name on disk
set(CPACK_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${URBANOPT_CLI_LONG_VERSION}-${CMAKE_SYSTEM_NAME}")
set(CPACK_PACKAGE_CONTACT "openstudio@nrel.gov")

# Install additional Documents, such as release notes
#install(FILES "${PROJECT_SOURCE_DIR}/LICENSE.md" DESTINATION .)

if (APPLE)
  #set(CPACK_IFW_TARGET_DIRECTORY "/Applications/UrbanOpt-cli-${URBANOPT_CLI_VERSION}")
  set(CPACK_IFW_TARGET_DIRECTORY "/Applications/UrbanOptCLI_${URBANOPT_CLI_VERSION}/")
elseif(UNIX)

  # For debug
  # set(CPACK_DEBIAN_PACKAGE_DEBUG ON)

  # These two will set the .deb install path correctly
   # ubuntu (18.04) uses libqdbm14
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqdbm14,sqlite3")
  set(CPACK_SET_DESTDIR ON)
  set(CPACK_INSTALL_PREFIX /usr/local/urbanopt-cli-${URBANOPT_CLI_VERSION})

  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "openstudio@nrel.gov")
  # Default the debian package name to include version to allow several versions to be installed concurrently instead of overwriting any existing one
  set(CPACK_DEBIAN_PACKAGE_NAME "urbanopt-cli-${URBANOPT_CLI_VERSION}")
  set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://www.openstudio.net")

  #set(POSTINST_FILE "${PROJECT_BINARY_DIR}/postinst")
  #set(POSTRM_FILE "${PROJECT_BINARY_DIR}/postrm")
  #configure_file(${PROJECT_SOURCE_DIR}/debian/postinst.in ${POSTINST_FILE} @ONLY)
  #configure_file(${PROJECT_SOURCE_DIR}/debian/postrm.in ${POSTRM_FILE} @ONLY)
  #execute_process(COMMAND chmod 755 "${POSTINST_FILE}")
  #execute_process(COMMAND chmod 755 "${POSTRM_FILE}")

  #TODO
  # install(FILES "${PROJECT_SOURCE_DIR}/src/openstudio_app/x-openstudio.xml" DESTINATION /usr/share/mime/application)
  #install(FILES "${PROJECT_SOURCE_DIR}/src/openstudio_app/x-openstudio.xml" DESTINATION Temp/)

  set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${CPACK_DEBIAN_BIN_PACKAGE_CONTROL_EXTRA};${POSTINST_FILE};${POSTRM_FILE}")

elseif(WIN32)
  set(CPACK_PACKAGE_INSTALL_DIRECTORY "UrbanOpt-cli-${URBANOPT_CLI_VERSION}")
  set(CPACK_IFW_TARGET_DIRECTORY "C:/${CPACK_PACKAGE_INSTALL_DIRECTORY}")
  set(CPACK_BINARY_IFW ON CACHE BOOL "Enable to build IFW packages")
  set(CPACK_BINARY_NSIS OFF CACHE BOOL "Enable to build NSIS packages")
endif()

include(CPackIFW)

cpack_add_component(UrbanOpt
  DISPLAY_NAME "UrbanOpt CLI"
  DESCRIPTION "UrbanOpt CLI software tool"
)

cpack_add_component(OpenStudio
  DISPLAY_NAME "OpenStudio SDK"
  DESCRIPTION "OpenStudio SDK"
)

cpack_ifw_configure_component(UrbanOpt
  REQUIRES_ADMIN_RIGHTS
)

cpack_ifw_configure_component(OpenStudio
#  SCRIPT src/openstudio_app/install_operations.qs
  REQUIRES_ADMIN_RIGHTS
)

include(CPack)

