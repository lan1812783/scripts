#!/bin/bash

##### Definitions #####

# Path to the icon file to be displayed in the notification
NOTIF_ICON_PATH=
# The summary of the notification
NOTIF_SUMMARY=''
# The commands intended to run, seperated by ; or && or ||
CMD=''

##### End definitions #####

function notify() {
  NOTIF_BODY=$1
  notify-send -i "$NOTIF_ICON_PATH" "$NOTIF_SUMMARY" "$NOTIF_BODY"
}

function normalizeSec() {
  NEXT_MAJOR_TIME=$1
  UNITS=(s m h)
  for UNIT in "${UNITS[@]}"; do
    REMAINDER=$NEXT_MAJOR_TIME
    if (( $(echo "$NEXT_MAJOR_TIME > 60" | bc -l) )); then
      NEXT_MAJOR_TIME=$(echo "$NEXT_MAJOR_TIME / 60 / 1" | bc)
      REMAINDER=$(echo "$REMAINDER - $NEXT_MAJOR_TIME * 60" | bc -l)
      NORMALIZED_TIME=$REMAINDER$UNIT$NORMALIZED_TIME
    else
      NORMALIZED_TIME=$REMAINDER$UNIT$NORMALIZED_TIME
      break
    fi
  done
}

notify 'Starts...'

# Needs 2>&1 at the end because 'time' command writes statistics to STDERR
# Ref: https://askubuntu.com/a/1263469
# Use bash -c to execute the commands, because without it the variable would
# treat the entire string as a single command, with the first word as the
# primary command, and the rest as the command arguments
# Ref: https://stackoverflow.com/a/47289872,
# https://stackoverflow.com/a/29037820
OUTPUT=$(TIMEFORMAT=%R; (time bash -c "$CMD" 2>&1) 2>&1)
EXIT_CODE=$?
# Parse output
ELAPSED=$(echo "$OUTPUT" | tail -n 1)
OUTPUT=$(echo "$OUTPUT" | head -n -1)
normalizeSec "${ELAPSED/,/.}"

SCRIPT_NAME=$(basename "$0")
LOG_PATH=/tmp/${SCRIPT_NAME%.*}.log
DATE=$(date '+%d-%m-%Y %H:%M:%S')
if [[ $EXIT_CODE == 0 ]]; then
  echo "$DATE - SUCCEEDED - $NORMALIZED_TIME${OUTPUT:+ - $OUTPUT}" >> "$LOG_PATH"
else
  echo "$DATE - FAILED (EXIT_CODE: $EXIT_CODE) - $NORMALIZED_TIME${OUTPUT:+ - $OUTPUT}" >> "$LOG_PATH"
fi
notify "$([[ $EXIT_CODE == 0 ]] && echo 'Done' || echo 'Failed')!\nElapsed: $NORMALIZED_TIME.${OUTPUT:+\nLog: $LOG_PATH.}"
