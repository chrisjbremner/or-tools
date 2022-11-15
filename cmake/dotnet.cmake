# Copyright 2010-2022 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if(NOT BUILD_DOTNET)
  return()
endif()

if(NOT TARGET ${PROJECT_NAMESPACE}::ortools)
  message(FATAL_ERROR ".Net: missing ortools TARGET")
endif()

# Will need swig
set(CMAKE_SWIG_FLAGS)
find_package(SWIG REQUIRED)
include(UseSWIG)

#if(${SWIG_VERSION} VERSION_GREATER_EQUAL 4)
#  list(APPEND CMAKE_SWIG_FLAGS "-doxygen")
#endif()

if(UNIX AND NOT APPLE)
  list(APPEND CMAKE_SWIG_FLAGS "-DSWIGWORDSIZE64")
endif()

# Find dotnet cli
find_program(DOTNET_EXECUTABLE NAMES dotnet)
if(NOT DOTNET_EXECUTABLE)
  message(FATAL_ERROR "Check for dotnet Program: not found")
else()
  message(STATUS "Found dotnet Program: ${DOTNET_EXECUTABLE}")
endif()

# Needed by dotnet/CMakeLists.txt
set(DOTNET_PACKAGE Google.OrTools)
set(DOTNET_PACKAGES_DIR "${PROJECT_BINARY_DIR}/dotnet/packages")

# Runtime IDentifier
# see: https://docs.microsoft.com/en-us/dotnet/core/rid-catalog
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)")
  set(DOTNET_PLATFORM arm64)
else()
  set(DOTNET_PLATFORM x64)
endif()

if(APPLE)
  set(DOTNET_RID osx-${DOTNET_PLATFORM})
elseif(UNIX)
  set(DOTNET_RID linux-${DOTNET_PLATFORM})
elseif(WIN32)
  set(DOTNET_RID win-${DOTNET_PLATFORM})
else()
  message(FATAL_ERROR "Unsupported system !")
endif()
message(STATUS ".Net RID: ${DOTNET_RID}")

set(DOTNET_NATIVE_PROJECT ${DOTNET_PACKAGE}.runtime.${DOTNET_RID})
message(STATUS ".Net runtime project: ${DOTNET_NATIVE_PROJECT}")
set(DOTNET_NATIVE_PROJECT_DIR ${PROJECT_BINARY_DIR}/dotnet/${DOTNET_NATIVE_PROJECT})
message(STATUS ".Net runtime project build path: ${DOTNET_NATIVE_PROJECT_DIR}")

# Language Version
# see: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/configure-language-version
set(DOTNET_LANG "9.0")
message(STATUS ".Net C# language version: ${DOTNET_LANG}")

# Targeted Framework Moniker
# see: https://docs.microsoft.com/en-us/dotnet/standard/frameworks
# see: https://learn.microsoft.com/en-us/dotnet/standard/net-standard
if(USE_DOTNET_CORE_31)
  list(APPEND TFM "netcoreapp3.1")
endif()
if(USE_DOTNET_6)
  list(APPEND TFM "net6.0")
endif()

list(LENGTH TFM TFM_LENGTH)
if(TFM_LENGTH EQUAL "0")
  message(FATAL_ERROR "No .Net SDK selected !")
endif()

string(JOIN ";" DOTNET_TFM ${TFM})
message(STATUS ".Net TFM: ${DOTNET_TFM}")
if(TFM_LENGTH GREATER "1")
  string(CONCAT DOTNET_TFM "<TargetFrameworks>" "${DOTNET_TFM}" "</TargetFrameworks>")
else()
  string(CONCAT DOTNET_TFM "<TargetFramework>" "${DOTNET_TFM}" "</TargetFramework>")
endif()

set(DOTNET_PROJECT ${DOTNET_PACKAGE})
message(STATUS ".Net project: ${DOTNET_PROJECT}")
set(DOTNET_PROJECT_DIR ${PROJECT_BINARY_DIR}/dotnet/${DOTNET_PROJECT})
message(STATUS ".Net project build path: ${DOTNET_PROJECT_DIR}")

##################
##  PROTO FILE  ##
##################
# Generate Protobuf .Net sources
set(PROTO_DOTNETS)
file(GLOB_RECURSE proto_dotnet_files RELATIVE ${PROJECT_SOURCE_DIR}
  "ortools/bop/*.proto"
  "ortools/constraint_solver/*.proto"
  "ortools/glop/*.proto"
  "ortools/graph/*.proto"
  "ortools/linear_solver/*.proto"
  "ortools/sat/*.proto"
  "ortools/util/*.proto"
  )
if(USE_PDLP)
  file(GLOB_RECURSE pdlp_proto_dotnet_files RELATIVE ${PROJECT_SOURCE_DIR} "ortools/pdlp/*.proto")
  list(APPEND proto_dotnet_files ${pdlp_proto_dotnet_files})
endif()
list(REMOVE_ITEM proto_dotnet_files "ortools/constraint_solver/demon_profiler.proto")
list(REMOVE_ITEM proto_dotnet_files "ortools/constraint_solver/assignment.proto")
foreach(PROTO_FILE IN LISTS proto_dotnet_files)
  #message(STATUS "protoc proto(dotnet): ${PROTO_FILE}")
  get_filename_component(PROTO_DIR ${PROTO_FILE} DIRECTORY)
  get_filename_component(PROTO_NAME ${PROTO_FILE} NAME_WE)
  set(PROTO_DOTNET ${DOTNET_PROJECT_DIR}/${PROTO_DIR}/${PROTO_NAME}.pb.cs)
  #message(STATUS "protoc dotnet: ${PROTO_DOTNET}")
  add_custom_command(
    OUTPUT ${PROTO_DOTNET}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DOTNET_PROJECT_DIR}/${PROTO_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/dotnet/${PROTO_DIR}
    COMMAND ${PROTOC_PRG}
    "--proto_path=${PROJECT_SOURCE_DIR}"
    ${PROTO_DIRS}
    "--csharp_out=${DOTNET_PROJECT_DIR}/${PROTO_DIR}"
    "--csharp_opt=file_extension=.pb.cs"
    ${PROTO_FILE}
    DEPENDS ${PROTO_FILE} ${PROTOC_PRG}
    COMMENT "Generate C# protocol buffer for ${PROTO_FILE}"
    VERBATIM)
  list(APPEND PROTO_DOTNETS ${PROTO_DOTNET})
endforeach()
add_custom_target(Dotnet${PROJECT_NAME}_proto
  DEPENDS
    ${PROTO_DOTNETS}
    ${PROJECT_NAMESPACE}::ortools)

# Create the native library
add_library(google-ortools-native SHARED "")
set_target_properties(google-ortools-native PROPERTIES
  PREFIX ""
  POSITION_INDEPENDENT_CODE ON)
# note: macOS is APPLE and also UNIX !
if(APPLE)
  set_target_properties(google-ortools-native PROPERTIES INSTALL_RPATH "@loader_path")
  # Xcode fails to build if library doesn't contains at least one source file.
  if(XCODE)
    file(GENERATE
      OUTPUT ${PROJECT_BINARY_DIR}/google-ortools-native/version.cpp
      CONTENT "namespace {char* version = \"${PROJECT_VERSION}\";}")
    target_sources(google-ortools-native PRIVATE ${PROJECT_BINARY_DIR}/google-ortools-native/version.cpp)
  endif()
elseif(UNIX)
  set_target_properties(google-ortools-native PROPERTIES INSTALL_RPATH "$ORIGIN")
endif()

#################
##  .Net Test  ##
#################
if(BUILD_TESTING)
  # add_dotnet_test()
  # CMake function to generate and build dotnet test.
  # Parameters:
  #  the dotnet filename
  # e.g.:
  # add_dotnet_test(FooTests.cs)
  function(add_dotnet_test FILE_NAME)
    message(STATUS "Configuring test ${FILE_NAME} ...")
    get_filename_component(TEST_NAME ${FILE_NAME} NAME_WE)
    get_filename_component(WRAPPER_DIR ${FILE_NAME} DIRECTORY)
    get_filename_component(COMPONENT_DIR ${WRAPPER_DIR} DIRECTORY)
    get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

    set(DOTNET_TEST_DIR ${PROJECT_BINARY_DIR}/dotnet/${COMPONENT_NAME}/${TEST_NAME})
    message(STATUS "build path: ${DOTNET_TEST_DIR}")

    configure_file(
      ${PROJECT_SOURCE_DIR}/ortools/dotnet/Test.csproj.in
      ${DOTNET_TEST_DIR}/${TEST_NAME}.csproj
      @ONLY)

    add_custom_command(
      OUTPUT ${DOTNET_TEST_DIR}/${TEST_NAME}.cs
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DOTNET_TEST_DIR}
      COMMAND ${CMAKE_COMMAND} -E copy
      ${FILE_NAME}
      ${DOTNET_TEST_DIR}/
      MAIN_DEPENDENCY ${FILE_NAME}
      VERBATIM
      WORKING_DIRECTORY ${DOTNET_TEST_DIR})

    add_custom_command(
      OUTPUT ${DOTNET_TEST_DIR}/timestamp
      COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
        ${DOTNET_EXECUTABLE} build --nologo -c Release ${TEST_NAME}.csproj
      COMMAND ${CMAKE_COMMAND} -E touch ${DOTNET_TEST_DIR}/timestamp
      DEPENDS
      ${DOTNET_TEST_DIR}/${TEST_NAME}.csproj
      ${DOTNET_TEST_DIR}/${TEST_NAME}.cs
      dotnet_package
      BYPRODUCTS
      ${DOTNET_TEST_DIR}/bin
      ${DOTNET_TEST_DIR}/obj
      VERBATIM
      COMMENT "Compiling .Net ${COMPONENT_NAME}/${TEST_NAME}.cs (${DOTNET_TEST_DIR}/timestamp)"
      WORKING_DIRECTORY ${DOTNET_TEST_DIR})

    add_custom_target(dotnet_${COMPONENT_NAME}_${TEST_NAME} ALL
      DEPENDS
      ${DOTNET_TEST_DIR}/timestamp
      WORKING_DIRECTORY ${DOTNET_TEST_DIR})

    add_test(
      NAME dotnet_${COMPONENT_NAME}_${TEST_NAME}
      COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
        ${DOTNET_EXECUTABLE} test --nologo -c Release ${TEST_NAME}.csproj
      WORKING_DIRECTORY ${DOTNET_TEST_DIR})
    message(STATUS "Configuring test ${FILE_NAME} done")
  endfunction()
endif()

#######################
##  DOTNET WRAPPERS  ##
#######################
list(APPEND CMAKE_SWIG_FLAGS "-I${PROJECT_SOURCE_DIR}")

# Swig wrap all libraries
foreach(SUBPROJECT IN ITEMS algorithms graph init linear_solver constraint_solver sat util)
  add_subdirectory(ortools/${SUBPROJECT}/csharp)
  target_link_libraries(google-ortools-native PRIVATE dotnet_${SUBPROJECT})
endforeach()

file(COPY ${PROJECT_SOURCE_DIR}/tools/doc/orLogo.png DESTINATION ${PROJECT_BINARY_DIR}/dotnet)
set(DOTNET_LOGO_DIR "${PROJECT_BINARY_DIR}/dotnet")
configure_file(${PROJECT_SOURCE_DIR}/ortools/dotnet/Directory.Build.props.in ${PROJECT_BINARY_DIR}/dotnet/Directory.Build.props)

############################
##  .Net SNK file  ##
############################
# Build or retrieve .snk file
if(DEFINED ENV{DOTNET_SNK})
  add_custom_command(
    OUTPUT ${PROJECT_BINARY_DIR}/dotnet/or-tools.snk
    COMMAND ${CMAKE_COMMAND} -E copy $ENV{DOTNET_SNK} ${PROJECT_BINARY_DIR}/dotnet/or-tools.snk
    COMMENT "Copy or-tools.snk from ENV:DOTNET_SNK"
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    VERBATIM
    )
else()
  set(DOTNET_SNK_PROJECT CreateSigningKey)
  set(DOTNET_SNK_PROJECT_DIR ${PROJECT_BINARY_DIR}/dotnet/${DOTNET_SNK_PROJECT})
  add_custom_command(
    OUTPUT ${PROJECT_BINARY_DIR}/dotnet/or-tools.snk
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${PROJECT_SOURCE_DIR}/ortools/dotnet/${DOTNET_SNK_PROJECT}
      ${DOTNET_SNK_PROJECT}
    COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME ${DOTNET_EXECUTABLE} run
    --project ${DOTNET_SNK_PROJECT}/${DOTNET_SNK_PROJECT}.csproj
    /or-tools.snk
    BYPRODUCTS
      ${DOTNET_SNK_PROJECT_DIR}/bin
      ${DOTNET_SNK_PROJECT_DIR}/obj
    COMMENT "Generate or-tools.snk using CreateSigningKey project"
    WORKING_DIRECTORY dotnet
    VERBATIM
    )
endif()

file(MAKE_DIRECTORY ${DOTNET_PACKAGES_DIR})
############################
##  .Net Runtime Package  ##
############################
# *.csproj.in contains:
# CMake variable(s) (@PROJECT_NAME@) that configure_file() can manage and
# generator expression ($<TARGET_FILE:...>) that file(GENERATE) can manage.
configure_file(
  ${PROJECT_SOURCE_DIR}/ortools/dotnet/${DOTNET_PACKAGE}.runtime.csproj.in
  ${DOTNET_NATIVE_PROJECT_DIR}/${DOTNET_NATIVE_PROJECT}.csproj.in
  @ONLY)
file(GENERATE
  OUTPUT ${DOTNET_NATIVE_PROJECT_DIR}/$<CONFIG>/${DOTNET_NATIVE_PROJECT}.csproj.in
  INPUT ${DOTNET_NATIVE_PROJECT_DIR}/${DOTNET_NATIVE_PROJECT}.csproj.in)

add_custom_command(
  OUTPUT ${DOTNET_NATIVE_PROJECT_DIR}/${DOTNET_NATIVE_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E copy ./$<CONFIG>/${DOTNET_NATIVE_PROJECT}.csproj.in ${DOTNET_NATIVE_PROJECT}.csproj
  DEPENDS
    ${DOTNET_NATIVE_PROJECT_DIR}/$<CONFIG>/${DOTNET_NATIVE_PROJECT}.csproj.in
  WORKING_DIRECTORY ${DOTNET_NATIVE_PROJECT_DIR})

add_custom_command(
  OUTPUT ${DOTNET_NATIVE_PROJECT_DIR}/timestamp
  COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
    ${DOTNET_EXECUTABLE} build --nologo -c Release /p:Platform=${DOTNET_PLATFORM} ${DOTNET_NATIVE_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
    ${DOTNET_EXECUTABLE} pack --nologo -c Release ${DOTNET_NATIVE_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E touch ${DOTNET_NATIVE_PROJECT_DIR}/timestamp
  DEPENDS
    ${PROJECT_BINARY_DIR}/dotnet/Directory.Build.props
    ${DOTNET_NATIVE_PROJECT_DIR}/${DOTNET_NATIVE_PROJECT}.csproj
    ${PROJECT_BINARY_DIR}/dotnet/or-tools.snk
    Dotnet${PROJECT_NAME}_proto
    google-ortools-native
  BYPRODUCTS
    ${DOTNET_NATIVE_PROJECT_DIR}/bin
    ${DOTNET_NATIVE_PROJECT_DIR}/obj
  VERBATIM
  COMMENT "Generate .Net native package ${DOTNET_NATIVE_PROJECT} (${DOTNET_NATIVE_PROJECT_DIR}/timestamp)"
  WORKING_DIRECTORY ${DOTNET_NATIVE_PROJECT_DIR})

add_custom_target(dotnet_native_package
  DEPENDS
    ${DOTNET_NATIVE_PROJECT_DIR}/timestamp
  WORKING_DIRECTORY ${DOTNET_NATIVE_PROJECT_DIR})

####################
##  .Net Package  ##
####################
if(UNIVERSAL_DOTNET_PACKAGE)
  configure_file(
    ${PROJECT_SOURCE_DIR}/ortools/dotnet/${DOTNET_PROJECT}-full.csproj.in
    ${DOTNET_PROJECT_DIR}/${DOTNET_PROJECT}.csproj.in
    @ONLY)
else()
  configure_file(
    ${PROJECT_SOURCE_DIR}/ortools/dotnet/${DOTNET_PROJECT}-local.csproj.in
    ${DOTNET_PROJECT_DIR}/${DOTNET_PROJECT}.csproj.in
    @ONLY)
endif()

add_custom_command(
  OUTPUT ${DOTNET_PROJECT_DIR}/${DOTNET_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E copy ${DOTNET_PROJECT}.csproj.in ${DOTNET_PROJECT}.csproj
  DEPENDS
    ${DOTNET_PROJECT_DIR}/${DOTNET_PROJECT}.csproj.in
  WORKING_DIRECTORY ${DOTNET_PROJECT_DIR})

add_custom_command(
  OUTPUT ${DOTNET_PROJECT_DIR}/timestamp
  COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
    ${DOTNET_EXECUTABLE} build --nologo -c Release /p:Platform=${DOTNET_PLATFORM} ${DOTNET_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
    ${DOTNET_EXECUTABLE} pack --nologo -c Release ${DOTNET_PROJECT}.csproj
  COMMAND ${CMAKE_COMMAND} -E touch ${DOTNET_PROJECT_DIR}/timestamp
  DEPENDS
    ${PROJECT_BINARY_DIR}/dotnet/or-tools.snk
    ${DOTNET_PROJECT_DIR}/${DOTNET_PROJECT}.csproj
    Dotnet${PROJECT_NAME}_proto
    ${DOTNET_NATIVE_PROJECT_DIR}/timestamp
    dotnet_native_package
  BYPRODUCTS
    ${DOTNET_PROJECT_DIR}/bin
    ${DOTNET_PROJECT_DIR}/obj
  VERBATIM
  COMMENT "Generate .Net package ${DOTNET_PROJECT} (${DOTNET_PROJECT_DIR}/timestamp)"
  WORKING_DIRECTORY ${DOTNET_PROJECT_DIR})

add_custom_target(dotnet_package ALL
  DEPENDS
    ${DOTNET_PROJECT_DIR}/timestamp
  WORKING_DIRECTORY ${DOTNET_PROJECT_DIR})

###################
##  .Net Sample  ##
###################
# add_dotnet_sample()
# CMake function to generate and build dotnet sample.
# Parameters:
#  the dotnet filename
# e.g.:
# add_dotnet_sample(FooApp.cs)
function(add_dotnet_sample FILE_NAME)
  message(STATUS "Configuring sample ${FILE_NAME} ...")
  get_filename_component(SAMPLE_NAME ${FILE_NAME} NAME_WE)
  get_filename_component(SAMPLE_DIR ${FILE_NAME} DIRECTORY)
  get_filename_component(COMPONENT_DIR ${SAMPLE_DIR} DIRECTORY)
  get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

  set(DOTNET_SAMPLE_DIR ${PROJECT_BINARY_DIR}/dotnet/${COMPONENT_NAME}/${SAMPLE_NAME})
  message(STATUS "build path: ${DOTNET_SAMPLE_DIR}")

  configure_file(
    ${PROJECT_SOURCE_DIR}/ortools/dotnet/Sample.csproj.in
    ${DOTNET_SAMPLE_DIR}/${SAMPLE_NAME}.csproj
    @ONLY)

  add_custom_command(
    OUTPUT ${DOTNET_SAMPLE_DIR}/${SAMPLE_NAME}.cs
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DOTNET_SAMPLE_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${FILE_NAME}
      ${DOTNET_SAMPLE_DIR}/
    MAIN_DEPENDENCY ${FILE_NAME}
    VERBATIM
    WORKING_DIRECTORY ${DOTNET_SAMPLE_DIR})

  add_custom_command(
    OUTPUT ${DOTNET_SAMPLE_DIR}/timestamp
    COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
      ${DOTNET_EXECUTABLE} build --nologo -c Release
    COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
      ${DOTNET_EXECUTABLE} pack --nologo -c Release
    COMMAND ${CMAKE_COMMAND} -E touch ${DOTNET_SAMPLE_DIR}/timestamp
    DEPENDS
      ${DOTNET_SAMPLE_DIR}/${SAMPLE_NAME}.csproj
      ${DOTNET_SAMPLE_DIR}/${SAMPLE_NAME}.cs
      dotnet_package
    BYPRODUCTS
      ${DOTNET_SAMPLE_DIR}/bin
      ${DOTNET_SAMPLE_DIR}/obj
    COMMENT "Compiling .Net ${COMPONENT_NAME}/${SAMPLE_NAME}.cs (${DOTNET_SAMPLE_DIR}/timestamp)"
    WORKING_DIRECTORY ${DOTNET_SAMPLE_DIR})

  add_custom_target(dotnet_${COMPONENT_NAME}_${SAMPLE_NAME} ALL
    DEPENDS
      ${DOTNET_SAMPLE_DIR}/timestamp
    WORKING_DIRECTORY ${DOTNET_SAMPLE_DIR})

  if(BUILD_TESTING)
    if(USE_DOTNET_CORE_31)
      add_test(
        NAME dotnet_${COMPONENT_NAME}_${SAMPLE_NAME}_netcoreapp31
        COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
          ${DOTNET_EXECUTABLE} run --framework netcoreapp3.1 -c Release
        WORKING_DIRECTORY ${DOTNET_SAMPLE_DIR})
    endif()
    if(USE_DOTNET_6)
      add_test(
        NAME dotnet_${COMPONENT_NAME}_${SAMPLE_NAME}_net60
        COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
          ${DOTNET_EXECUTABLE} run --no-build --framework net6.0 -c Release
        WORKING_DIRECTORY ${DOTNET_SAMPLE_DIR})
    endif()
  endif()
  message(STATUS "Configuring sample ${FILE_NAME} done")
endfunction()

####################
##  .Net Example  ##
####################
# add_dotnet_example()
# CMake function to generate and build dotnet example.
# Parameters:
#  the dotnet filename
# e.g.:
# add_dotnet_example(Foo.cs)
function(add_dotnet_example FILE_NAME)
  message(STATUS "Configuring example ${FILE_NAME} ...")
  get_filename_component(EXAMPLE_NAME ${FILE_NAME} NAME_WE)
  get_filename_component(COMPONENT_DIR ${FILE_NAME} DIRECTORY)
  get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

  set(DOTNET_EXAMPLE_DIR ${PROJECT_BINARY_DIR}/dotnet/${COMPONENT_NAME}/${EXAMPLE_NAME})
  message(STATUS "build path: ${DOTNET_EXAMPLE_DIR}")

  set(SAMPLE_NAME ${EXAMPLE_NAME})
  configure_file(
    ${PROJECT_SOURCE_DIR}/ortools/dotnet/Sample.csproj.in
    ${DOTNET_EXAMPLE_DIR}/${EXAMPLE_NAME}.csproj
    @ONLY)

  add_custom_command(
    OUTPUT ${DOTNET_EXAMPLE_DIR}/${EXAMPLE_NAME}.cs
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DOTNET_EXAMPLE_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${FILE_NAME}
      ${DOTNET_EXAMPLE_DIR}/
    MAIN_DEPENDENCY ${FILE_NAME}
    VERBATIM
    WORKING_DIRECTORY ${DOTNET_EXAMPLE_DIR})

  add_custom_command(
    OUTPUT ${DOTNET_EXAMPLE_DIR}/timestamp
    COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
      ${DOTNET_EXECUTABLE} build --nologo -c Release ${EXAMPLE_NAME}.csproj
    COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME ${DOTNET_EXECUTABLE} pack -c Release ${EXAMPLE_NAME}.csproj
    COMMAND ${CMAKE_COMMAND} -E touch ${DOTNET_EXAMPLE_DIR}/timestamp
    DEPENDS
      ${DOTNET_EXAMPLE_DIR}/${EXAMPLE_NAME}.csproj
      ${DOTNET_EXAMPLE_DIR}/${EXAMPLE_NAME}.cs
      dotnet_package
    BYPRODUCTS
      ${DOTNET_EXAMPLE_DIR}/bin
      ${DOTNET_EXAMPLE_DIR}/obj
    VERBATIM
    COMMENT "Compiling .Net ${COMPONENT_NAME}/${EXAMPLE_NAME}.cs (${DOTNET_EXAMPLE_DIR}/timestamp)"
    WORKING_DIRECTORY ${DOTNET_EXAMPLE_DIR})

  add_custom_target(dotnet_${COMPONENT_NAME}_${EXAMPLE_NAME} ALL
    DEPENDS
      ${DOTNET_EXAMPLE_DIR}/timestamp
    WORKING_DIRECTORY ${DOTNET_EXAMPLE_DIR})

  if(BUILD_TESTING)
    if(USE_DOTNET_CORE_31)
      add_test(
        NAME dotnet_${COMPONENT_NAME}_${EXAMPLE_NAME}_netcoreapp31
        COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
          ${DOTNET_EXECUTABLE} run --no-build --framework netcoreapp3.1 -c Release ${EXAMPLE_NAME}.csproj
        WORKING_DIRECTORY ${DOTNET_EXAMPLE_DIR})
    endif()
    if(USE_DOTNET_6)
      add_test(
        NAME dotnet_${COMPONENT_NAME}_${EXAMPLE_NAME}_net60
        COMMAND ${CMAKE_COMMAND} -E env --unset=TARGETNAME
          ${DOTNET_EXECUTABLE} run --no-build --framework net6.0 -c Release ${EXAMPLE_NAME}.csproj
        WORKING_DIRECTORY ${DOTNET_EXAMPLE_DIR})
    endif()
  endif()
  message(STATUS "Configuring example ${FILE_NAME} done")
endfunction()
