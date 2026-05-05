#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "FreeGLUT::freeglut" for configuration "Release"
set_property(TARGET FreeGLUT::freeglut APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(FreeGLUT::freeglut PROPERTIES
  IMPORTED_IMPLIB_RELEASE "C:/Portable/LGA_MediaTools/LGA_EXR_Convert/Tools/conda_exrtools/Library/lib/glut.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/glut.dll"
  )

list(APPEND _cmake_import_check_targets FreeGLUT::freeglut )
list(APPEND _cmake_import_check_files_for_FreeGLUT::freeglut "C:/Portable/LGA_MediaTools/LGA_EXR_Convert/Tools/conda_exrtools/Library/lib/glut.lib" "${_IMPORT_PREFIX}/bin/glut.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
