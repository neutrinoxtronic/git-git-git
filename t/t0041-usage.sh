#!/bin/sh

test_description='Test commands behavior when given invalid argument value'

BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export BUT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup ' '
	test_cummit "v1.0"
'

test_expect_success 'tag --contains <existent_tag>' '
	but tag --contains "v1.0" >actual 2>actual.err &&
	grep "v1.0" actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'tag --contains <inexistent_tag>' '
	test_must_fail but tag --contains "notag" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'tag --no-contains <existent_tag>' '
	but tag --no-contains "v1.0" >actual 2>actual.err  &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'tag --no-contains <inexistent_tag>' '
	test_must_fail but tag --no-contains "notag" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'tag usage error' '
	test_must_fail but tag --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "usage" actual.err
'

test_expect_success 'branch --contains <existent_cummit>' '
	but branch --contains "main" >actual 2>actual.err &&
	test_i18ngrep "main" actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'branch --contains <inexistent_cummit>' '
	test_must_fail but branch --no-contains "nocummit" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'branch --no-contains <existent_cummit>' '
	but branch --no-contains "main" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'branch --no-contains <inexistent_cummit>' '
	test_must_fail but branch --no-contains "nocummit" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'branch usage error' '
	test_must_fail but branch --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "usage" actual.err
'

test_expect_success 'for-each-ref --contains <existent_object>' '
	but for-each-ref --contains "main" >actual 2>actual.err &&
	test_line_count = 2 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'for-each-ref --contains <inexistent_object>' '
	test_must_fail but for-each-ref --no-contains "noobject" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'for-each-ref --no-contains <existent_object>' '
	but for-each-ref --no-contains "main" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'for-each-ref --no-contains <inexistent_object>' '
	test_must_fail but for-each-ref --no-contains "noobject" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "error" actual.err &&
	test_i18ngrep ! "usage" actual.err
'

test_expect_success 'for-each-ref usage error' '
	test_must_fail but for-each-ref --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_i18ngrep "usage" actual.err
'

test_done
