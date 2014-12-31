# Bashlib core routines
#######################################################################
# This module contains core routines in bashlib, specifically to handle
# internal errors, diagnostics and other utilities
#######################################################################

# We need to keep a copy of the top level shell so that any throws are sent
# straight to the parent shell, instead of simply aborting the subshell
export BASHLIB_TOP_PID=${BASHPID:-$$}

# Trap to exit on receiving SIGUSR2
trap "exit 42" USR2

# Bashlib internal diagnostics - these are always logged to stderr and cause
# the script to display a stack trace and exit
bashlib_throw()
{
    for m in "$@"
    do
        echo "bashlib: $m" >&2
    done

    if [[ -z "$BASHLIB_NO_STACKTRACE" ]]
    then
        # Generate a stacktrace
        local i=0
        while caller $i >&2
        do
            ((i++))
        done
    fi

    kill -s USR2 $BASHLIB_TOP_PID
}

trap "bashlib_cleanup" EXIT

bashlib_cleanup()
{
    :
}

# Handle stacktracing
bashlib_stacktrace_disable()
{
    BASHLIB_NO_STACKTRACE=1
}

bashlib_stacktrace_enable()
{
    unset BASHLIB_NO_STACKTRACE
}
