#!/bin/sh

test_description='but cat-file'

. ./test-lib.sh

test_cmdmode_usage () {
	test_expect_code 129 "$@" 2>err &&
	grep "^error:.*is incompatible with" err
}

for switches in \
	'-e -p' \
	'-p -t' \
	'-t -s' \
	'-s --textconv' \
	'--textconv --filters' \
	'--batch-all-objects -e'
do
	test_expect_success "usage: cmdmode $switches" '
		test_cmdmode_usage but cat-file $switches
	'
done

test_incompatible_usage () {
	test_expect_code 129 "$@" 2>err &&
	grep -E "^(fatal|error):.*(requires|incompatible with|needs)" err
}

for opt in --batch --batch-check
do
	test_expect_success "usage: incompatible options: --path with $opt" '
		test_incompatible_usage but cat-file --path=foo $opt
	'
done

test_missing_usage () {
	test_expect_code 129 "$@" 2>err &&
	grep -E "^fatal:.*required" err
}

short_modes="-e -p -t -s"
cw_modes="--textconv --filters"

for opt in $cw_modes
do
	test_expect_success "usage: $opt requires another option" '
		test_missing_usage but cat-file $opt
	'
done

for opt in $short_modes
do
	test_expect_success "usage: $opt requires another option" '
		test_missing_usage but cat-file $opt
	'

	for opt2 in --batch \
		--batch-check \
		--follow-symlinks \
		"--path=foo HEAD:some-path.txt"
	do
		test_expect_success "usage: incompatible options: $opt and $opt2" '
			test_incompatible_usage but cat-file $opt $opt2
		'
	done
done

test_too_many_arguments () {
	test_expect_code 129 "$@" 2>err &&
	grep -E "^fatal: too many arguments$" err
}

for opt in $short_modes $cw_modes
do
	args="one two three"
	test_expect_success "usage: too many arguments: $opt $args" '
		test_too_many_arguments but cat-file $opt $args
	'

	for opt2 in --buffer --follow-symlinks
	do
		test_expect_success "usage: incompatible arguments: $opt with batch option $opt2" '
			test_incompatible_usage but cat-file $opt $opt2
		'
	done
done

for opt in --buffer \
	--follow-symlinks \
	--batch-all-objects
do
	test_expect_success "usage: bad option combination: $opt without batch mode" '
		test_incompatible_usage but cat-file $opt &&
		test_incompatible_usage but cat-file $opt commit HEAD
	'
done

echo_without_newline () {
    printf '%s' "$*"
}

strlen () {
    echo_without_newline "$1" | wc -c | sed -e 's/^ *//'
}

maybe_remove_timestamp () {
	if test -z "$2"; then
		echo_without_newline "$1"
	else
		echo_without_newline "$(printf '%s\n' "$1" | remove_timestamp)"
	fi
}

remove_timestamp () {
	sed -e 's/ [0-9][0-9]* [-+][0-9][0-9][0-9][0-9]$//'
}


run_tests () {
    type=$1
    sha1=$2
    size=$3
    content=$4
    pretty_content=$5
    no_ts=$6

    batch_output="$sha1 $type $size
$content"

    test_expect_success "$type exists" '
	but cat-file -e $sha1
    '

    test_expect_success "Type of $type is correct" '
	echo $type >expect &&
	but cat-file -t $sha1 >actual &&
	test_cmp expect actual
    '

    test_expect_success "Size of $type is correct" '
	echo $size >expect &&
	but cat-file -s $sha1 >actual &&
	test_cmp expect actual
    '

    test_expect_success "Type of $type is correct using --allow-unknown-type" '
	echo $type >expect &&
	but cat-file -t --allow-unknown-type $sha1 >actual &&
	test_cmp expect actual
    '

    test_expect_success "Size of $type is correct using --allow-unknown-type" '
	echo $size >expect &&
	but cat-file -s --allow-unknown-type $sha1 >actual &&
	test_cmp expect actual
    '

    test -z "$content" ||
    test_expect_success "Content of $type is correct" '
	maybe_remove_timestamp "$content" $no_ts >expect &&
	maybe_remove_timestamp "$(but cat-file $type $sha1)" $no_ts >actual &&
	test_cmp expect actual
    '

    test_expect_success "Pretty content of $type is correct" '
	maybe_remove_timestamp "$pretty_content" $no_ts >expect &&
	maybe_remove_timestamp "$(but cat-file -p $sha1)" $no_ts >actual &&
	test_cmp expect actual
    '

    test -z "$content" ||
    test_expect_success "--batch output of $type is correct" '
	maybe_remove_timestamp "$batch_output" $no_ts >expect &&
	maybe_remove_timestamp "$(echo $sha1 | but cat-file --batch)" $no_ts >actual &&
	test_cmp expect actual
    '

    test_expect_success "--batch-check output of $type is correct" '
	echo "$sha1 $type $size" >expect &&
	echo_without_newline $sha1 | but cat-file --batch-check >actual &&
	test_cmp expect actual
    '

    for opt in --buffer --no-buffer
    do
	test -z "$content" ||
		test_expect_success "--batch-command $opt output of $type content is correct" '
		maybe_remove_timestamp "$batch_output" $no_ts >expect &&
		maybe_remove_timestamp "$(test_write_lines "contents $sha1" |
		but cat-file --batch-command $opt)" $no_ts >actual &&
		test_cmp expect actual
	'

	test_expect_success "--batch-command $opt output of $type info is correct" '
		echo "$sha1 $type $size" >expect &&
		test_write_lines "info $sha1" |
		but cat-file --batch-command $opt >actual &&
		test_cmp expect actual
	'
    done

    test_expect_success "custom --batch-check format" '
	echo "$type $sha1" >expect &&
	echo $sha1 | but cat-file --batch-check="%(objecttype) %(objectname)" >actual &&
	test_cmp expect actual
    '

    test_expect_success "custom --batch-command format" '
	echo "$type $sha1" >expect &&
	echo "info $sha1" | but cat-file --batch-command="%(objecttype) %(objectname)" >actual &&
	test_cmp expect actual
    '

    test_expect_success '--batch-check with %(rest)' '
	echo "$type this is some extra content" >expect &&
	echo "$sha1    this is some extra content" |
		but cat-file --batch-check="%(objecttype) %(rest)" >actual &&
	test_cmp expect actual
    '

    test -z "$content" ||
    test_expect_success "--batch without type ($type)" '
	{
		echo "$size" &&
		maybe_remove_timestamp "$content" $no_ts
	} >expect &&
	echo $sha1 | but cat-file --batch="%(objectsize)" >actual.full &&
	maybe_remove_timestamp "$(cat actual.full)" $no_ts >actual &&
	test_cmp expect actual
    '

    test -z "$content" ||
    test_expect_success "--batch without size ($type)" '
	{
		echo "$type" &&
		maybe_remove_timestamp "$content" $no_ts
	} >expect &&
	echo $sha1 | but cat-file --batch="%(objecttype)" >actual.full &&
	maybe_remove_timestamp "$(cat actual.full)" $no_ts >actual &&
	test_cmp expect actual
    '
}

hello_content="Hello World"
hello_size=$(strlen "$hello_content")
hello_sha1=$(echo_without_newline "$hello_content" | but hash-object --stdin)

test_expect_success "setup" '
	echo_without_newline "$hello_content" > hello &&
	but update-index --add hello
'

run_tests 'blob' $hello_sha1 $hello_size "$hello_content" "$hello_content"

test_expect_success '--batch-command --buffer with flush for blob info' '
	echo "$hello_sha1 blob $hello_size" >expect &&
	test_write_lines "info $hello_sha1" "flush" |
	BUT_TEST_CAT_FILE_NO_FLUSH_ON_EXIT=1 \
	but cat-file --batch-command --buffer >actual &&
	test_cmp expect actual
'

test_expect_success '--batch-command --buffer without flush for blob info' '
	touch output &&
	test_write_lines "info $hello_sha1" |
	BUT_TEST_CAT_FILE_NO_FLUSH_ON_EXIT=1 \
	but cat-file --batch-command --buffer >>output &&
	test_must_be_empty output
'

test_expect_success '--batch-check without %(rest) considers whole line' '
	echo "$hello_sha1 blob $hello_size" >expect &&
	but update-index --add --cacheinfo 100644 $hello_sha1 "white space" &&
	test_when_finished "but update-index --remove \"white space\"" &&
	echo ":white space" | but cat-file --batch-check >actual &&
	test_cmp expect actual
'

tree_sha1=$(but write-tree)
tree_size=$(($(test_oid rawsz) + 13))
tree_pretty_content="100644 blob $hello_sha1	hello"

run_tests 'tree' $tree_sha1 $tree_size "" "$tree_pretty_content"

cummit_message="Initial cummit"
cummit_sha1=$(echo_without_newline "$cummit_message" | but cummit-tree $tree_sha1)
cummit_size=$(($(test_oid hexsz) + 137))
cummit_content="tree $tree_sha1
author $BUT_AUTHOR_NAME <$BUT_AUTHOR_EMAIL> 0000000000 +0000
cummitter $BUT_CUMMITTER_NAME <$BUT_CUMMITTER_EMAIL> 0000000000 +0000

$cummit_message"

run_tests 'cummit' $cummit_sha1 $cummit_size "$cummit_content" "$cummit_content" 1

tag_header_without_timestamp="object $hello_sha1
type blob
tag hellotag
tagger $BUT_CUMMITTER_NAME <$BUT_CUMMITTER_EMAIL>"
tag_description="This is a tag"
tag_content="$tag_header_without_timestamp 0000000000 +0000

$tag_description"

tag_sha1=$(echo_without_newline "$tag_content" | but hash-object -t tag --stdin -w)
tag_size=$(strlen "$tag_content")

run_tests 'tag' $tag_sha1 $tag_size "$tag_content" "$tag_content" 1

test_expect_success \
    "Reach a blob from a tag pointing to it" \
    "test '$hello_content' = \"\$(but cat-file blob $tag_sha1)\""

for batch in batch batch-check batch-command
do
    for opt in t s e p
    do
	test_expect_success "Passing -$opt with --$batch fails" '
	    test_must_fail but cat-file --$batch -$opt $hello_sha1
	'

	test_expect_success "Passing --$batch with -$opt fails" '
	    test_must_fail but cat-file -$opt --$batch $hello_sha1
	'
    done

    test_expect_success "Passing <type> with --$batch fails" '
	test_must_fail but cat-file --$batch blob $hello_sha1
    '

    test_expect_success "Passing --$batch with <type> fails" '
	test_must_fail but cat-file blob --$batch $hello_sha1
    '

    test_expect_success "Passing sha1 with --$batch fails" '
	test_must_fail but cat-file --$batch $hello_sha1
    '
done

for opt in t s e p
do
    test_expect_success "Passing -$opt with --follow-symlinks fails" '
	    test_must_fail but cat-file --follow-symlinks -$opt $hello_sha1
	'
done

test_expect_success "--batch-check for a non-existent named object" '
    test "foobar42 missing
foobar84 missing" = \
    "$( ( echo foobar42 && echo_without_newline foobar84 ) | but cat-file --batch-check)"
'

test_expect_success "--batch-check for a non-existent hash" '
    test "0000000000000000000000000000000000000042 missing
0000000000000000000000000000000000000084 missing" = \
    "$( ( echo 0000000000000000000000000000000000000042 &&
	 echo_without_newline 0000000000000000000000000000000000000084 ) |
       but cat-file --batch-check)"
'

test_expect_success "--batch for an existent and a non-existent hash" '
    test "$tag_sha1 tag $tag_size
$tag_content
0000000000000000000000000000000000000000 missing" = \
    "$( ( echo $tag_sha1 &&
	 echo_without_newline 0000000000000000000000000000000000000000 ) |
       but cat-file --batch)"
'

test_expect_success "--batch-check for an empty line" '
    test " missing" = "$(echo | but cat-file --batch-check)"
'

test_expect_success 'empty --batch-check notices missing object' '
	echo "$ZERO_OID missing" >expect &&
	echo "$ZERO_OID" | but cat-file --batch-check="" >actual &&
	test_cmp expect actual
'

batch_input="$hello_sha1
$cummit_sha1
$tag_sha1
deadbeef

"

batch_output="$hello_sha1 blob $hello_size
$hello_content
$cummit_sha1 cummit $cummit_size
$cummit_content
$tag_sha1 tag $tag_size
$tag_content
deadbeef missing
 missing"

test_expect_success '--batch with multiple sha1s gives correct format' '
	test "$(maybe_remove_timestamp "$batch_output" 1)" = "$(maybe_remove_timestamp "$(echo_without_newline "$batch_input" | but cat-file --batch)" 1)"
'

batch_check_input="$hello_sha1
$tree_sha1
$cummit_sha1
$tag_sha1
deadbeef

"

batch_check_output="$hello_sha1 blob $hello_size
$tree_sha1 tree $tree_size
$cummit_sha1 cummit $cummit_size
$tag_sha1 tag $tag_size
deadbeef missing
 missing"

test_expect_success "--batch-check with multiple sha1s gives correct format" '
    test "$batch_check_output" = \
    "$(echo_without_newline "$batch_check_input" | but cat-file --batch-check)"
'

test_expect_success '--batch-command with multiple info calls gives correct format' '
	cat >expect <<-EOF &&
	$hello_sha1 blob $hello_size
	$tree_sha1 tree $tree_size
	$cummit_sha1 cummit $cummit_size
	$tag_sha1 tag $tag_size
	deadbeef missing
	EOF

	but cat-file --batch-command --buffer >actual <<-EOF &&
	info $hello_sha1
	info $tree_sha1
	info $cummit_sha1
	info $tag_sha1
	info deadbeef
	EOF

	test_cmp expect actual
'

test_expect_success '--batch-command with multiple command calls gives correct format' '
	remove_timestamp >expect <<-EOF &&
	$hello_sha1 blob $hello_size
	$hello_content
	$cummit_sha1 cummit $cummit_size
	$cummit_content
	$tag_sha1 tag $tag_size
	$tag_content
	deadbeef missing
	EOF

	but cat-file --batch-command --buffer >actual_raw <<-EOF &&
	contents $hello_sha1
	contents $cummit_sha1
	contents $tag_sha1
	contents deadbeef
	flush
	EOF

	remove_timestamp <actual_raw >actual &&
	test_cmp expect actual
'

test_expect_success 'setup blobs which are likely to delta' '
	test-tool genrandom foo 10240 >foo &&
	{ cat foo && echo plus; } >foo-plus &&
	but add foo foo-plus &&
	but cummit -m foo &&
	cat >blobs <<-\EOF
	HEAD:foo
	HEAD:foo-plus
	EOF
'

test_expect_success 'confirm that neither loose blob is a delta' '
	cat >expect <<-EOF &&
	$ZERO_OID
	$ZERO_OID
	EOF
	but cat-file --batch-check="%(deltabase)" <blobs >actual &&
	test_cmp expect actual
'

# To avoid relying too much on the current delta heuristics,
# we will check only that one of the two objects is a delta
# against the other, but not the order. We can do so by just
# asking for the base of both, and checking whether either
# sha1 appears in the output.
test_expect_success '%(deltabase) reports packed delta bases' '
	but repack -ad &&
	but cat-file --batch-check="%(deltabase)" <blobs >actual &&
	{
		grep "$(but rev-parse HEAD:foo)" actual ||
		grep "$(but rev-parse HEAD:foo-plus)" actual
	}
'

test_expect_success 'setup bogus data' '
	bogus_short_type="bogus" &&
	bogus_short_content="bogus" &&
	bogus_short_size=$(strlen "$bogus_short_content") &&
	bogus_short_sha1=$(echo_without_newline "$bogus_short_content" | but hash-object -t $bogus_short_type --literally -w --stdin) &&

	bogus_long_type="abcdefghijklmnopqrstuvwxyz1234679" &&
	bogus_long_content="bogus" &&
	bogus_long_size=$(strlen "$bogus_long_content") &&
	bogus_long_sha1=$(echo_without_newline "$bogus_long_content" | but hash-object -t $bogus_long_type --literally -w --stdin)
'

for arg1 in '' --allow-unknown-type
do
	for arg2 in -s -t -p
	do
		if test "$arg1" = "--allow-unknown-type" && test "$arg2" = "-p"
		then
			continue
		fi


		test_expect_success "cat-file $arg1 $arg2 error on bogus short OID" '
			cat >expect <<-\EOF &&
			fatal: invalid object type
			EOF

			if test "$arg1" = "--allow-unknown-type"
			then
				but cat-file $arg1 $arg2 $bogus_short_sha1
			else
				test_must_fail but cat-file $arg1 $arg2 $bogus_short_sha1 >out 2>actual &&
				test_must_be_empty out &&
				test_cmp expect actual
			fi
		'

		test_expect_success "cat-file $arg1 $arg2 error on bogus full OID" '
			if test "$arg2" = "-p"
			then
				cat >expect <<-EOF
				error: header for $bogus_long_sha1 too long, exceeds 32 bytes
				fatal: Not a valid object name $bogus_long_sha1
				EOF
			else
				cat >expect <<-EOF
				error: header for $bogus_long_sha1 too long, exceeds 32 bytes
				fatal: but cat-file: could not get object info
				EOF
			fi &&

			if test "$arg1" = "--allow-unknown-type"
			then
				but cat-file $arg1 $arg2 $bogus_short_sha1
			else
				test_must_fail but cat-file $arg1 $arg2 $bogus_long_sha1 >out 2>actual &&
				test_must_be_empty out &&
				test_cmp expect actual
			fi
		'

		test_expect_success "cat-file $arg1 $arg2 error on missing short OID" '
			cat >expect.err <<-EOF &&
			fatal: Not a valid object name $(test_oid deadbeef_short)
			EOF
			test_must_fail but cat-file $arg1 $arg2 $(test_oid deadbeef_short) >out 2>err.actual &&
			test_must_be_empty out
		'

		test_expect_success "cat-file $arg1 $arg2 error on missing full OID" '
			if test "$arg2" = "-p"
			then
				cat >expect.err <<-EOF
				fatal: Not a valid object name $(test_oid deadbeef)
				EOF
			else
				cat >expect.err <<-\EOF
				fatal: but cat-file: could not get object info
				EOF
			fi &&
			test_must_fail but cat-file $arg1 $arg2 $(test_oid deadbeef) >out 2>err.actual &&
			test_must_be_empty out &&
			test_cmp expect.err err.actual
		'
	done
done

test_expect_success '-e is OK with a broken object without --allow-unknown-type' '
	but cat-file -e $bogus_short_sha1
'

test_expect_success '-e can not be combined with --allow-unknown-type' '
	test_expect_code 128 but cat-file -e --allow-unknown-type $bogus_short_sha1
'

test_expect_success '-p cannot print a broken object even with --allow-unknown-type' '
	test_must_fail but cat-file -p $bogus_short_sha1 &&
	test_expect_code 128 but cat-file -p --allow-unknown-type $bogus_short_sha1
'

test_expect_success '<type> <hash> does not work with objects of broken types' '
	cat >err.expect <<-\EOF &&
	fatal: invalid object type "bogus"
	EOF
	test_must_fail but cat-file $bogus_short_type $bogus_short_sha1 2>err.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'broken types combined with --batch and --batch-check' '
	echo $bogus_short_sha1 >bogus-oid &&

	cat >err.expect <<-\EOF &&
	fatal: invalid object type
	EOF

	test_must_fail but cat-file --batch <bogus-oid 2>err.actual &&
	test_cmp err.expect err.actual &&

	test_must_fail but cat-file --batch-check <bogus-oid 2>err.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'the --batch and --batch-check options do not combine with --allow-unknown-type' '
	test_expect_code 128 but cat-file --batch --allow-unknown-type <bogus-oid &&
	test_expect_code 128 but cat-file --batch-check --allow-unknown-type <bogus-oid
'

test_expect_success 'the --allow-unknown-type option does not consider replacement refs' '
	cat >expect <<-EOF &&
	$bogus_short_type
	EOF
	but cat-file -t --allow-unknown-type $bogus_short_sha1 >actual &&
	test_cmp expect actual &&

	# Create it manually, as "but replace" will die on bogus
	# types.
	head=$(but rev-parse --verify HEAD) &&
	test_when_finished "test-tool ref-store main delete-refs 0 msg refs/replace/$bogus_short_sha1" &&
	test-tool ref-store main update-ref msg "refs/replace/$bogus_short_sha1" $head $ZERO_OID REF_SKIP_OID_VERIFICATION &&

	cat >expect <<-EOF &&
	cummit
	EOF
	but cat-file -t --allow-unknown-type $bogus_short_sha1 >actual &&
	test_cmp expect actual
'

test_expect_success "Type of broken object is correct" '
	echo $bogus_short_type >expect &&
	but cat-file -t --allow-unknown-type $bogus_short_sha1 >actual &&
	test_cmp expect actual
'

test_expect_success "Size of broken object is correct" '
	echo $bogus_short_size >expect &&
	but cat-file -s --allow-unknown-type $bogus_short_sha1 >actual &&
	test_cmp expect actual
'

test_expect_success 'clean up broken object' '
	rm .but/objects/$(test_oid_to_path $bogus_short_sha1)
'

test_expect_success "Type of broken object is correct when type is large" '
	echo $bogus_long_type >expect &&
	but cat-file -t --allow-unknown-type $bogus_long_sha1 >actual &&
	test_cmp expect actual
'

test_expect_success "Size of large broken object is correct when type is large" '
	echo $bogus_long_size >expect &&
	but cat-file -s --allow-unknown-type $bogus_long_sha1 >actual &&
	test_cmp expect actual
'

test_expect_success 'clean up broken object' '
	rm .but/objects/$(test_oid_to_path $bogus_long_sha1)
'

test_expect_success 'cat-file -t and -s on corrupt loose object' '
	but init --bare corrupt-loose.but &&
	(
		cd corrupt-loose.but &&

		# Setup and create the empty blob and its path
		empty_path=$(but rev-parse --but-path objects/$(test_oid_to_path "$EMPTY_BLOB")) &&
		but hash-object -w --stdin </dev/null &&

		# Create another blob and its path
		echo other >other.blob &&
		other_blob=$(but hash-object -w --stdin <other.blob) &&
		other_path=$(but rev-parse --but-path objects/$(test_oid_to_path "$other_blob")) &&

		# Before the swap the size is 0
		cat >out.expect <<-EOF &&
		0
		EOF
		but cat-file -s "$EMPTY_BLOB" >out.actual 2>err.actual &&
		test_must_be_empty err.actual &&
		test_cmp out.expect out.actual &&

		# Swap the two to corrupt the repository
		mv -f "$other_path" "$empty_path" &&
		test_must_fail but fsck 2>err.fsck &&
		grep "hash-path mismatch" err.fsck &&

		# confirm that cat-file is reading the new swapped-in
		# blob...
		cat >out.expect <<-EOF &&
		blob
		EOF
		but cat-file -t "$EMPTY_BLOB" >out.actual 2>err.actual &&
		test_must_be_empty err.actual &&
		test_cmp out.expect out.actual &&

		# ... since it has a different size now.
		cat >out.expect <<-EOF &&
		6
		EOF
		but cat-file -s "$EMPTY_BLOB" >out.actual 2>err.actual &&
		test_must_be_empty err.actual &&
		test_cmp out.expect out.actual &&

		# So far "cat-file" has been happy to spew the found
		# content out as-is. Try to make it zlib-invalid.
		mv -f other.blob "$empty_path" &&
		test_must_fail but fsck 2>err.fsck &&
		grep "^error: inflate: data stream error (" err.fsck
	)
'

# Tests for but cat-file --follow-symlinks
test_expect_success 'prep for symlink tests' '
	echo_without_newline "$hello_content" >morx &&
	test_ln_s_add morx same-dir-link &&
	test_ln_s_add dir link-to-dir &&
	test_ln_s_add ../fleem out-of-repo-link &&
	test_ln_s_add .. out-of-repo-link-dir &&
	test_ln_s_add same-dir-link link-to-link &&
	test_ln_s_add nope broken-same-dir-link &&
	mkdir dir &&
	test_ln_s_add ../morx dir/parent-dir-link &&
	test_ln_s_add .. dir/link-dir &&
	test_ln_s_add ../../escape dir/out-of-repo-link &&
	test_ln_s_add ../.. dir/out-of-repo-link-dir &&
	test_ln_s_add nope dir/broken-link-in-dir &&
	mkdir dir/subdir &&
	test_ln_s_add ../../morx dir/subdir/grandparent-dir-link &&
	test_ln_s_add ../../../great-escape dir/subdir/out-of-repo-link &&
	test_ln_s_add ../../.. dir/subdir/out-of-repo-link-dir &&
	test_ln_s_add ../../../ dir/subdir/out-of-repo-link-dir-trailing &&
	test_ln_s_add ../parent-dir-link dir/subdir/parent-dir-link-to-link &&
	echo_without_newline "$hello_content" >dir/subdir/ind2 &&
	echo_without_newline "$hello_content" >dir/ind1 &&
	test_ln_s_add dir dirlink &&
	test_ln_s_add dir/subdir subdirlink &&
	test_ln_s_add subdir/ind2 dir/link-to-child &&
	test_ln_s_add dir/link-to-child link-to-down-link &&
	test_ln_s_add dir/.. up-down &&
	test_ln_s_add dir/../ up-down-trailing &&
	test_ln_s_add dir/../morx up-down-file &&
	test_ln_s_add dir/../../morx up-up-down-file &&
	test_ln_s_add subdirlink/../../morx up-two-down-file &&
	test_ln_s_add loop1 loop2 &&
	test_ln_s_add loop2 loop1 &&
	but add morx dir/subdir/ind2 dir/ind1 &&
	but cummit -am "test" &&
	echo $hello_sha1 blob $hello_size >found
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for non-links' '
	echo HEAD:morx | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo HEAD:nope missing >expect &&
	echo HEAD:nope | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for in-repo, same-dir links' '
	echo HEAD:same-dir-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for in-repo, links to dirs' '
	echo HEAD:link-to-dir/ind1 | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'


test_expect_success 'but cat-file --batch-check --follow-symlinks works for broken in-repo, same-dir links' '
	echo dangling 25 >expect &&
	echo HEAD:broken-same-dir-link >>expect &&
	echo HEAD:broken-same-dir-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for same-dir links-to-links' '
	echo HEAD:link-to-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for parent-dir links' '
	echo HEAD:dir/parent-dir-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo notdir 29 >expect &&
	echo HEAD:dir/parent-dir-link/nope >>expect &&
	echo HEAD:dir/parent-dir-link/nope | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for .. links' '
	echo dangling 22 >expect &&
	echo HEAD:dir/link-dir/nope >>expect &&
	echo HEAD:dir/link-dir/nope | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:dir/link-dir/morx | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo dangling 27 >expect &&
	echo HEAD:dir/broken-link-in-dir >>expect &&
	echo HEAD:dir/broken-link-in-dir | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for ../.. links' '
	echo notdir 41 >expect &&
	echo HEAD:dir/subdir/grandparent-dir-link/nope >>expect &&
	echo HEAD:dir/subdir/grandparent-dir-link/nope | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:dir/subdir/grandparent-dir-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo HEAD:dir/subdir/parent-dir-link-to-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for dir/ links' '
	echo dangling 17 >expect &&
	echo HEAD:dirlink/morx >>expect &&
	echo HEAD:dirlink/morx | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo $hello_sha1 blob $hello_size >expect &&
	echo HEAD:dirlink/ind1 | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for dir/subdir links' '
	echo dangling 20 >expect &&
	echo HEAD:subdirlink/morx >>expect &&
	echo HEAD:subdirlink/morx | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:subdirlink/ind2 | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for dir ->subdir links' '
	echo notdir 27 >expect &&
	echo HEAD:dir/link-to-child/morx >>expect &&
	echo HEAD:dir/link-to-child/morx | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:dir/link-to-child | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo HEAD:link-to-down-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for out-of-repo symlinks' '
	echo symlink 8 >expect &&
	echo ../fleem >>expect &&
	echo HEAD:out-of-repo-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo symlink 2 >expect &&
	echo .. >>expect &&
	echo HEAD:out-of-repo-link-dir | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for out-of-repo symlinks in dirs' '
	echo symlink 9 >expect &&
	echo ../escape >>expect &&
	echo HEAD:dir/out-of-repo-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo symlink 2 >expect &&
	echo .. >>expect &&
	echo HEAD:dir/out-of-repo-link-dir | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for out-of-repo symlinks in subdirs' '
	echo symlink 15 >expect &&
	echo ../great-escape >>expect &&
	echo HEAD:dir/subdir/out-of-repo-link | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo symlink 2 >expect &&
	echo .. >>expect &&
	echo HEAD:dir/subdir/out-of-repo-link-dir | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo symlink 3 >expect &&
	echo ../ >>expect &&
	echo HEAD:dir/subdir/out-of-repo-link-dir-trailing | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch-check --follow-symlinks works for symlinks with internal ..' '
	echo HEAD: | but cat-file --batch-check >expect &&
	echo HEAD:up-down | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:up-down-trailing | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:up-down-file | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual &&
	echo symlink 7 >expect &&
	echo ../morx >>expect &&
	echo HEAD:up-up-down-file | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual &&
	echo HEAD:up-two-down-file | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp found actual
'

test_expect_success 'but cat-file --batch-check --follow-symlink breaks loops' '
	echo loop 10 >expect &&
	echo HEAD:loop1 >>expect &&
	echo HEAD:loop1 | but cat-file --batch-check --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'but cat-file --batch --follow-symlink returns correct sha and mode' '
	echo HEAD:morx | but cat-file --batch >expect &&
	echo HEAD:morx | but cat-file --batch --follow-symlinks >actual &&
	test_cmp expect actual
'

test_expect_success 'cat-file --batch-all-objects shows all objects' '
	# make new repos so we know the full set of objects; we will
	# also make sure that there are some packed and some loose
	# objects, some referenced and some not, some duplicates, and that
	# there are some available only via alternates.
	but init all-one &&
	(
		cd all-one &&
		echo content >file &&
		but add file &&
		but cummit -qm base &&
		but rev-parse HEAD HEAD^{tree} HEAD:file &&
		but repack -ad &&
		echo not-cloned | but hash-object -w --stdin
	) >expect.unsorted &&
	but clone -s all-one all-two &&
	(
		cd all-two &&
		echo local-unref | but hash-object -w --stdin
	) >>expect.unsorted &&
	but -C all-two rev-parse HEAD:file |
		but -C all-two pack-objects .but/objects/pack/pack &&
	sort <expect.unsorted >expect &&
	but -C all-two cat-file --batch-all-objects \
				--batch-check="%(objectname)" >actual &&
	test_cmp expect actual
'

# The only user-visible difference is that the objects are no longer sorted,
# and the resulting sort order is undefined. So we can only check that it
# produces the same objects as the ordered case, but that at least exercises
# the code.
test_expect_success 'cat-file --unordered works' '
	but -C all-two cat-file --batch-all-objects --unordered \
				--batch-check="%(objectname)" >actual.unsorted &&
	sort <actual.unsorted >actual &&
	test_cmp expect actual
'

test_expect_success 'set up object list for --batch-all-objects tests' '
	but -C all-two cat-file --batch-all-objects --batch-check="%(objectname)" >objects
'

test_expect_success 'cat-file --batch="%(objectname)" with --batch-all-objects will work' '
	but -C all-two cat-file --batch="%(objectname)" <objects >expect &&
	but -C all-two cat-file --batch-all-objects --batch="%(objectname)" >actual &&
	cmp expect actual
'

test_expect_success 'cat-file --batch="%(rest)" with --batch-all-objects will work' '
	but -C all-two cat-file --batch="%(rest)" <objects >expect &&
	but -C all-two cat-file --batch-all-objects --batch="%(rest)" >actual &&
	cmp expect actual
'

test_expect_success 'cat-file --batch="batman" with --batch-all-objects will work' '
	but -C all-two cat-file --batch="batman" <objects >expect &&
	but -C all-two cat-file --batch-all-objects --batch="batman" >actual &&
	cmp expect actual
'

test_expect_success 'set up replacement object' '
	orig=$(but rev-parse HEAD) &&
	but cat-file cummit $orig >orig &&
	{
		cat orig &&
		echo extra
	} >fake &&
	fake=$(but hash-object -t cummit -w fake) &&
	orig_size=$(but cat-file -s $orig) &&
	fake_size=$(but cat-file -s $fake) &&
	but replace $orig $fake
'

test_expect_success 'cat-file --batch respects replace objects' '
	but cat-file --batch >actual <<-EOF &&
	$orig
	EOF
	{
		echo "$orig cummit $fake_size" &&
		cat fake &&
		echo
	} >expect &&
	test_cmp expect actual
'

test_expect_success 'cat-file --batch-check respects replace objects' '
	but cat-file --batch-check >actual <<-EOF &&
	$orig
	EOF
	echo "$orig cummit $fake_size" >expect &&
	test_cmp expect actual
'

# Pull the entry for object with oid "$1" out of the output of
# "cat-file --batch", including its object content (which requires
# parsing and reading a set amount of bytes, hence perl).
extract_batch_output () {
    perl -ne '
	BEGIN { $oid = shift }
	if (/^$oid \S+ (\d+)$/) {
	    print;
	    read STDIN, my $buf, $1;
	    print $buf;
	    print "\n";
	}
    ' "$@"
}

test_expect_success 'cat-file --batch-all-objects --batch ignores replace' '
	but cat-file --batch-all-objects --batch >actual.raw &&
	extract_batch_output $orig <actual.raw >actual &&
	{
		echo "$orig cummit $orig_size" &&
		cat orig &&
		echo
	} >expect &&
	test_cmp expect actual
'

test_expect_success 'cat-file --batch-all-objects --batch-check ignores replace' '
	but cat-file --batch-all-objects --batch-check >actual.raw &&
	grep ^$orig actual.raw >actual &&
	echo "$orig cummit $orig_size" >expect &&
	test_cmp expect actual
'
test_expect_success 'batch-command empty command' '
	echo "" >cmd &&
	test_expect_code 128 but cat-file --batch-command <cmd 2>err &&
	grep "^fatal:.*empty command in input.*" err
'

test_expect_success 'batch-command whitespace before command' '
	echo " info deadbeef" >cmd &&
	test_expect_code 128 but cat-file --batch-command <cmd 2>err &&
	grep "^fatal:.*whitespace before command.*" err
'

test_expect_success 'batch-command unknown command' '
	echo unknown_command >cmd &&
	test_expect_code 128 but cat-file --batch-command <cmd 2>err &&
	grep "^fatal:.*unknown command.*" err
'

test_expect_success 'batch-command missing arguments' '
	echo "info" >cmd &&
	test_expect_code 128 but cat-file --batch-command <cmd 2>err &&
	grep "^fatal:.*info requires arguments.*" err
'

test_expect_success 'batch-command flush with arguments' '
	echo "flush arg" >cmd &&
	test_expect_code 128 but cat-file --batch-command --buffer <cmd 2>err &&
	grep "^fatal:.*flush takes no arguments.*" err
'

test_expect_success 'batch-command flush without --buffer' '
	echo "flush" >cmd &&
	test_expect_code 128 but cat-file --batch-command <cmd 2>err &&
	grep "^fatal:.*flush is only for --buffer mode.*" err
'

test_done
