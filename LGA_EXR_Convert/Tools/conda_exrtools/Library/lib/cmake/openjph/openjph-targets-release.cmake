#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "openjph" for configuration "Release"
set_property(TARGET openjph APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(openjph PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/openjph.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/openjph.dll"
  )

list(APPEND _cmake_import_check_targets openjph )
list(APPEND _cmake_import_check_files_for_openjph "${_IMPORT_PREFIX}/lib/openjph.lib" "${_IMPORT_PREFIX}/bin/openjph.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
