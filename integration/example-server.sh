#!/bin/bash
# Starts and stops the server of one example. It stops only the server that
# it started: never other processes that have the same command line.
#
#   example-server.sh start PIDFILE LOGFILE PORT COMMAND [ARGUMENT...]
#   example-server.sh stop PIDFILE
#
# PIDFILE  the file that records the server, for example build/server.pid
#          in the example's folder
# LOGFILE  the file that gets the output of the server
# PORT     the port the server listens on. "start" fails when an other
#          process uses it.
#
# "start" first stops the server that PIDFILE records, if it still runs.
# Then it starts COMMAND in the background, in a new process group, and
# writes its process id and start time to PIDFILE.
#
# "stop" stops the server that PIDFILE records, with its child processes
# (for example the BEAM that "gleam run" starts), then removes PIDFILE. It
# sends SIGTERM first and waits at most 10 seconds. It sends SIGKILL to the
# processes that still run after that. When the process id now belongs to
# an other process (the start time is not the same), it stops nothing.
set -u

GRACE_SECONDS=10

start_time() {
  ps -o lstart= -p "$1" 2>/dev/null
}

# The process ids of the processes of the server: the process, its
# descendants and the members of its process group.
server_processes() {
  local root=$1
  local table
  table=$(ps -A -o pid= -o ppid= -o pgid=)
  local found=" $root "
  local added=1
  while [ "$added" -eq 1 ]; do
    added=0
    while read -r pid ppid pgid; do
      case "$found" in *" $pid "*) continue ;; esac
      case "$found" in
        *" $ppid "*) found="$found$pid "; added=1; continue ;;
      esac
      if [ "$pgid" = "$root" ]; then
        found="$found$pid "
        added=1
      fi
    done <<EOF
$table
EOF
  done
  echo "$found"
}

any_alive() {
  for pid in "$@"; do
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

stop_server() {
  local pidfile=$1
  [ -f "$pidfile" ] || return 0
  local pid recorded
  pid=$(sed -n 1p "$pidfile")
  recorded=$(sed -n 2p "$pidfile")
  if [ -n "$pid" ] && [ -n "$recorded" ] \
    && [ "$(start_time "$pid")" = "$recorded" ]; then
    # shellcheck disable=SC2046
    set -- $(server_processes "$pid")
    echo "Stopping the server of $pidfile (process $pid)..."
    kill -TERM "$@" 2>/dev/null
    local waited=0
    while any_alive "$@" && [ "$waited" -lt "$GRACE_SECONDS" ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if any_alive "$@"; then
      echo "The server did not stop in $GRACE_SECONDS seconds. Sending SIGKILL."
      kill -KILL "$@" 2>/dev/null
    fi
  fi
  rm -f "$pidfile"
}

case "${1:-}" in
  start)
    if [ "$#" -lt 5 ]; then
      echo "Usage: $0 start PIDFILE LOGFILE PORT COMMAND [ARGUMENT...]" >&2
      exit 2
    fi
    pidfile=$2
    logfile=$3
    port=$4
    shift 4
    stop_server "$pidfile"
    if command -v lsof > /dev/null 2>&1; then
      users=$(lsof -ti:"$port" 2>/dev/null | tr '\n' ' ')
      if [ -n "$users" ]; then
        echo "Port $port is in use by process $users. Stop it, then try again." >&2
        exit 1
      fi
    fi
    mkdir -p "$(dirname "$pidfile")"
    set -m
    "$@" > "$logfile" 2>&1 &
    server=$!
    set +m
    { echo "$server"; start_time "$server"; } > "$pidfile"
    ;;
  stop)
    if [ "$#" -ne 2 ]; then
      echo "Usage: $0 stop PIDFILE" >&2
      exit 2
    fi
    stop_server "$2"
    ;;
  *)
    echo "Usage: $0 start PIDFILE LOGFILE PORT COMMAND [ARGUMENT...]" >&2
    echo "       $0 stop PIDFILE" >&2
    exit 2
    ;;
esac
