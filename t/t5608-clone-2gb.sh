#!/bin/sh

test_description='Test cloning a repository larger than 2 gigabyte'
. ./test-lib.sh

if ! test_bool_env BUT_TEST_CLONE_2GB false
then
	skip_all='expensive 2GB clone test; enable with BUT_TEST_CLONE_2GB=true'
	test_done
fi

test_expect_success 'setup' '

	but config pack.compression 0 &&
	but config pack.depth 0 &&
	blobsize=$((100*1024*1024)) &&
	blobcount=$((2*1024*1024*1024/$blobsize+1)) &&
	i=1 &&
	(while test $i -le $blobcount
	 do
		printf "Generating blob $i/$blobcount\r" >&2 &&
		printf "blob\nmark :$i\ndata $blobsize\n" &&
		#test-tool genrandom $i $blobsize &&
		printf "%-${blobsize}s" $i &&
		echo "M 100644 :$i $i" >> cummit &&
		i=$(($i+1)) ||
		echo $? > exit-status
	 done &&
	 echo "cummit refs/heads/main" &&
	 echo "author A U Thor <author@email.com> 123456789 +0000" &&
	 echo "cummitter C O Mitter <cummitter@email.com> 123456789 +0000" &&
	 echo "data 5" &&
	 echo ">2gb" &&
	 cat cummit) |
	but fast-import --big-file-threshold=2 &&
	test ! -f exit-status

'

test_expect_success 'clone - bare' '

	but clone --bare --no-hardlinks . clone-bare

'

test_expect_success 'clone - with worktree, file:// protocol' '

	but clone "file://$(pwd)" clone-wt

'

test_done
