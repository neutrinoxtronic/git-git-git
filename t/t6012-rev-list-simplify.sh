#!/bin/sh

test_description='merge simplification'

BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

note () {
	but tag "$1"
}

unnote () {
	test_when_finished "rm -f tmp" &&
	but name-rev --tags --annotate-stdin >tmp &&
	sed -e "s|$OID_REGEX (tags/\([^)]*\)) |\1 |g" <tmp
}

#
# Create a test repo with an interesting cummit graph:
#
# A-----B-----G--H--I--K--L
#  \     \      /     /
#   \     \    /     /
#    C--D--E--F     J
#
# The cummits are laid out from left-to-right starting with
# the root cummit A and terminating at the tip cummit L.
#
# There are a few places where we adjust the cummit date or
# author date to make the --topo-order, --date-order, and
# --author-date-order flags produce different output.

test_expect_success setup '
	echo "Hi there" >file &&
	echo "initial" >lost &&
	but add file lost &&
	test_tick && but cummit -m "Initial file and lost" &&
	note A &&

	but branch other-branch &&

	but symbolic-ref HEAD refs/heads/unrelated &&
	but rm -f "*" &&
	echo "Unrelated branch" >side &&
	but add side &&
	test_tick && but cummit -m "Side root" &&
	note J &&
	but checkout main &&

	echo "Hello" >file &&
	echo "second" >lost &&
	but add file lost &&
	test_tick && BUT_AUTHOR_DATE=$(($test_tick + 120)) but cummit -m "Modified file and lost" &&
	note B &&

	but checkout other-branch &&

	echo "Hello" >file &&
	>lost &&
	but add file lost &&
	test_tick && but cummit -m "Modified the file identically" &&
	note C &&

	echo "This is a stupid example" >another-file &&
	but add another-file &&
	test_tick && but cummit -m "Add another file" &&
	note D &&

	test_tick &&
	test_must_fail but merge -m "merge" main &&
	>lost && but cummit -a -m "merge" &&
	note E &&

	echo "Yet another" >elif &&
	but add elif &&
	test_tick && but cummit -m "Irrelevant change" &&
	note F &&

	but checkout main &&
	echo "Yet another" >elif &&
	but add elif &&
	test_tick && but cummit -m "Another irrelevant change" &&
	note G &&

	test_tick && but merge -m "merge" other-branch &&
	note H &&

	echo "Final change" >file &&
	test_tick && but cummit -a -m "Final change" &&
	note I &&

	but checkout main &&
	test_tick && but merge --allow-unrelated-histories -m "Coolest" unrelated &&
	note K &&

	echo "Immaterial" >elif &&
	but add elif &&
	test_tick && but cummit -m "Last" &&
	note L
'

FMT='tformat:%P 	%H | %s'

check_outcome () {
	outcome=$1
	shift
	for c in $1
	do
		echo "$c"
	done >expect &&
	shift &&
	param="$*" &&
	test_expect_$outcome "log $param" '
		but log --pretty="$FMT" --parents $param >out &&
		unnote >actual <out &&
		sed -e "s/^.*	\([^ ]*\) .*/\1/" >check <actual &&
		test_cmp expect check
	'
}

check_result () {
	check_outcome success "$@"
}

check_result 'L K J I H F E D C G B A' --full-history --topo-order
check_result 'L K I H G F E D C B J A' --full-history
check_result 'L K I H G F E D C B J A' --full-history --date-order
check_result 'L K I H G F E D B C J A' --full-history --author-date-order
check_result 'K I H E C B A' --full-history -- file
check_result 'K I H E C B A' --full-history --topo-order -- file
check_result 'K I H E C B A' --full-history --date-order -- file
check_result 'K I H E B C A' --full-history --author-date-order -- file
check_result 'I E C B A' --simplify-merges -- file
check_result 'I E C B A' --simplify-merges --topo-order -- file
check_result 'I E C B A' --simplify-merges --date-order -- file
check_result 'I E B C A' --simplify-merges --author-date-order -- file
check_result 'I B A' -- file
check_result 'I B A' --topo-order -- file
check_result 'I B A' --date-order -- file
check_result 'I B A' --author-date-order -- file
check_result 'H' --first-parent -- another-file
check_result 'H' --first-parent --topo-order -- another-file

check_result 'L K I H G B A' --first-parent L
check_result 'F E D C' --exclude-first-parent-only F ^L
check_result '' F ^L
check_result 'L K I H G J' L ^F
check_result 'L K I H G B J' --exclude-first-parent-only L ^F
check_result 'L K I H G B' --exclude-first-parent-only --first-parent L ^F

check_result 'E C B A' --full-history E -- lost
test_expect_success 'full history simplification without parent' '
	printf "%s\n" E C B A >expect &&
	but log --pretty="$FMT" --full-history E -- lost >out &&
	unnote >actual <out &&
	sed -e "s/^.*	\([^ ]*\) .*/\1/" >check <actual &&
	test_cmp expect check
'

test_expect_success '--full-diff is not affected by --parents' '
	but log -p --pretty="%H" --full-diff -- file >expected &&
	but log -p --pretty="%H" --full-diff --parents -- file >actual &&
	test_cmp expected actual
'

#
# Create a new history to demonstrate the value of --show-pulls
# with respect to the subtleties of simplified history, --full-history,
# and --simplify-merges.
#
#   .-A---M-----C--N---O---P
#  /     / \  \  \/   /   /
# I     B   \  R-'`-Z'   /
#  \   /     \/         /
#   \ /      /\        /
#    `---X--'  `---Y--'
#
# This example is explained in Documentation/rev-list-options.txt

test_expect_success 'setup rebuild repo' '
	rm -rf .but * &&
	but init &&
	but switch -c topic &&

	echo base >file &&
	but add file &&
	test_cummit I &&

	echo A >file &&
	but add file &&
	test_cummit A &&

	but switch -c branchB I &&
	echo B >file &&
	but add file &&
	test_cummit B &&

	but switch topic &&
	test_must_fail but merge -m "M" B &&
	echo A >file &&
	echo B >>file &&
	but add file &&
	but merge --continue &&
	note M &&

	echo C >other &&
	but add other &&
	test_cummit C &&

	but switch -c branchX I &&
	echo X >file &&
	but add file &&
	test_cummit X &&

	but switch -c branchR M &&
	but merge -m R -Xtheirs X &&
	note R &&

	but switch topic &&
	but merge -m N R &&
	note N &&

	but switch -c branchY M &&
	echo Y >y &&
	but add y &&
	test_cummit Y &&

	but switch -c branchZ C &&
	echo Z >z &&
	but add z &&
	test_cummit Z &&

	but switch topic &&
	but merge -m O Z &&
	note O &&

	but merge -m P Y &&
	note P
'

check_result 'X I' -- file
check_result 'N R X I' --show-pulls -- file

check_result 'P O N R X M B A I' --full-history --topo-order -- file
check_result 'N R X M B A I' --simplify-merges --topo-order --show-pulls -- file
check_result 'R X M B A I' --simplify-merges --topo-order -- file
check_result 'N M A I' --first-parent -- file
check_result 'N M A I' --first-parent --show-pulls -- file

# --ancestry-path implies --full-history
check_result 'P O N R M' --topo-order \
	--ancestry-path A..HEAD -- file
check_result 'P O N R M' --topo-order \
	--show-pulls \
	--ancestry-path A..HEAD -- file
check_result 'P O N R M' --topo-order \
	--full-history \
	--ancestry-path A..HEAD -- file
check_result 'R M' --topo-order \
	--simplify-merges \
	--ancestry-path A..HEAD -- file
check_result 'N R M' --topo-order \
	--simplify-merges --show-pulls \
	--ancestry-path A..HEAD -- file

test_expect_success 'log --graph --simplify-merges --show-pulls' '
	cat >expect <<-\EOF &&
	* N
	*   R
	|\  
	| * X
	* |   M
	|\ \  
	| * | B
	| |/  
	* / A
	|/  
	* I
	EOF
	but log --graph --pretty="%s" \
		--simplify-merges --show-pulls \
		-- file >actual &&
	test_cmp expect actual
'

test_done
