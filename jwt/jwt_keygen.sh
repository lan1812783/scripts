#!/bin/bash

SCRIPT_EXECUTION_PATH=$0
OUT_DIR=$(dirname "$(readlink -f "$0")")
# mkdir -p "$OUT_DIR" # in case the output directory is different from where this script lives

echo

# --- Help ---

printUsageThenDie() {
  EXIT_CODE=$1

  for _JWT_ALGO in "${ALGORITHMS[@]}"; do
    [[ -z $JWT_ALGORITHMS ]] && JWT_ALGORITHMS=$_JWT_ALGO && continue
    JWT_ALGORITHMS="$JWT_ALGORITHMS | $_JWT_ALGO"
  done

  echo "Usage: ./$SCRIPT_EXECUTION_PATH [<option=value>...]"
  echo -e "\t[<option[=value>...]]: one or more options"
  echo -e "\t\t-h, --help: print help"
  echo -e "\t\t-len, --key-length: key length in bytes (not for ES algorithm)"
  echo -e "\t\t-f, --file: the output filename"
  echo -e "\t\t-alg, --algorithm: JWT algorithm (HS is not supported yet, it's a symmetric encryption)"
  echo -e "\t\t\t$JWT_ALGORITHMS"
  echo
  echo "Example: ./$SCRIPT_EXECUTION_PATH --algorithm=RS256 --key-length=2048 --file=key_rsa256"
  echo
  echo "For safety reason this script generates encryption keys and put those keys in the same directory where this script lives"
  echo
  exit "$EXIT_CODE"
}

# --- Constants ---

ALGORITHMS=(
  # "HS256" "HS384" "HS512" # not yet support HS (symmetric) algorithm
  "RS256" "RS384" "RS512"
  "PS256" "PS384" "PS512"
  "ES256" "ES384" "ES512"
)
DEF_JWT_ALGO=RS256
DEF_KEY_LENGTH=4096
DEF_FILE_PREFIX="jwt_"

# --- Argument processing ---

ARGS=("$@")
for OPTION in "${ARGS[@]}"; do
  if [[ $OPTION =~ ^-alg=.* || $OPTION =~ ^--algorithm=.* ]]; then
    IN_JWT_ALGO=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-len=.* || $OPTION =~ ^--key-length=.* ]]; then
    IN_KEY_LENGTH=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-f=.* || $OPTION =~ ^--file=.* ]]; then
    IN_FILE=$(echo "$OPTION" | cut -d '=' -f 2-)
  elif [[ $OPTION =~ ^-h$ || $OPTION =~ ^--help$ ]]; then
    printUsageThenDie 0
  else
    echo "Encounter invalid option: $OPTION"
    echo
    printUsageThenDie 1
  fi
done

# Algorithm
processAlgorithm() {
  [[ -z $IN_JWT_ALGO ]] && JWT_ALGO=$DEF_JWT_ALGO && return

  for JWT_ALGO in "${ALGORITHMS[@]}"; do
    [[ $IN_JWT_ALGO == "$JWT_ALGO" ]] && JWT_ALGO_FOUND=true && break
  done

  [[ $JWT_ALGO_FOUND != true ]] && echo "Unsupported JWT algorithm: $IN_JWT_ALGO, please choose another one, consult help for more infomation" && echo && printUsageThenDie 1
}
processAlgorithm

# Key length
[[ -n $IN_KEY_LENGTH ]] && KEY_LENGTH=$IN_KEY_LENGTH || KEY_LENGTH=$DEF_KEY_LENGTH

# Output key pair files
processFilePath() {
  if [[ -z $IN_FILE ]]; then
    PRIVATE_KEY_PATH=$OUT_DIR/$DEF_FILE_PREFIX$JWT_ALGO
    return
  fi
  PRIVATE_KEY_PATH=$OUT_DIR/$IN_FILE
}
processFilePath
PUBLIC_KEY_PATH=$PRIVATE_KEY_PATH.pub

# --- Infomation ---

info() {
  echo "========== Information =========="
  echo "JWT algorithm: $JWT_ALGO"
  [[ ! $JWT_ALGO =~ ^ES.* ]] && echo "Key length: $KEY_LENGTH"
  [[ $JWT_ALGO =~ ^ES.* ]] && echo "Curve name: $CURVE_NAME"
  echo "Private key: $PRIVATE_KEY_PATH"
  echo "Public key: $PUBLIC_KEY_PATH"
  echo "================================="
  echo

  [[ -f $PRIVATE_KEY_PATH ]] && echo "$PRIVATE_KEY_PATH already exist!" && echo && exit 1
  [[ -f $PUBLIC_KEY_PATH ]] && echo "$PUBLIC_KEY_PATH already exist!" && echo && exit 1
}

# --- Key pair generation ---

runCmd() {
  CMD=$1
  [[ -z $CMD ]] && echo "[runCmd] please supply command to run" && echo && exit 1

  echo "$CMD"
  $CMD
  echo
}

rsassa() {
  info

  runCmd "ssh-keygen -t rsa -b $KEY_LENGTH -m PEM -f $PRIVATE_KEY_PATH"

  runCmd "openssl rsa -in $PRIVATE_KEY_PATH -pubout -outform PEM -out $PUBLIC_KEY_PATH"
}

ecdsa() {
  # Supported curves: openssl ecparam -list_curves
  CURVE_NAME=$1
  [[ -z $CURVE_NAME ]] && echo "[ecdsa] please supply a curve" && echo && exit 1
  
  info

  runCmd "openssl ecparam -genkey -name $CURVE_NAME -noout -out $PRIVATE_KEY_PATH"

  runCmd "openssl ec -in $PRIVATE_KEY_PATH -pubout -out $PUBLIC_KEY_PATH"
}

# Reference:
#   https://gist.github.com/ygotthilf/baa58da5c3dd1f69fae9
#   https://github.com/northbright/Notes/blob/master/jwt/generate_keys_for_jwt_alg.md
case "$JWT_ALGO" in
  "RS256")
    rsassa
    ;;
  "RS384")
    rsassa
    ;;
  "RS512")
    rsassa
    ;;
  "PS254")
    rsassa
    ;;
  "PS384")
    rsassa
    ;;
  "PS512")
    rsassa
    ;;
  "ES256")
    ecdsa "prime256v1"
    ;;
  "ES384")
    ecdsa "secp384r1"
    ;;
  "ES512")
    ecdsa "secp521r1"
    ;;
  *)
    echo "Unsupported JWT algorithm: $IN_JWT_ALGO, please choose another one, consult help for more infomation"
    echo
    printUsageThenDie 1
esac
