#include "test-tool.h"
#include "cache.h"

int cmd__sha1(int ac, const char **av)
{
	return cmd_hash_impl(ac, av, BUT_HASH_SHA1);
}
