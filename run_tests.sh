#!/bin/bash
# Run all tests for the bashlib

TESTS_DIR=$(dirname $0)/test
TESTS_DEBUG=${TESTS_DEBUG:-}

debug()
{
    if [[ -n "$TESTS_DEBUG" ]]
    then
        echo -e "$@"
    else
        return 1
    fi
}

TESTS_PASSED=0
TESTS_FAILED_STDOUT=0
TESTS_FAILED_STDERR=0
TESTS_FAILED_EXIT=0

TESTS_FAILURES=$(mktemp -t tcdiff.XXXXXXXX)

# Search for all test files under the test folder
for testfile in $(find $TESTS_DIR -name '.*' -prune -o -type f -print)
do
    debug "Adding tests from $testfile"
    source $testfile
done

debug "Test runner PID $$"
# Search for all functions beginning with bl_test_
for testcase in $(declare -F | grep 'bl_test_' | sed 's/^.* //')
do
    ( testcase_setup_common; $testcase ) || status=$?
    check_status
done

echo
echo "Tests Passed = $TESTS_PASSED"
echo "Total Tests = $(($TESTS_PASSED + $TESTS_FAILED_STDOUT + $TESTS_FAILED_STDERR + $TESTS_FAILED_EXIT))"

if [[ -s "$TESTS_FAILURES" ]]
then
    echo
    echo "Failures observed"
    echo "================="

    cat "$TESTS_FAILURES"
    rm -f "$TESTS_FAILURES"

    echo 
    echo "STDOUT failures = $TESTS_FAILED_STDOUT"
    echo "STDERR failures = $TESTS_FAILED_STDERR"
    echo "EXIT_CODE failures = $TESTS_FAILED_EXIT"
fi


