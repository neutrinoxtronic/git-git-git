#!/bin/sh

test_description='test but rev-parse diagnosis for invalid argument'

exec </dev/null

BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_did_you_mean ()
{
	cat >expected <<-EOF &&
	fatal: path '$2$3' $4, but not ${5:-$SQ$3$SQ}
	hint: Did you mean '$1:$2$3'${2:+ aka $SQ$1:./$3$SQ}?
	EOF
	test_cmp expected error
}

HASH_file=

test_expect_success 'set up basic repo' '
	echo one > file.txt &&
	mkdir subdir &&
	echo two > subdir/file.txt &&
	echo three > subdir/file2.txt &&
	but add . &&
	but cummit -m init &&
	echo four > index-only.txt &&
	but add index-only.txt &&
	echo five > disk-only.txt
'

test_expect_success 'correct file objects' '
	HASH_file=$(but rev-parse HEAD:file.txt) &&
	but rev-parse HEAD:subdir/file.txt &&
	but rev-parse :index-only.txt &&
	(cd subdir &&
	 but rev-parse HEAD:subdir/file2.txt &&
	 test $HASH_file = $(but rev-parse HEAD:file.txt) &&
	 test $HASH_file = $(but rev-parse :file.txt) &&
	 test $HASH_file = $(but rev-parse :0:file.txt) )
'

test_expect_success 'correct relative file objects (0)' '
	but rev-parse :file.txt >expected &&
	but rev-parse :./file.txt >result &&
	test_cmp expected result &&
	but rev-parse :0:./file.txt >result &&
	test_cmp expected result
'

test_expect_success 'correct relative file objects (1)' '
	but rev-parse HEAD:file.txt >expected &&
	but rev-parse HEAD:./file.txt >result &&
	test_cmp expected result
'

test_expect_success 'correct relative file objects (2)' '
	(
		cd subdir &&
		but rev-parse HEAD:../file.txt >result &&
		test_cmp ../expected result
	)
'

test_expect_success 'correct relative file objects (3)' '
	(
		cd subdir &&
		but rev-parse HEAD:../subdir/../file.txt >result &&
		test_cmp ../expected result
	)
'

test_expect_success 'correct relative file objects (4)' '
	but rev-parse HEAD:subdir/file.txt >expected &&
	(
		cd subdir &&
		but rev-parse HEAD:./file.txt >result &&
		test_cmp ../expected result
	)
'

test_expect_success 'correct relative file objects (5)' '
	but rev-parse :subdir/file.txt >expected &&
	(
		cd subdir &&
		but rev-parse :./file.txt >result &&
		test_cmp ../expected result &&
		but rev-parse :0:./file.txt >result &&
		test_cmp ../expected result
	)
'

test_expect_success 'correct relative file objects (6)' '
	but rev-parse :file.txt >expected &&
	(
		cd subdir &&
		but rev-parse :../file.txt >result &&
		test_cmp ../expected result &&
		but rev-parse :0:../file.txt >result &&
		test_cmp ../expected result
	)
'

test_expect_success 'incorrect revision id' '
	test_must_fail but rev-parse foobar:file.txt 2>error &&
	test_i18ngrep "invalid object name .foobar." error &&
	test_must_fail but rev-parse foobar 2>error &&
	test_i18ngrep "unknown revision or path not in the working tree." error
'

test_expect_success 'incorrect file in sha1:path' '
	test_must_fail but rev-parse HEAD:nothing.txt 2>error &&
	test_i18ngrep "path .nothing.txt. does not exist in .HEAD." error &&
	test_must_fail but rev-parse HEAD:index-only.txt 2>error &&
	test_i18ngrep "path .index-only.txt. exists on disk, but not in .HEAD." error &&
	(cd subdir &&
	 test_must_fail but rev-parse HEAD:file2.txt 2>error &&
	 test_did_you_mean HEAD subdir/ file2.txt exists )
'

test_expect_success 'incorrect file in :path and :N:path' '
	test_must_fail but rev-parse :nothing.txt 2>error &&
	test_i18ngrep "path .nothing.txt. does not exist (neither on disk nor in the index)" error &&
	test_must_fail but rev-parse :1:nothing.txt 2>error &&
	test_i18ngrep "path .nothing.txt. does not exist (neither on disk nor in the index)" error &&
	test_must_fail but rev-parse :1:file.txt 2>error &&
	test_did_you_mean ":0" "" file.txt "is in the index" "at stage 1" &&
	(cd subdir &&
	 test_must_fail but rev-parse :1:file.txt 2>error &&
	 test_did_you_mean ":0" "" file.txt "is in the index" "at stage 1" &&
	 test_must_fail but rev-parse :file2.txt 2>error &&
	 test_did_you_mean ":0" subdir/ file2.txt "is in the index" &&
	 test_must_fail but rev-parse :2:file2.txt 2>error &&
	 test_did_you_mean :0 subdir/ file2.txt "is in the index") &&
	test_must_fail but rev-parse :disk-only.txt 2>error &&
	test_i18ngrep "path .disk-only.txt. exists on disk, but not in the index" error
'

test_expect_success 'invalid @{n} reference' '
	test_must_fail but rev-parse main@{99999} >output 2>error &&
	test_must_be_empty output &&
	test_i18ngrep "log for [^ ]* only has [0-9][0-9]* entries" error  &&
	test_must_fail but rev-parse --verify main@{99999} >output 2>error &&
	test_must_be_empty output &&
	test_i18ngrep "log for [^ ]* only has [0-9][0-9]* entries" error
'

test_expect_success 'relative path not found' '
	(
		cd subdir &&
		test_must_fail but rev-parse HEAD:./nonexistent.txt 2>error &&
		test_i18ngrep subdir/nonexistent.txt error
	)
'

test_expect_success 'relative path outside worktree' '
	test_must_fail but rev-parse HEAD:../file.txt >output 2>error &&
	test_must_be_empty output &&
	test_i18ngrep "outside repository" error
'

test_expect_success 'relative path when cwd is outside worktree' '
	test_must_fail but --but-dir=.but --work-tree=subdir rev-parse HEAD:./file.txt >output 2>error &&
	test_must_be_empty output &&
	test_i18ngrep "relative path syntax can.t be used outside working tree" error
'

test_expect_success '<cummit>:file correctly diagnosed after a pathname' '
	test_must_fail but rev-parse file.txt HEAD:file.txt 1>actual 2>error &&
	test_i18ngrep ! "exists on disk" error &&
	test_i18ngrep "no such path in the working tree" error &&
	cat >expect <<-\EOF &&
	file.txt
	HEAD:file.txt
	EOF
	test_cmp expect actual
'

test_expect_success 'dotdot is not an empty set' '
	( H=$(but rev-parse HEAD) && echo $H && echo ^$H ) >expect &&

	but rev-parse HEAD.. >actual &&
	test_cmp expect actual &&

	but rev-parse ..HEAD >actual &&
	test_cmp expect actual &&

	echo .. >expect &&
	but rev-parse .. >actual &&
	test_cmp expect actual
'

test_expect_success 'dotdot does not peel endpoints' '
	but tag -a -m "annote" annotated HEAD &&
	A=$(but rev-parse annotated) &&
	H=$(but rev-parse annotated^0) &&
	{
		echo $A && echo ^$A
	} >expect-with-two-dots &&
	{
		echo $A && echo $A && echo ^$H
	} >expect-with-merge-base &&

	but rev-parse annotated..annotated >actual-with-two-dots &&
	test_cmp expect-with-two-dots actual-with-two-dots &&

	but rev-parse annotated...annotated >actual-with-merge-base &&
	test_cmp expect-with-merge-base actual-with-merge-base
'

test_expect_success 'arg before dashdash must be a revision (missing)' '
	test_must_fail but rev-parse foobar -- 2>stderr &&
	test_i18ngrep "bad revision" stderr
'

test_expect_success 'arg before dashdash must be a revision (file)' '
	>foobar &&
	test_must_fail but rev-parse foobar -- 2>stderr &&
	test_i18ngrep "bad revision" stderr
'

test_expect_success 'arg before dashdash must be a revision (ambiguous)' '
	>foobar &&
	but update-ref refs/heads/foobar HEAD &&
	{
		# we do not want to use rev-parse here, because
		# we are testing it
		but show-ref -s refs/heads/foobar &&
		printf "%s\n" --
	} >expect &&
	but rev-parse foobar -- >actual &&
	test_cmp expect actual
'

test_expect_success 'reject Nth parent if N is too high' '
	test_must_fail but rev-parse HEAD^100000000000000000000000000000000
'

test_expect_success 'reject Nth ancestor if N is too high' '
	test_must_fail but rev-parse HEAD~100000000000000000000000000000000
'

test_expect_success 'pathspecs with wildcards are not ambiguous' '
	echo "*.c" >expect &&
	but rev-parse "*.c" >actual &&
	test_cmp expect actual
'

test_expect_success 'backslash does not trigger wildcard rule' '
	test_must_fail but rev-parse "foo\\bar"
'

test_expect_success 'escaped char does not trigger wildcard rule' '
	test_must_fail but rev-parse "foo\\*bar"
'

test_expect_success 'arg after dashdash not interpreted as option' '
	cat >expect <<-\EOF &&
	--
	--local-env-vars
	EOF
	but rev-parse -- --local-env-vars >actual &&
	test_cmp expect actual
'

test_expect_success 'arg after end-of-options not interpreted as option' '
	test_must_fail but rev-parse --end-of-options --not-real -- 2>err &&
	test_i18ngrep bad.revision.*--not-real err
'

test_expect_success 'end-of-options still allows --' '
	cat >expect <<-EOF &&
	--end-of-options
	$(but rev-parse --verify HEAD)
	--
	path
	EOF
	but rev-parse --end-of-options HEAD -- path >actual &&
	test_cmp expect actual
'

test_done
