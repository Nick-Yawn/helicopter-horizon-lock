#define MAINPREFIX z
#define PREFIX hhl
#define SUBPREFIX addons

#include "script_version.hpp"

#define VERSION     MAJOR.MINOR
#define VERSION_STR MAJOR.MINOR.PATCH.BUILD
#define VERSION_AR  MAJOR,MINOR,PATCH,BUILD

#define REQUIRED_VERSION 2.18

#ifdef COMPONENT_BEAUTIFIED
    #define COMPONENT_NAME QUOTE(Helicopter Horizon Lock - COMPONENT_BEAUTIFIED)
#else
    #define COMPONENT_NAME QUOTE(Helicopter Horizon Lock - COMPONENT)
#endif
