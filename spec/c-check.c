
#include <stdlib.h>
#include <rpm/rpmspec.h>

size_t sizeof_spec_s(void)
{
  return sizeof(struct rpmSpec_s);
}
