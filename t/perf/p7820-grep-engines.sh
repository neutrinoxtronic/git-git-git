#!/bin/sh

test_description="Comparison of but-grep's regex engines

Set BUT_PERF_7820_GREP_OPTS in the environment to pass options to
but-grep. Make sure to include a leading space,
e.g. BUT_PERF_7820_GREP_OPTS=' -i'. Some options to try:

	-i
	-w
	-v
	-vi
	-vw
	-viw

If BUT_PERF_GREP_THREADS is set to a list of threads (e.g. '1 4 8'
etc.) we will test the patterns under those numbers of threads.
"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

if test -n "$BUT_PERF_GREP_THREADS"
then
	test_set_prereq PERF_GREP_ENGINES_THREADS
fi

for pattern in \
	'how.to' \
	'^how to' \
	'[how] to' \
	'\(e.t[^ ]*\|v.ry\) rare' \
	'm\(ú\|u\)lt.b\(æ\|y\)te'
do
	for engine in basic extended perl
	do
		if test $engine != "basic"
		then
			# Poor man's basic -> extended converter.
			pattern=$(echo "$pattern" | sed 's/\\//g')
		fi
		if test $engine = "perl" && ! test_have_prereq PCRE
		then
			prereq="PCRE"
		else
			prereq=""
		fi
		if ! test_have_prereq PERF_GREP_ENGINES_THREADS
		then
			test_perf $prereq "$engine grep$BUT_PERF_7820_GREP_OPTS '$pattern'" "
				but -c grep.patternType=$engine grep$BUT_PERF_7820_GREP_OPTS -- '$pattern' >'out.$engine' || :
			"
		else
			for threads in $BUT_PERF_GREP_THREADS
			do
				test_perf PTHREADS,$prereq "$engine grep$BUT_PERF_7820_GREP_OPTS '$pattern' with $threads threads" "
					but -c grep.patternType=$engine -c grep.threads=$threads grep$BUT_PERF_7820_GREP_OPTS -- '$pattern' >'out.$engine.$threads' || :
				"
			done
		fi
	done

	if ! test_have_prereq PERF_GREP_ENGINES_THREADS
	then
		test_expect_success "assert that all engines found the same for$BUT_PERF_7820_GREP_OPTS '$pattern'" '
			test_cmp out.basic out.extended &&
			if test_have_prereq PCRE
			then
				test_cmp out.basic out.perl
			fi
		'
	else
		for threads in $BUT_PERF_GREP_THREADS
		do
			test_expect_success PTHREADS "assert that all engines found the same for$BUT_PERF_7820_GREP_OPTS '$pattern' under threading" "
				test_cmp out.basic.$threads out.extended.$threads &&
				if test_have_prereq PCRE
				then
					test_cmp out.basic.$threads out.perl.$threads
				fi
			"
		done
	fi
done

test_done
