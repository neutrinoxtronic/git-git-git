#!/bin/sh

test_description='merge signature verification tests'
BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create signed cummits' '
	echo 1 >file && but add file &&
	test_tick && but cummit -m initial &&
	but tag initial &&

	but checkout -b side-signed &&
	echo 3 >elif && but add elif &&
	test_tick && but cummit -S -m "signed on side" &&
	but checkout initial &&

	but checkout -b side-unsigned &&
	echo 3 >foo && but add foo &&
	test_tick && but cummit -m "unsigned on side" &&
	but checkout initial &&

	but checkout -b side-bad &&
	echo 3 >bar && but add bar &&
	test_tick && but cummit -S -m "bad on side" &&
	but cat-file cummit side-bad >raw &&
	sed -e "s/^bad/forged bad/" raw >forged &&
	but hash-object -w -t cummit forged >forged.cummit &&
	but checkout initial &&

	but checkout -b side-untrusted &&
	echo 3 >baz && but add baz &&
	test_tick && but cummit -SB7227189 -m "untrusted on side" &&

	but checkout main
'

test_expect_success GPG 'merge unsigned cummit with verification' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_must_fail but merge --ff-only --verify-signatures side-unsigned 2>mergeerror &&
	test_i18ngrep "does not have a GPG signature" mergeerror
'

test_expect_success GPG 'merge unsigned cummit with merge.verifySignatures=true' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail but merge --ff-only side-unsigned 2>mergeerror &&
	test_i18ngrep "does not have a GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with bad signature with verification' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_must_fail but merge --ff-only --verify-signatures $(cat forged.cummit) 2>mergeerror &&
	test_i18ngrep "has a bad GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with bad signature with merge.verifySignatures=true' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail but merge --ff-only $(cat forged.cummit) 2>mergeerror &&
	test_i18ngrep "has a bad GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with untrusted signature with verification' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_must_fail but merge --ff-only --verify-signatures side-untrusted 2>mergeerror &&
	test_i18ngrep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with untrusted signature with verification and high minTrustLevel' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config gpg.minTrustLevel marginal &&
	test_must_fail but merge --ff-only --verify-signatures side-untrusted 2>mergeerror &&
	test_i18ngrep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with untrusted signature with verification and low minTrustLevel' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config gpg.minTrustLevel undefined &&
	but merge --ff-only --verify-signatures side-untrusted >mergeoutput &&
	test_i18ngrep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge cummit with untrusted signature with merge.verifySignatures=true' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail but merge --ff-only side-untrusted 2>mergeerror &&
	test_i18ngrep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge cummit with untrusted signature with merge.verifySignatures=true and minTrustLevel' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	test_config gpg.minTrustLevel marginal &&
	test_must_fail but merge --ff-only side-untrusted 2>mergeerror &&
	test_i18ngrep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge signed cummit with verification' '
	test_when_finished "but reset --hard && but checkout initial" &&
	but merge --verbose --ff-only --verify-signatures side-signed >mergeoutput &&
	test_i18ngrep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge signed cummit with merge.verifySignatures=true' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	but merge --verbose --ff-only side-signed >mergeoutput &&
	test_i18ngrep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge cummit with bad signature without verification' '
	test_when_finished "but reset --hard && but checkout initial" &&
	but merge $(cat forged.cummit)
'

test_expect_success GPG 'merge cummit with bad signature with merge.verifySignatures=false' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures false &&
	but merge $(cat forged.cummit)
'

test_expect_success GPG 'merge cummit with bad signature with merge.verifySignatures=true and --no-verify-signatures' '
	test_when_finished "but reset --hard && but checkout initial" &&
	test_config merge.verifySignatures true &&
	but merge --no-verify-signatures $(cat forged.cummit)
'

test_expect_success GPG 'merge unsigned cummit into unborn branch' '
	test_when_finished "but checkout initial" &&
	but checkout --orphan unborn &&
	test_must_fail but merge --verify-signatures side-unsigned 2>mergeerror &&
	test_i18ngrep "does not have a GPG signature" mergeerror
'

test_done
