#!/bin/bash
# Run all tests for the bashlib

ROOT_DIR=$(realpath $(dirname $0))
TESTS_DIR=$ROOT_DIR/test
TESTS_DEBUG=${TESTS_DEBUG:-}

cd $ROOT_DIR

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
TESTS_FAILED_ASSERT=0
TESTS_FAILED_EXIT=0
TESTS_SKIPPED=0

TESTS_FAILURES=$(mktemp -t tcdiff.XXXXXXXX)
TESTS_SKIPPED_LIST=$(mktemp -t skipped.XXXXXXXX)

# Test runner core routines

# Common initialization for every test case
testcase_setup_common()
{
    source bashlib

    debug -n "Testcase ${testcase#bl_test_}..."

    # This is a hack needed to force the PID to the sub-shell's PID
    # Bash 3 does not evaluate $$ correctly in a sub-shell.
    # In Bash 4, the sub-shell's PID is available in $BASHPID
    if [[ ${BASH_VERSINFO[0]} != "4" ]]
    then
        BASHLIB_TOP_PID=$(bash -c 'echo $PPID')
    fi

    BASHLIB_TESTCASE_STDOUT=$(mktemp -t stdout.XXXXXXXX)
    BASHLIB_TESTCASE_STDERR=$(mktemp -t stderr.XXXXXXXX)
    BASHLIB_TESTCASE_EXPOUT=$(mktemp -t expout.XXXXXXXX)
    BASHLIB_TESTCASE_EXPERR=$(mktemp -t experr.XXXXXXXX)

    # Save original file handles
    exec 7>&1
    exec 8>&2

    exec 1>$BASHLIB_TESTCASE_STDOUT
    exec 2>$BASHLIB_TESTCASE_STDERR

    trap 'test_cleanup $?' EXIT

    # Default expected result is to exit successfully
    BASHLIB_TESTCASE_RESULT=0
}

testcase_delete_file()
{
    if [[ -n "$1" ]]
    then
        rm -f "$1"
    fi
}

testcase_cleanup_temp_files()
{
    testcase_delete_file "$BASHLIB_TESTCASE_STDOUT"
    testcase_delete_file "$BASHLIB_TESTCASE_STDERR"
    testcase_delete_file "$BASHLIB_TESTCASE_EXPOUT"
    testcase_delete_file "$BASHLIB_TESTCASE_EXPERR"

    unset BASHLIB_TESTCASE_STDOUT
    unset BASHLIB_TESTCASE_STDERR
    unset BASHLIB_TESTCASE_EXPOUT
    unset BASHLIB_TESTCASE_EXPERR
}

# Common cleanup for every test case
test_cleanup()
{
    tc_result="$1"

    # Restore original file handles
    exec 1>&7
    exec 2>&8

    exec 7>&-
    exec 8>&-

    # Compare the exit code with expected value
    if [[ $tc_result == $BASHLIB_TESTCASE_RESULT ]]
    then
        tc_result=0
        if ! diff -q $BASHLIB_TESTCASE_STDOUT $BASHLIB_TESTCASE_EXPOUT &>/dev/null
        then
            tc_result=1
            echo -e "\nSTDOUT Failure in $testcase" >> "$TESTS_FAILURES"
            diff $BASHLIB_TESTCASE_EXPOUT $BASHLIB_TESTCASE_STDOUT >> "$TESTS_FAILURES"
        elif ! diff -q $BASHLIB_TESTCASE_STDERR $BASHLIB_TESTCASE_EXPERR &>/dev/null
        then
            tc_result=2
            echo -e "\nSTDERR Failure in $testcase" >> "$TESTS_FAILURES"
            diff $BASHLIB_TESTCASE_EXPERR $BASHLIB_TESTCASE_STDERR >> "$TESTS_FAILURES"
        fi
    else
        if [[ $tc_result == 3 ]]
        then
            echo -e "\nASSERT Failure in $testcase" >> "$TESTS_FAILURES"
            echo "Expect: True" >> "$TESTS_FAILURES"
            echo "Actual: False" >> "$TESTS_FAILURES"
        elif [[ $tc_result == 4 ]]
        then
            echo -e "\nASSERT Failure in $testcase" >> "$TESTS_FAILURES"
            echo "Expect: False" >> "$TESTS_FAILURES"
            echo "Actual: True" >> "$TESTS_FAILURES"
        elif [[ $tc_result == 255 ]]
        then
            # Do nothing, this is a skipped test case
            echo "${testcase#bl_test_}" >> "$TESTS_SKIPPED_LIST"
        else
            echo -e "\nEXIT_CODE Failure in $testcase" >> "$TESTS_FAILURES"
            diff <(echo $BASHLIB_TESTCASE_RESULT) <(echo  $tc_result) >> "$TESTS_FAILURES"
        fi
    fi

    if [ ${TESTS_DEBUG:-0} -gt 1 ]
    then
        echo
        echo "Expect STDOUT:"
        sed 's/^/\t/' $BASHLIB_TESTCASE_EXPOUT
        echo "Actual STDOUT:"
        sed 's/^/\t/' $BASHLIB_TESTCASE_STDOUT
        echo

        echo "Expect STDERR:"
        sed 's/^/\t/' $BASHLIB_TESTCASE_EXPERR
        echo "Actual STDERR:"
        sed 's/^/\t/' $BASHLIB_TESTCASE_STDERR
        echo

        echo -n 'Testcase result: '
    fi
    testcase_cleanup_temp_files

    exit $tc_result
}

# Assertations
expect_raise()
{
    BASHLIB_TESTCASE_RESULT=${1:-0}
}

expect_stdout()
{
    echo -e "$@" >> $BASHLIB_TESTCASE_EXPOUT
}

expect_stderr()
{
    echo -e "$@" >> $BASHLIB_TESTCASE_EXPERR
}

# Test status for each command
expect_true()
{
    if "$@"; then
        return 0
    else
        return 3
    fi
}

expect_false()
{
    if ! "$@"; then
        return 0
    else
        return 4
    fi
}

skip_test()
{
    return 255
}

check_status()
{
    status=${status:-0}
    case $status in
    0)
        debug PASS || echo -n .
        ((TESTS_PASSED++))
        ;;
    1)
        debug "FAIL <stdout>" || echo -n F
        ((TESTS_FAILED_STDOUT++))
        ;;
    2)
        debug "FAIL <stderr>" || echo -n E
        ((TESTS_FAILED_STDERR++))
        ;;
    3|4)
        debug "FAIL <assert>" || echo -n A
        ((TESTS_FAILED_ASSERT++))
        ;;
    255)
        debug "SKIPPED" || echo -n S
        ((TESTS_SKIPPED++))
        ;;
    *)
        debug "FAIL <exit_code>" || echo -n X
        ((TESTS_FAILED_EXIT++))
        ;;
    esac

    unset status
}
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
if [ $TESTS_SKIPPED -gt 0 ]
then
    echo "Tests Skipped = $TESTS_SKIPPED"
fi
echo "Total Tests = $(($TESTS_PASSED + $TESTS_FAILED_STDOUT + $TESTS_FAILED_STDERR + $TESTS_FAILED_ASSERT + $TESTS_FAILED_EXIT + $TESTS_SKIPPED))"

if [[ -s "$TESTS_SKIPPED_LIST" ]]
then
    echo
    echo "Skipped tests"
    echo "============="

    cat "$TESTS_SKIPPED_LIST"
fi

if [[ -s "$TESTS_FAILURES" ]]
then
    echo
    echo "Failures observed"
    echo "================="

    cat "$TESTS_FAILURES"

    echo 
    echo "STDOUT failures = $TESTS_FAILED_STDOUT"
    echo "STDERR failures = $TESTS_FAILED_STDERR"
    echo "ASSERT failures = $TESTS_FAILED_ASSERT"
    echo "EXIT_CODE failures = $TESTS_FAILED_EXIT"
fi

rm -f "$TESTS_FAILURES"
rm -f "$TESTS_SKIPPED_LIST"

