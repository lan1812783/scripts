#!/bin/bash

SCRIPT_EXECUTION_PATH=$0
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

echo

# --- Utils ---

panic() {
  MSG=$1
  EXIT_CODE=$2

  echo -e "$MSG"
  echo

  printUsageThenDie "$EXIT_CODE"
}

printUsageThenDie() {
  EXIT_CODE=$1

  echo "IMPORTANT: backup your .git/hooks folder inside the target repository before running this script, otherwise this script would override some"
  echo
  echo "Description: utillty to help setup git hooks (branch & commit naming violation checks, incremental checkstyle (java), etc) for a git repository"
  echo
  echo "Usage: ./$SCRIPT_EXECUTION_PATH [<option=value>...] <path to git repository>"
  echo -e "\t[<option[=value>...]]: one or more options"
  echo -e "\t\t-h, --help: print help"
  echo -e "\t\t-agile, --agile-commit-msg-check: setup agile commit message check"
  echo -e "\t\t-cs, --checkstyle: setup checkstyle (java only)"
  echo -e "\t\t-cs-conf, --checkstyle-config-path: specify the checkstyle config path (java only)"
  echo -e "\t\t\tPossible values:"
  echo -e "\t\t\t\tEmbedded: /sun_checks.xml (default), /google_checks.xml"
  echo -e "\t\t\t\tCustom configuration file: absolute path to the custom configuration file"
  echo
  echo "Example: ./$SCRIPT_EXECUTION_PATH --agile-commit-msg-check --checkstyle --checkstyle-config-path=/google_checks.xml path/to/git/repo"
  echo
  exit "$EXIT_CODE"
}

# --- Defaults ---

AGILE_COMMIT_MSG_CHECK=false
CHECKSTYLE=false

# --- Argument processing ---

ARGS=("$@")
for OPTION in "${ARGS[@]}"; do
  if [[ $OPTION =~ ^-agile$ || $OPTION =~ ^--agile-commit-msg-check$ ]]; then
    AGILE_COMMIT_MSG_CHECK=true
  elif [[ $OPTION =~ ^-cs$ || $OPTION =~ ^--checkstyle$ ]]; then
    CHECKSTYLE=true
  elif [[ $OPTION =~ ^-cs-conf=.* || $OPTION =~ ^--checkstyle-config-path=.* ]]; then
    CHECKSTYLE_CONFIG_PATH=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-h$ || $OPTION =~ ^--help$ ]]; then
    printUsageThenDie 0
  else
    if [[ -z $TARGET_REPO_PATH ]]; then
      # Repository path
      TARGET_REPO_PATH=$OPTION
    else
      panic "Encounter invalid option: $OPTION" 1
    fi
  fi
done

# Validate target repository
[[ -z "$TARGET_REPO_PATH" ]] && panic "Please supply a git repository" 1
[[ ! -d "$TARGET_REPO_PATH" ]] && panic "$TARGET_REPO_PATH does not exist or is not a directory" 1
[[ ! -d "$TARGET_REPO_PATH/.git" ]] && panic "$TARGET_REPO_PATH is not a git repository" 1
# Validate if target repository has atleast one commit
if ! git -C "$TARGET_REPO_PATH" rev-parse HEAD 1>/dev/null 2>&1; then
  panic "The git repository at $TARGET_REPO_PATH does not have any commit yet" 1
fi
# Validate git hooks folder
TARGET_GIT_HOOKS_PATH=$(git config --get core.hooksPath)
[[ ! -d "$TARGET_GIT_HOOKS_PATH" ]] && TARGET_GIT_HOOKS_PATH="$TARGET_REPO_PATH/.git/hooks"
[[ ! -d "$TARGET_GIT_HOOKS_PATH" ]] && panic "$TARGET_REPO_PATH/.git/hooks does not exist or is not a directory" 1
# Validate checkstyle config
SUN_CHECKS="/sun_checks.xml"
GOOGLE_CHECKS="/google_checks.xml"
[[ "$CHECKSTYLE_CONFIG_PATH" != "$SUN_CHECKS" &&
  "$CHECKSTYLE_CONFIG_PATH" != "$GOOGLE_CHECKS" &&
  ! -f "$CHECKSTYLE_CONFIG_PATH" ]] &&
  panic "$CHECKSTYLE_CONFIG_PATH does not exist or is not a file" 1

# --- Information ---

info() {
  echo "========== Information =========="
  echo "Target repository: $TARGET_REPO_PATH"
  echo "Agile commit message check: $AGILE_COMMIT_MSG_CHECK"
  echo "Checkstyle: $CHECKSTYLE"
  [[ $CHECKSTYLE == true && -n "$CHECKSTYLE_CONFIG_PATH" ]] && echo "Checkstyle config path: $CHECKSTYLE_CONFIG_PATH"
  echo "================================="
  echo
}
info

# --- Agile commit msg check ---

if [[ $AGILE_COMMIT_MSG_CHECK == true ]]; then
  AGILE_HOOK_SCRIPTS=$SCRIPT_DIR/agile-commit-msg-check
  chmod +x -R "$AGILE_HOOK_SCRIPTS"

  rsync -av --progress "$AGILE_HOOK_SCRIPTS/" "$TARGET_GIT_HOOKS_PATH"
fi

# --- Checkstyle ---

if [[ $CHECKSTYLE == true ]]; then
  CHECKSTYLE_HOOK_SCRIPTS_PATH=$SCRIPT_DIR/java/checkstyle
  chmod +x -R "$CHECKSTYLE_HOOK_SCRIPTS_PATH"

  if [[ $AGILE_COMMIT_MSG_CHECK == true ]]; then
    # Sync excluding pre-commit
    rsync -av --progress --exclude pre-commit "$CHECKSTYLE_HOOK_SCRIPTS_PATH/" "$TARGET_GIT_HOOKS_PATH"
    # Concatenate pre-commit of checkstyle (skip the first shebang line) to pre-commit of agile commit msg check
    tail -n +1 "$CHECKSTYLE_HOOK_SCRIPTS_PATH/pre-commit" >>"$TARGET_GIT_HOOKS_PATH/pre-commit"
  else
    rsync -av --progress "$CHECKSTYLE_HOOK_SCRIPTS_PATH/" "$TARGET_GIT_HOOKS_PATH"
  fi

  # Use '|' in sed expression cuz '/' would clash with path seperator
  [[ -n "$CHECKSTYLE_CONFIG_PATH" ]] &&
    sed -i "s|CHECKSTYLE_CONFIG=.*|CHECKSTYLE_CONFIG=$CHECKSTYLE_CONFIG_PATH|" "$TARGET_GIT_HOOKS_PATH/pre-commit-checkstyle"
fi

echo
echo "=========="
echo "Setup done"
echo "=========="
echo
