#!/bin/sh

test_description='checkout $tree -- $paths'
BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	mkdir dir &&
	>dir/main &&
	echo common >dir/common &&
	but add dir/main dir/common &&
	test_tick && but cummit -m "main has dir/main" &&
	but checkout -b next &&
	but mv dir/main dir/next0 &&
	echo next >dir/next1 &&
	but add dir &&
	test_tick && but cummit -m "next has dir/next but not dir/main"
'

test_expect_success 'checking out paths out of a tree does not clobber unrelated paths' '
	but checkout next &&
	but reset --hard &&
	rm dir/next0 &&
	cat dir/common >expect.common &&
	echo modified >expect.next1 &&
	cat expect.next1 >dir/next1 &&
	echo untracked >expect.next2 &&
	cat expect.next2 >dir/next2 &&

	but checkout main dir &&

	test_cmp expect.common dir/common &&
	test_path_is_file dir/main &&
	but diff --exit-code main dir/main &&

	test_path_is_missing dir/next0 &&
	test_cmp expect.next1 dir/next1 &&
	test_path_is_file dir/next2 &&
	test_must_fail but ls-files --error-unmatch dir/next2 &&
	test_cmp expect.next2 dir/next2
'

test_expect_success 'do not touch unmerged entries matching $path but not in $tree' '
	but checkout next &&
	but reset --hard &&

	cat dir/common >expect.common &&
	EMPTY_SHA1=$(but hash-object -w --stdin </dev/null) &&
	but rm dir/next0 &&
	cat >expect.next0 <<-EOF &&
	100644 $EMPTY_SHA1 1	dir/next0
	100644 $EMPTY_SHA1 2	dir/next0
	EOF
	but update-index --index-info <expect.next0 &&

	but checkout main dir &&

	test_cmp expect.common dir/common &&
	test_path_is_file dir/main &&
	but diff --exit-code main dir/main &&
	but ls-files -s dir/next0 >actual.next0 &&
	test_cmp expect.next0 actual.next0
'

test_expect_success 'do not touch files that are already up-to-date' '
	but reset --hard &&
	echo one >file1 &&
	echo two >file2 &&
	but add file1 file2 &&
	but cummit -m base &&
	echo modified >file1 &&
	test-tool chmtime =1000000000 file2 &&
	but update-index -q --refresh &&
	but checkout HEAD -- file1 file2 &&
	echo one >expect &&
	test_cmp expect file1 &&
	echo "1000000000" >expect &&
	test-tool chmtime --get file2 >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout HEAD adds deleted intent-to-add file back to index' '
	echo "nonempty" >nonempty &&
	>empty &&
	but add nonempty empty &&
	but cummit -m "create files to be deleted" &&
	but rm --cached nonempty empty &&
	but add -N nonempty empty &&
	but checkout HEAD nonempty empty &&
	but diff --cached --exit-code
'

test_done
