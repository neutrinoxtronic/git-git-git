#!/bin/sh

test_description='pack should notice missing cummit objects'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	for i in 1 2 3 4 5
	do
		echo "$i" >"file$i" &&
		git add "file$i" &&
		test_tick &&
		git cummit -m "$i" &&
		git tag "tag$i" || return 1
	done &&
	obj=$(git rev-parse --verify tag3) &&
	fanout=$(expr "$obj" : "\(..\)") &&
	remainder=$(expr "$obj" : "..\(.*\)") &&
	rm -f ".git/objects/$fanout/$remainder"
'

test_expect_success 'check corruption' '
	test_must_fail git fsck
'

test_expect_success 'rev-list notices corruption (1)' '
	test_must_fail env GIT_TEST_CUMMIT_GRAPH=0 git -c core.cummitGraph=false rev-list HEAD
'

test_expect_success 'rev-list notices corruption (2)' '
	test_must_fail env GIT_TEST_CUMMIT_GRAPH=0 git -c core.cummitGraph=false rev-list --objects HEAD
'

test_expect_success 'pack-objects notices corruption' '
	echo HEAD |
	test_must_fail git pack-objects --revs pack
'

test_done
