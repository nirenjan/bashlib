# Bashlib logging module
#######################################################################
# This module contains wrappers to logging API. It can log to stdout,
# stderr, a custom log file, or syslog
#######################################################################

# This variable is used within the logging API to log the script name
BASHLIB_APP_NAME=$(basename $0)

#######################################################################
# Log levels
#######################################################################
BASHLIB_SYSLOG_LEVELS=(emerg alert crit err warning notice info debug)

#######################################################################
# Logging API
#######################################################################

# Get the log level given the mnemonic string
_bashlib_parse_log_level_string()
{
    local level=$(echo $1 | tr A-Z a-z)
    local log_level=3

    case "$level" in
    emerg|emergency|panic)
        BASHLIB_PARSED_LOG_LEVEL=0
        ;;

    alert)
        BASHLIB_PARSED_LOG_LEVEL=1
        ;;

    crit|critical)
        BASHLIB_PARSED_LOG_LEVEL=2
        ;;

    err|error)
        BASHLIB_PARSED_LOG_LEVEL=3
        ;;

    warning|warn)
        BASHLIB_PARSED_LOG_LEVEL=4
        ;;

    notice)
        BASHLIB_PARSED_LOG_LEVEL=5
        ;;

    info)
        BASHLIB_PARSED_LOG_LEVEL=6
        ;;

    debug)
        BASHLIB_PARSED_LOG_LEVEL=7
        ;;

    *)
        bashlib_throw "Invalid log level '$level'"
        ;;
    esac

}

# Set log level - logs below this threshold will be ignored
bashlib_set_log_level()
{
    _bashlib_parse_log_level_string $1
    BASHLIB_LOG_LEVEL=$BASHLIB_PARSED_LOG_LEVEL
    unset -v BASHLIB_PARSED_LOG_LEVEL
}

# Set log destination
bashlib_set_log_dest()
{
    local dest=$(echo $1 | tr A-Z a-z)
    local logfile=$2

    case "$dest" in
    stdout)
        BASHLIB_LOG_FORMAT='echo "%.0s%s: %s" >&1'
        ;;

    stderr)
        BASHLIB_LOG_FORMAT='echo "%.0s%s: %s" >&2'
        ;;

    syslog)
        BASHLIB_LOG_FORMAT='logger -p user.%s -t %s "%s"'
        ;;

    file)
        if [[ -z $logfile ]]
        then
            bashlib_throw "Missing required parameter - logfile"
        fi
        BASHLIB_LOG_FORMAT="echo \"%.0s%s: %s\" >>\"$logfile\""
        ;;

    *)
        bashlib_throw "Invalid log destination '$dest'"
        ;;
    esac
}

# The actual logging function
# This takes at least 2 arguments - the level at which to log, and the message(s)
bashlib_log()
{
    if (( $# < 2 ))
    then
        bashlib_throw "Insufficient number of arguments for bashlib_log"
    fi

    _bashlib_parse_log_level_string $1
    shift

    if (( $BASHLIB_PARSED_LOG_LEVEL <= $BASHLIB_LOG_LEVEL ))
    then
        local syslog_lvl="${BASHLIB_SYSLOG_LEVELS[$BASHLIB_PARSED_LOG_LEVEL]}"
        unset -v BASHLIB_PARSED_LOG_LEVEL

        for msg in "$@"
        do
            eval $(printf "$BASHLIB_LOG_FORMAT" \
                        "$syslog_lvl" \
                        "$BASHLIB_APP_NAME" \
                        "$msg")
        done
    fi

}

# Set default parameters for logging
bashlib_set_log_dest stdout
bashlib_set_log_level err

