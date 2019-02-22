#include <stdlib.h>
#include <rpm/rpmspec.h>

#ifndef VERSION_MAJOR
#define VERSION_MAJOR 9999
#endif
#ifndef VERSION_MINOR
#define VERSION_MINOR 9999
#endif
#ifndef VERSION_PATCH
#define VERSION_PATCH 9999
#endif

int sizeof_spec_s(void)
{
#if VERSION_MAJOR <= 4 && VERSION_MINOR < 9
  int isz = (int)sizeof(struct rpmSpec_s);
  if (isz < 0) {
    return -2;
  } else {
    return isz;
  }
#else
  return -1;
#endif
}
