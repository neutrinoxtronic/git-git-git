#!/bin/sh

test_description='fetch/push functionality using the HTTP protocol'

BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server"
URI="$HTTPD_URL/smart/server"

grep_wrote () {
	object_count=$1
	file_name=$2
	grep 'write_pack_file/wrote.*"value":"'$1'"' $2
}

setup_client_and_server () {
	but init client &&
	test_when_finished 'rm -rf client' &&
	test_cummit -C client first_cummit &&
	test_cummit -C client second_cummit &&

	but init "$SERVER" &&
	test_when_finished 'rm -rf "$SERVER"' &&
	test_config -C "$SERVER" http.receivepack true &&
	test_cummit -C "$SERVER" unrelated_cummit &&
	but -C client push "$URI" first_cummit:refs/remotes/origin/first_cummit &&
	but -C "$SERVER" config receive.hideRefs refs/remotes/origin/first_cummit
}

test_expect_success 'push without negotiation (for comparing object counts with the next test)' '
	setup_client_and_server &&

	BUT_TRACE2_EVENT="$(pwd)/event" but -C client -c protocol.version=2 \
		push "$URI" refs/heads/main:refs/remotes/origin/main &&
	test_when_finished "rm -f event" &&
	grep_wrote 6 event # 2 cummits, 2 trees, 2 blobs
'

test_expect_success 'push with negotiation' '
	setup_client_and_server &&

	BUT_TRACE2_EVENT="$(pwd)/event" but -C client -c protocol.version=2 -c push.negotiate=1 \
		push "$URI" refs/heads/main:refs/remotes/origin/main &&
	test_when_finished "rm -f event" &&
	grep_wrote 3 event # 1 cummit, 1 tree, 1 blob
'

test_expect_success 'push with negotiation proceeds anyway even if negotiation fails' '
	setup_client_and_server &&

	# Use protocol v0 to make negotiation fail (because protocol v0 does
	# not support the "wait-for-done" capability, which is required for
	# push negotiation)
	BUT_TEST_PROTOCOL_VERSION=0 BUT_TRACE2_EVENT="$(pwd)/event" but -C client -c push.negotiate=1 \
		push "$URI" refs/heads/main:refs/remotes/origin/main 2>err &&
	test_when_finished "rm -f event" &&
	grep_wrote 6 event && # 2 cummits, 2 trees, 2 blobs

	cat >warning-expect <<-EOF &&
	warning: --negotiate-only requires protocol v2
	warning: push negotiation failed; proceeding anyway with push
EOF
	grep warning: err >warning-actual &&
	test_cmp warning-expect warning-actual
'

test_done
