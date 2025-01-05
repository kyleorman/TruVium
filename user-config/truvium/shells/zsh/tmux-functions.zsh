#!/usr/bin/env zsh

# XDG Base Directory Specification
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Tmux configuration paths
TMUX_DATA_DIR="${XDG_DATA_HOME}/tmux"
TMUX_PERSIST_FILE="${TMUX_DATA_DIR}/persistent-sessions"

# Debug control
TMUX_DEBUG=0
TMUX_GRACE_PERIOD="${TMUX_GRACE_PERIOD:-300}" # Default to 5 minutes

debug_log() {
    if [[ "$TMUX_DEBUG" -eq 1 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Debug: $*" >&2
    fi
}

# Ensure data directory exists
if [[ ! -d "$TMUX_DATA_DIR" ]]; then
    mkdir -p "$TMUX_DATA_DIR" 2>/dev/null || {
        echo "Error: Could not create directory: $TMUX_DATA_DIR" >&2
        return 1
    }
fi

# Create persistence file if it doesn't exist
if [[ ! -f "$TMUX_PERSIST_FILE" ]]; then
    touch "$TMUX_PERSIST_FILE" 2>/dev/null || {
        echo "Error: Could not create file: $TMUX_PERSIST_FILE" >&2
        return 1
    }
fi

is_generated_session() {
    local session_name="$1"
    [[ "$session_name" =~ ^session-[0-9]+(-[0-9]+)?$ ]]
}

save_persistent_session() {
    local session_name="$1"
    if ! grep -q "^${session_name}$" "$TMUX_PERSIST_FILE"; then
        echo "$session_name" >> "$TMUX_PERSIST_FILE"
    fi
}

remove_persistent_session() {
    local session_name="$1"
    sed -i "/^${session_name}$/d" "$TMUX_PERSIST_FILE"
}

is_persistent_session() {
    local session_name="$1"
    grep -q "^${session_name}$" "$TMUX_PERSIST_FILE"
}

toggle_session_persistence() {
    if [ -n "$TMUX" ]; then
        local session_name
        session_name="$(tmux display-message -p '#S')"

        if ! is_generated_session "$session_name"; then
            tmux display-message "Cannot toggle persistence for custom-named sessions"
            return 1
        fi

        if is_persistent_session "$session_name"; then
            remove_persistent_session "$session_name"
            tmux display-message "Session marked as temporary"
        else
            save_persistent_session "$session_name"
            tmux display-message "Session marked as persistent"
        fi
    fi
}

cleanup_old_sessions() {
    local current_time
    current_time=$(date +%s)

    debug_log "Starting cleanup check at $(date)"

    tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
        if [[ -z "$session" ]] || ! tmux has-session -t "$session" 2>/dev/null; then
            continue
        fi

        if ! is_generated_session "$session" || is_persistent_session "$session"; then
            debug_log "Skipping session $session (either not generated or persistent)"
            continue
        fi

        local detached_time
        detached_time=$(tmux show-option -v -t "$session" @detached_time 2>/dev/null || echo "0")
        if [[ "$detached_time" == "0" ]]; then
            tmux set-option -t "$session" @detached_time "$(date +%s)"
            debug_log "Updated detach time for session $session"
            continue
        fi

        local detached_duration=$(( current_time - detached_time ))
        debug_log "Session $session detached for ${detached_duration}s"

        if (( detached_duration > TMUX_GRACE_PERIOD )); then
            tmux kill-session -t "$session"
            debug_log "Cleaned up session $session (detached for ${detached_duration}s)"
        fi
    done
}

force_cleanup_sessions() {
    debug_log "Starting force cleanup of all generated sessions"
    tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
        if [[ -z "$session" ]] || ! tmux has-session -t "$session" 2>/dev/null; then
            continue
        fi
        # Skip if session has an active client
        if tmux list-clients -t "$session" 2>/dev/null | grep -q .; then
            continue
        fi
        if ! is_generated_session "$session"; then
            debug_log "Skipping session $session (not generated)"
            continue
        fi
        if is_persistent_session "$session"; then
            debug_log "Skipping session $session (persistent)"
            continue
        fi
        tmux kill-session -t "$session"
        debug_log "Force cleaned session: $session"
    done
}

setup_cleanup_hook() {
    # Kill any existing cleanup loop
    stop_cleanup_hook

    # Create cleanup script with improved error handling
    local cleanup_script="${TMUX_DATA_DIR}/cleanup-loop.sh"
    cat > "$cleanup_script" << 'EOF'
#!/bin/bash

# Basic environment setup
TMUX_DATA_DIR="${HOME}/.local/share/tmux"
TMUX_PERSIST_FILE="${TMUX_DATA_DIR}/persistent-sessions"
TMUX_GRACE_PERIOD=300

# Helper functions
is_generated_session() {
    local session_name="$1"
    [[ "$session_name" =~ ^session-[0-9]+(-[0-9]+)?$ ]]
}

is_persistent_session() {
    local session_name="$1"
    grep -q "^${session_name}$" "$TMUX_PERSIST_FILE" 2>/dev/null
}

# Redirect all output to the log file
exec 1> "${TMUX_DATA_DIR}/cleanup.log"
exec 2>&1

echo "$(date): Cleanup process started"

# Main loop with error handling
while true; do
    echo "$(date): Running cleanup check"

    tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
        if [[ -z "$session" ]] || ! tmux has-session -t "$session" 2>/dev/null; then
            continue
        fi

        # Skip if session has clients
        if tmux list-clients -t "$session" 2>/dev/null | grep -q .; then
            continue
        fi

        if ! is_generated_session "$session" || is_persistent_session "$session"; then
            continue
        fi

        current_time=$(date +%s)
        detached_time=$(tmux show-option -v -t "$session" @detached_time 2>/dev/null || echo "0")

        if (( current_time - detached_time > TMUX_GRACE_PERIOD )); then
            tmux kill-session -t "$session"
            echo "$(date): Cleaned up session: $session"
        fi
    done || true

    sleep ${TMUX_GRACE_PERIOD}
done
EOF

    chmod +x "$cleanup_script"

    # Start the cleanup loop with output redirection
    nohup "$cleanup_script" > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "${TMUX_DATA_DIR}/cleanup-loop.pid"
    disown
    debug_log "Periodic cleanup hook started with PID $pid"
}

check_cleanup_hook() {
    if [[ -f "${TMUX_DATA_DIR}/cleanup-loop.pid" ]]; then
        local pid
        pid=$(<"${TMUX_DATA_DIR}/cleanup-loop.pid")
        if ps -p "$pid" >/dev/null 2>&1; then
            echo "Periodic cleanup loop is running with PID: $pid"
            return 0
        else
            echo "No periodic cleanup loop is running"
            rm -f "${TMUX_DATA_DIR}/cleanup-loop.pid"
            return 1
        fi
    else
        echo "No periodic cleanup loop is running"
        return 1
    fi
}

stop_cleanup_hook() {
    if [[ -f "${TMUX_DATA_DIR}/cleanup-loop.pid" ]]; then
        local pid
        pid=$(<"${TMUX_DATA_DIR}/cleanup-loop.pid")
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid" 2>/dev/null
            debug_log "Stopped periodic cleanup hook with PID: $pid"
        fi
        rm -f "${TMUX_DATA_DIR}/cleanup-loop.pid"
    else
        debug_log "No cleanup loop is running"
    fi
}

tmux_cmd() {
    local cmd="$1"
    shift
    case "$cmd" in
        toggle)
            toggle_session_persistence
            ;;
        cleanup-old)
            cleanup_old_sessions
            ;;
        force-cleanup)
            force_cleanup_sessions
            ;;
        start-cleanup)
            setup_cleanup_hook
            ;;
        stop-cleanup)
            stop_cleanup_hook
            ;;
        check-cleanup)
            check_cleanup_hook
            ;;
        debug)
            if [[ "$TMUX_DEBUG" -eq 1 ]]; then
                TMUX_DEBUG=0
                echo "Debug output disabled"
            else
                TMUX_DEBUG=1
                echo "Debug output enabled"
            fi
            ;;
        *)
            echo "Usage: tmux_cmd {toggle|cleanup-old|force-cleanup|start-cleanup|stop-cleanup|check-cleanup|debug}" >&2
            return 1
            ;;
    esac
}

tmux() {
    if [ -n "$TMUX" ]; then
        case "$1" in
            cmd)
                shift
                tmux_cmd "$@"
                ;;
            *)
                command tmux "$@"
                ;;
        esac
    elif [ "$#" -eq 0 ]; then
        local SESSION_NAME="session-$(date +%s)-$$" # Consistently use timestamp + PID
        command tmux new-session -As "$SESSION_NAME"
        command tmux set-option -t "$SESSION_NAME" @detached_time 0
        setup_cleanup_hook
    else
        command tmux "$@"
    fi
}
