#!/bin/sh
#
# Build and test Git
#

. ${0%/*}/lib.sh

case "$CI_OS_NAME" in
windows*) cmd //c mklink //j t\\.prove "$(cygpath -aw "$cache_dir/.prove")";;
*) ln -s "$cache_dir/.prove" t/.prove;;
esac

export MAKE_TARGETS="all test"

case "$jobname" in
linux-gcc)
	export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
	;;
linux-TEST-vars)
	export BUT_TEST_SPLIT_INDEX=yes
	export BUT_TEST_MERGE_ALGORITHM=recursive
	export BUT_TEST_FULL_IN_PACK_ARRAY=true
	export BUT_TEST_OE_SIZE=10
	export BUT_TEST_OE_DELTA_SIZE=5
	export BUT_TEST_CUMMIT_GRAPH=1
	export BUT_TEST_CUMMIT_GRAPH_CHANGED_PATHS=1
	export BUT_TEST_MULTI_PACK_INDEX=1
	export BUT_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=1
	export BUT_TEST_ADD_I_USE_BUILTIN=1
	export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=master
	export BUT_TEST_WRITE_REV_INDEX=1
	export BUT_TEST_CHECKOUT_WORKERS=2
	;;
linux-clang)
	export BUT_TEST_DEFAULT_HASH=sha1
	;;
linux-sha256)
	export BUT_TEST_DEFAULT_HASH=sha256
	;;
pedantic)
	# Don't run the tests; we only care about whether Git can be
	# built.
	export DEVOPTS=pedantic
	export MAKE_TARGETS=all
	;;
esac

# Any new "test" targets should not go after this "make", but should
# adjust $MAKE_TARGETS. Otherwise compilation-only targets above will
# start running tests.
make $MAKE_TARGETS
check_unignored_build_artifacts

save_good_tree
