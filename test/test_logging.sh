#!/bin/bash

bl_test_logging_bad_call_1()
{
    # Don't bother with a stacktrace
    bashlib_stacktrace_disable

    # Empty parameters
    expect_raise 42
    expect_stderr "bashlib: Insufficient number of arguments for bashlib_log"
    bashlib_log
}

bl_test_logging_bad_call_2()
{
    # Don't bother with a stacktrace
    bashlib_stacktrace_disable

    # Insufficient parameters
    expect_raise 42
    expect_stderr "bashlib: Insufficient number of arguments for bashlib_log"
    bashlib_log panic
}

bl_test_logging_bad_call_3()
{
    # Don't bother with a stacktrace
    bashlib_stacktrace_disable

    # Bad level string
    expect_raise 42
    expect_stderr "bashlib: Invalid log level 'badstring'"
    bashlib_log badstring "don't care"
}

# This is just a wrapper function to test at various config levels
blt_helper_logging_test()
{
    local set_level=$1
    local expected=$2

    # Configure logging level
    bashlib_set_log_level $set_level

    for level in ${BASHLIB_SYSLOG_LEVELS[@]}
    do
        bashlib_log $level "test"
    done

    for i in $(seq $expected)
    do
        expect_stdout "run_tests.sh: test"
    done
}

bl_test_logging_test_cfg_emerg_1()
{
    blt_helper_logging_test emerg 1
}

bl_test_logging_test_cfg_emerg_2()
{
    blt_helper_logging_test emergency 1
}

bl_test_logging_test_cfg_emerg_3()
{
    blt_helper_logging_test panic 1
}

bl_test_logging_test_cfg_alert()
{
    blt_helper_logging_test alert 2
}

bl_test_logging_test_cfg_crit_1()
{
    blt_helper_logging_test crit 3
}

bl_test_logging_test_cfg_crit_2()
{
    blt_helper_logging_test critical 3
}

bl_test_logging_test_cfg_err_1()
{
    blt_helper_logging_test err 4
}

bl_test_logging_test_cfg_err_2()
{
    blt_helper_logging_test error 4
}

bl_test_logging_test_cfg_warn_1()
{
    blt_helper_logging_test warn 5
}

bl_test_logging_test_cfg_warn_2()
{
    blt_helper_logging_test warning 5
}

bl_test_logging_test_cfg_notice()
{
    blt_helper_logging_test notice 6
}

bl_test_logging_test_cfg_info()
{
    blt_helper_logging_test info 7
}

bl_test_logging_test_cfg_debug()
{
    blt_helper_logging_test debug 8
}

bl_test_logging_dest_stdout()
{
    bashlib_set_log_dest stdout
    expect_stdout 'echo "%.0s%s: %s" >&1'
    echo $BASHLIB_LOG_FORMAT
}

bl_test_logging_dest_stderr()
{
    bashlib_set_log_dest stderr
    expect_stdout 'echo "%.0s%s: %s" >&2'
    echo $BASHLIB_LOG_FORMAT
}

bl_test_logging_dest_syslog()
{
    bashlib_set_log_dest syslog
    expect_stdout 'logger -p user.%s -t %s "%s"'
    echo $BASHLIB_LOG_FORMAT
}

bl_test_logging_dest_file_1()
{
    bashlib_stacktrace_disable
    expect_raise 42
    expect_stderr 'bashlib: Missing required parameter - logfile'
    bashlib_set_log_dest file
}

bl_test_logging_dest_file_2()
{
    expect_stdout 'echo "%.0s%s: %s" >>"foo"'
    bashlib_set_log_dest file foo
    echo $BASHLIB_LOG_FORMAT
}

bl_test_logging_dest_invalid()
{
    bashlib_stacktrace_disable
    expect_raise 42
    expect_stderr "bashlib: Invalid log destination 'foo'"
    bashlib_set_log_dest foo
}
