#!/bin/bash

##### Definitions #####

# Path to the icon file to be displayed in the notification
NOTIF_ICON_PATH=
# The summary of the notification
NOTIF_SUMMARY=''
# The command intended to run
CMD=''

##### End definitions #####

function notify() {
  NOTIF_BODY=$1
  notify-send -i "$NOTIF_ICON_PATH" "$NOTIF_SUMMARY" "$NOTIF_BODY"
}

notify 'Starts...'

# Needs 2>&1 because 'time' command writes statistics to STDERR
# Ref: https://askubuntu.com/a/1263469
ELAPSED=$(TIMEFORMAT=%R; (time $CMD) 2>&1)

EXIT_CODE=$?
if [[ $EXIT_CODE == 0 ]]; then
  notify "Done! Elapsed: ${ELAPSED}s."
else
  notify "Failed! Exit code: $EXIT_CODE. Elapsed: ${ELAPSED}s."
fi
