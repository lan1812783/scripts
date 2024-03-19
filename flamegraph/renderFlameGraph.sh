#!/bin/bash

SCRIPT_EXECUTION_PATH=$0

echo

# --- Constants ---

DEF_FILE_POSTFIX=_flamegraph.svg
DEF_N_SAMPLES=100
DEF_INTERVAL=0.1s
DEF_FG_OPTS="--color=java"

# --- Help ---

printUsageThenDie() {
  EXIT_CODE=$1

  echo "Usage: $SCRIPT_EXECUTION_PATH --pid=<pid> [<option=value>...]"
  echo
  echo "Description: render flame graph for java process"

  echo -e "\tRequired arguments"
  echo -e "\t\t-fg-repo, --flamegraph-repository: path to the FlameGraph repository (https://github.com/brendangregg/FlameGraph.git)"
  echo -e "\t\t-p, --pid: the process id of the program to inspect"

  echo -e "\t[<option[=value>...]]: one or more options"
  echo -e "\t\t-h, --help: print help"
  echo -e "\t\t-jh, --java-home: the JAVA_HOME to use, default: the JAVA_HOME environment variable"
  echo -e "\t\t-s, --samples: number of samples to capture, default: $DEF_N_SAMPLES"
  echo -e "\t\t-i, --interval: sample capturing interval, same as the NUMBER argument of the 'sleep' command (https://man7.org/linux/man-pages/man1/sleep.1.html), default: $DEF_INTERVAL"
  echo -e "\t\t-fg-opts, --flamegraph-options: flamegraph.pl's options (https://github.com/brendangregg/FlameGraph?tab=readme-ov-file#options), default: $DEF_FG_OPTS"
  echo -e "\t\t-f, --file: the output svg filename, default: <pid>$DEF_FILE_POSTFIX"
  echo
  echo "Example:
  $SCRIPT_EXECUTION_PATH \\
    --flamegraph-repository=~/Workspace/repo/FlameGraph \\
    --pid=12345 \\
    --java-home=~/.sdkman/candidates/java/17.0.10-tem \\
    --samples=1000 \\
    --interval=0.01 \\
    --flamegraph-options='--title=\"Flame Graph: java --flamechart\"' \\
    --file=flamegraph.svg"
  echo
  exit "$EXIT_CODE"
}

# --- Argument processing ---

ARGS=("$@")
for OPTION in "${ARGS[@]}"; do
  if [[ $OPTION =~ ^-fg-repo=.* || $OPTION =~ ^--flamegraph-repository=.* ]]; then
    IN_FG_REPO=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-p=.* || $OPTION =~ ^--pid=.* ]]; then
    IN_PID=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-jh=.* || $OPTION =~ ^--java-home=.* ]]; then
    IN_JAVA_HOME=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-f=.* || $OPTION =~ ^--file=.* ]]; then
    IN_FILE=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-s=.* || $OPTION =~ ^--samples=.* ]]; then
    IN_N_SAMPLES=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-i=.* || $OPTION =~ ^--interval=.* ]]; then
    IN_INTERVAL=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-fg-opts=.* || $OPTION =~ ^--flamegraph-options=.* ]]; then
    IN_FG_OPTS=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-h$ || $OPTION =~ ^--help$ ]]; then
    printUsageThenDie 0
  else
    echo "Encounter invalid option: $OPTION"
    echo
    printUsageThenDie 1
  fi
done

# FlameGraph repository
processFgRepo() {
  if [[ -z $IN_FG_REPO ]]; then
    echo FlameGraph repository not found, please clone it first using this commnad: git clone https://github.com/brendangregg/FlameGraph.git && echo && printUsageThenDie 1
  fi
  FG_REPO=$IN_FG_REPO
}
processFgRepo

# Inspected pid
processPid() {
  if [[ -z $IN_PID ]]; then
    echo Please supply the process id && echo && printUsageThenDie 1
  fi
  PID=$IN_PID
}
processPid

# JAVA_HOME
processJavaHome() {
  if [[ -z $IN_JAVA_HOME ]]; then
    USED_JAVA_HOME=$JAVA_HOME
  else
    USED_JAVA_HOME=$IN_JAVA_HOME
  fi

  if [[ -z $USED_JAVA_HOME ]]; then
    echo "JAVA_HOME is not found" && echo && printUsageThenDie 1
  fi
}
processJavaHome

# Output flamegraph svg file
processFilePath() {
  if [[ -z $IN_FILE ]]; then
    FLAME_GRAPH_FILE=$PID$DEF_FILE_POSTFIX
  else
    FLAME_GRAPH_FILE=$IN_FILE
  fi

  if [[ -f $FLAME_GRAPH_FILE ]]; then
    read -rp "File $FLAME_GRAPH_FILE already exists, do you want to override? (Y/N): " CONFIRMATION && [[ $CONFIRMATION == [yY] || $CONFIRMATION == [yY][eE][sS] ]] || exit 1
    echo
  fi
}
processFilePath

# Number of samples
processSamples() {
  if [[ -z $IN_N_SAMPLES ]]; then
    N_SAMPLES=$DEF_N_SAMPLES
    return
  fi
  N_SAMPLES=$IN_N_SAMPLES
}
processSamples

# Interval
processInterval() {
  if [[ -z $IN_INTERVAL ]]; then
    INTERVAL=$DEF_INTERVAL
    return
  fi
  INTERVAL=$IN_INTERVAL
}
processInterval

# FlameGraph options
processFgOpts() {
  if [[ -z $IN_FG_OPTS ]]; then
    FG_OPTS=$DEF_FG_OPTS
    return
  fi
  FG_OPTS=$IN_FG_OPTS
}
processFgOpts

# --- Infomation ---

info() {
  echo "========== Information =========="
  echo "FlameGraph repository: $FG_REPO"
  echo "Process id: $PID"
  echo "JAVA_HOME: $USED_JAVA_HOME"
  echo "# of samples: $N_SAMPLES"
  echo "Interval: $INTERVAL"
  echo "flamegraph.pl's options: $FG_OPTS"
  echo "================================="
  echo
}
info

# --- Capture stack frames ---

echo -e "\033[1m> Capturing stack frames\033[0m"
JSTACK_FILE="${FLAME_GRAPH_FILE%.*}.jstack"
rm -vf "$JSTACK_FILE" # -f for 'rm' to not output error message when the file does not exist
PROGRESS_CHECKPOINTS=(0 20 40 60 80 100) # at least must have (0 100), otherwise, the below logic won't work
CHECKPOINT_IDX=0
for SAMPLE_IDX in $(seq "$N_SAMPLES"); do # from 1 to N_SAMPLES inclusive
  "$JAVA_HOME/bin/jstack" -l "$PID" >> "$JSTACK_FILE" || break

  PROGRESS=$(echo "$SAMPLE_IDX / $N_SAMPLES * 100" | bc -l)
  CHECKPOINT=${PROGRESS_CHECKPOINTS[$CHECKPOINT_IDX]}
  REACH_CHECKPOINT=$(echo "$PROGRESS >= $CHECKPOINT" | bc -l)
  [[ $REACH_CHECKPOINT == 1 ]] && TRIMMED_PROGRESS=${PROGRESS%.*} && echo -n "${TRIMMED_PROGRESS:=0}"% || echo -n .
  # Find next checkpoint index
  while [[ $REACH_CHECKPOINT == 1 ]] && (( CHECKPOINT_IDX < ${#PROGRESS_CHECKPOINTS[@]} - 1 )); do #https://stackoverflow.com/a/42745537
    (( CHECKPOINT_IDX += 1 ))
    CHECKPOINT=${PROGRESS_CHECKPOINTS[$CHECKPOINT_IDX]}
    REACH_CHECKPOINT=$(echo "$PROGRESS >= $CHECKPOINT" | bc -l)
  done

  sleep "$INTERVAL"
done
echo
echo

# --- Render flamegraph ---

echo -e "\033[1m> Rendering flamegraph\033[0m"
# shellcheck disable=SC2086 # word splitting on purpose on FG_OPTS variable
"$FG_REPO/stackcollapse-jstack.pl" "$JSTACK_FILE" 2>/dev/null | \
  "$FG_REPO/flamegraph.pl" $FG_OPTS > "$FLAME_GRAPH_FILE"
echo "Flamegraph file: $FLAME_GRAPH_FILE"
echo

# --- Clean up ---

echo -e "\033[1m> Cleaning up\033[0m"
rm -vf "$JSTACK_FILE"
echo

# ---

echo -e "\033[1m> Done!\033[0m"
echo
