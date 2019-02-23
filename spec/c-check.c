#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// typedef off_t _IO_off64_t;

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

#define rpm_version_maj_eq(maj)                 \
  (VERSION_MAJOR == (maj))

#define rpm_version_majmin_eq(maj, min)                 \
  (rpm_version_maj_eq((maj)) && VERSION_MINOR == (min))

#define rpm_version_eq(maj, min, pat)                               \
  (rpm_version_majmin_eq((maj), (min)) && VERSION_PATCH == (pat))

#define rpm_version_less(maj, min, pat)                             \
  ((VERSION_MAJOR < (maj)) ||                                       \
   (rpm_version_maj_eq((maj)) && VERSION_MINOR < (min)) ||          \
   (rpm_version_majmin_eq((maj), (min)) && VERSION_PATCH < (pat)))


int sizeof_spec_s(void)
{
#if rpm_version_less(4, 9, 0)
  size_t ssz;
  ssz = sizeof(struct rpmSpec_s);
  if (ssz > INT_MAX) {
    return -2;
  }
  return (int)ssz;
#else
  return -1;
#endif
}

#define SPEC_S_OFFSET(offsz, member_str, mem)      \
  do {                                             \
    if (strcmp(member_str, #mem) == 0) {           \
      offsz = offsetof(struct rpmSpec_s, mem);     \
    }                                              \
  } while(0)

int offset_spec_s(const char *member)
{
#if rpm_version_less(4, 9, 0)
  size_t offsz;
  offsz = (size_t)-1;

  SPEC_S_OFFSET(offsz, member, specFile);
  SPEC_S_OFFSET(offsz, member, lbufPtr);
  SPEC_S_OFFSET(offsz, member, sources);
  SPEC_S_OFFSET(offsz, member, packages);

  if (offsz >= sizeof(struct rpmSpec_s)) {
    return -1;
  }
  if (offsz > INT_MAX) {
    return -2;
  }
  return (int)offsz;
#else
  return -1;
#endif
}
