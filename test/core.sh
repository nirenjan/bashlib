#!/bin/bash
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
        echo -e "\nEXIT_CODE Failure in $testcase" >> "$TESTS_FAILURES"
        diff <(echo $BASHLIB_TESTCASE_RESULT) <(echo  $tc_result) >> "$TESTS_FAILURES"
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
    *)
        debug "FAIL <exit_code>" || echo -n X
        ((TESTS_FAILED_EXIT++))
        ;;
    esac

    unset status
}
