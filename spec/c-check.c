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

#define SPEC_S_OFFSET(offsz, member_str, type, mem) \
  do {                                              \
    if (strcmp(member_str, #mem) == 0) {            \
      offsz = offsetof(type, mem);                  \
    }                                               \
  } while(0)


static int int_overflow_check(size_t szv, int value_overflowed)
{
  if (szv > INT_MAX) {
    return value_overflowed;
  }
  return (int)szv;
}

int sizeof_spec_s(void)
{
#if rpm_version_less(4, 9, 0)
  return int_overflow_check(sizeof(struct rpmSpec_s), -2);
#else
  return -1;
#endif
}

int offset_spec_s(const char *member)
{
#if rpm_version_less(4, 9, 0)
  size_t offsz;
  offsz = (size_t)-1;

  SPEC_S_OFFSET(offsz, member, struct rpmSpec_s, specFile);
  SPEC_S_OFFSET(offsz, member, struct rpmSpec_s, lbufPtr);
  SPEC_S_OFFSET(offsz, member, struct rpmSpec_s, sources);
  SPEC_S_OFFSET(offsz, member, struct rpmSpec_s, packages);

  if (offsz >= sizeof(struct rpmSpec_s)) {
    return -1;
  }
  return int_overflow_check(offsz, -2);
#else
  return -1;
#endif
}

int sizeof_package_s(void)
{
#if rpm_version_less(4, 9, 0)
  return int_overflow_check(sizeof(struct Package_s), -2);
#else
  return -1;
#endif
}

int offset_package_s(const char *member)
{
#if rpm_version_less(4, 9, 0)
  size_t offsz;
  offsz = (size_t)-1;

  SPEC_S_OFFSET(offsz, member, struct Package_s, header);
  SPEC_S_OFFSET(offsz, member, struct Package_s, next);

  if (offsz >= sizeof(struct Package_s)) {
    return -1;
  }
  return int_overflow_check(offsz, -2);
#else
  return -1;
#endif
}
