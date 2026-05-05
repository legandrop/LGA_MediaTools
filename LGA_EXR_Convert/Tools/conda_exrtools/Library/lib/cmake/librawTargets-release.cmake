#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "libraw::raw" for configuration "Release"
set_property(TARGET libraw::raw APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(libraw::raw PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/raw.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/raw.dll"
  )

list(APPEND _cmake_import_check_targets libraw::raw )
list(APPEND _cmake_import_check_files_for_libraw::raw "${_IMPORT_PREFIX}/lib/raw.lib" "${_IMPORT_PREFIX}/bin/raw.dll" )

# Import target "libraw::raw_r" for configuration "Release"
set_property(TARGET libraw::raw_r APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(libraw::raw_r PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/raw_r.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/raw_r.dll"
  )

list(APPEND _cmake_import_check_targets libraw::raw_r )
list(APPEND _cmake_import_check_files_for_libraw::raw_r "${_IMPORT_PREFIX}/lib/raw_r.lib" "${_IMPORT_PREFIX}/bin/raw_r.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
