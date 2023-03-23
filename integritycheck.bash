#!/bin/bash
# Ralf Lange 2022

# switch to the direcory this script resides in
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if ! cd "${DIR}"; then
    echo -e "####\n#### Could not make \"${DIR}\" the current directory.\n#### Exiting.\n####"
    exit
fi

# filename of this script
THIS_SCRIPT="$(basename ${BASH_SOURCE})"

# ----------------------------------
# Colors
# ----------------------------------
NOCOLOR='\x1B[0m'
RED='\x1B[0;31m'
GREEN='\x1B[0;32m'
ORANGE='\x1B[0;33m'
BLUE='\x1B[0;34m'
PURPLE='\x1B[0;35m'
CYAN='\x1B[0;36m'
LIGHTGRAY='\x1B[0;37m'
DARKGRAY='\x1B[1;30m'
LIGHTRED='\x1B[1;31m'
LIGHTGREEN='\x1B[1;32m'
YELLOW='\x1B[1;33m'
LIGHTBLUE='\x1B[1;34m'
LIGHTPURPLE='\x1B[1;35m'
LIGHTCYAN='\x1B[1;36m'
WHITE='\x1B[1;37m'

# EXCLUSION_REGEXP is given as regular expressions
EXCLUSION_REGEXP=()
##EXCLUSION_REGEXP+=("\./verzeichnis[[:space:]]mit[[:space:]]leerzeichen")
##EXCLUSION_REGEXP+=("\./briefe/\.git")
EXCLUSION_REGEXP+=("\./\.nochecksum/\.zsh/\.zcompdump.*")
EXCLUSION_REGEXP+=("\./\.nochecksum/\.zsh/\.zsh_sessions")
EXCLUSION_REGEXP+=("\./\.nochecksum/\.zsh/\.zsh_history.*")
EXCLUSION_REGEXP+=("\./TeX/\.signatures")

# show number of files processed to help user over longer periods wihtout output
SHOW_COUNTER=true
# set to true for more output
# do not change value if set in environment
DEBUG_PRINT="${DEBUG_PRINT:=false}"
SHORT_NAME=${THIS_SCRIPT%.*}
GNUPG_LOGFILE=$(mktemp /tmp/${SHORT_NAME}_gnupg_log.XXXXXX)

debug_print()
{
  if [[ "${DEBUG_PRINT}" = true ]]; then
    echo -e "$*"
  fi
}

# array keeps a list of temporary files to cleanup
TMP_FILE_LIST=()

# Do cleanup
function Cleanup() {
  for i in "${!TMP_FILE_LIST[@]}"; do
    if [ -f "${TMP_FILE_LIST[$i]}" ]; then
      debug_print "deleting ${TMP_FILE_LIST[$i]}"
      rm -f "${TMP_FILE_LIST[$i]}"
    fi
  done
}

# Do cleanup, display error message and exit
function Interrupt() {
  Cleanup
  exitcode=99
  echo -e "\nScript '${THIS_SCRIPT}' aborted by user."
  exit $exitcode
}

# trap ctrl-c and call interrupt()
trap Interrupt INT
# trap exit and call cleanup()
trap Cleanup   EXIT


# call:
# tempfile my_temp_file
# to create a tempfile. The generated file is $my_temp_file
function tempfile()
{
  local __resultvar=$1
  local __tmp_file=$(mktemp -t ${THIS_SCRIPT}_tmp_file.XXXXXX) || {
    echo "*** Creation of ${__tmp_file} failed";
    exit 1;
  }
  TMP_FILE_LIST+=("${__tmp_file}")
  if [[ "$__resultvar" ]]; then
    eval $__resultvar="'$__tmp_file'"
  else
    echo "$__tmp_file"
  fi
}

cat /dev/null > "${GNUPG_LOGFILE}"

# construct the EXCLUSION_EXPRESSION
EXCLUSION_EXPRESSION=""
for i in "${!EXCLUSION_REGEXP[@]}"; do
  EXCLUSION_EXPRESSION="${EXCLUSION_EXPRESSION} -regex ${EXCLUSION_REGEXP[i]} -prune -o "
  echo -e "${GREEN}[ EXCLUDED FROM SEARCH ]${NOCOLOR}    ${EXCLUSION_REGEXP[i]}"
done
# .signatures is hard-coded not to be searched
EXCLUSION_EXPRESSION="${EXCLUSION_EXPRESSION} -regex \./\.signatures -prune -o "


START_WITH="."
if [[ $# -eq 1 ]]; then
  ARG=$(readlink -f "$1")
  if [[ ! -n "${ARG}" || ! -d "${ARG}" ]]; then
    echo "### not a directory or notexistent"
  else
    REL_PATH=${ARG#"${DIR}"/}
    if [[ "${ARG}" == "${REL_PATH}" || ! -d "${REL_PATH}" ]]; then
      START_WITH="."
    else
      START_WITH="./${REL_PATH}"
    fi
  fi
fi
echo "START_WITH = \"${START_WITH}\""

# needed to pass a variable as search pattern to grep
# so that the variable content is not interpreted as regexp
ere_quote() {
    sed 's/[][\.|$(){}?+*^]/\\&/g' <<< "$*"
}

echo -e "find new and changed files"
COUNTER=0
tempfile COUNTERFILE
debug_print "COUNTERFILE : $COUNTERFILE"
TPUT="/usr/bin/tput"
PAD=$(printf '%0.1s' " "{1..1000})
       OK_STATUS="       [ OK ] "
    CHECK_STATUS="    [ CHECK ] "
 NEW_FILE_STATUS=" [ NEW FILE ] "
NOT_EXIST_STATUS="[ NOT FOUND ] "
   REMOVE_STATUS="   [ REMOVE ] "
# EXCLUSION_EXPRESSION excludes the directories given in EXCLUSION_REGEXP
find -E "${START_WITH}" ${EXCLUSION_EXPRESSION} -type f -print0 | while read -d $'\0' file
do
  COUNTER=$((COUNTER+1))

  if [[ "${file}" == "${GNUPG_LOGFILE}" ]]; then
    continue
  fi
  SIGNATURE_FILE=".signatures/${file#./}.sig"
  DIRECTORY="$(dirname """${SIGNATURE_FILE}""")"

  if [[ -f "${SIGNATURE_FILE}" || -f "${SIGNATURE_FILE}" ]]; then
    if gpg --verify --quiet --batch --no-tty --log-file "${GNUPG_LOGFILE}" "${SIGNATURE_FILE}" "${file}"; then
      STATUS="${OK_STATUS}"
    else
      STATUS="${CHECK_STATUS}"
    fi
  else
    STATUS="${NEW_FILE_STATUS}"
  fi

  # determine how many columns the terminal has
  COLS=$($TPUT cols)
  # MARGIN: printout ends MARGIN columns short of right edge
  MARGIN=0
  # LEN : columns available for printout
  # by subtracting 2 pressing a key during execution does not start new line
  LEN=$((COLS - MARGIN - ${#STATUS} - 2))
  if [ "$LEN" -gt "${#file}" ]; then PADLEN=$((LEN - ${#file} + $MARGIN)); LEN=${#file}; else PADLEN=$MARGIN; fi
  file=${file:${#file}-$LEN:$LEN}

  case "${STATUS}" in
    "${OK_STATUS}")
      printf '%b%*d %b%s%*.*s\r' "${GREEN}" "$((${#STATUS}-1))" "${COUNTER}" "${NOCOLOR}" "${file}" 0 "$PADLEN" "$PAD"
      ;;
    "${CHECK_STATUS}")
      printf '%b%s%b%s%*.*s\n' "${RED}" "${STATUS}" "${NOCOLOR}" "${file}" 0 "$PADLEN" "$PAD"
      ;;
    "${NEW_FILE_STATUS}")
      printf '%b%s%b%s%*.*s\n' "${GREEN}" "${STATUS}" "${NOCOLOR}" "${file}" 0 "$PADLEN" "$PAD"
      ;;
  esac
  if [ -f "${COUNTERFILE}" ]; then
    printf "%s" "${COUNTER}" > "${COUNTERFILE}"
  fi
done
COLS=$($TPUT cols)
printf '%*.*s\r' 0 "$COLS" "$PAD"
COUNTER=$(<"${COUNTERFILE}")
printf '%b%*d %b%s%*.*s\n' "${GREEN}" "$((${#OK_STATUS}-1))" "${COUNTER}" "${NOCOLOR}" "files checked" 0 "$PADLEN" "$PAD"

if [[ "${START_WITH}" == "." ]]; then
  START_WITH=".signatures"
else
  START_WITH=".signatures/${START_WITH#./}"
fi
echo "START_WITH = \"${START_WITH}\""
COUNTER=0
echo -e "find missing files"
# now check if all files a signature exists for are in the file system
find "${START_WITH}" -type f -print0 | while read -d $'\0' file
do
  COUNTER=$((COUNTER+1))
  ORIGINAL_FILE="${file#.signatures/}"
  ORIGINAL_FILE="./${ORIGINAL_FILE%.sig}"
  DIRECTORY="$(dirname """${ORIGINAL_FILE}""")"
  if [[ -f "${ORIGINAL_FILE}" || -f "${ORIGINAL_FILE}" ]]; then
    STATUS="${OK_STATUS}"
  else
    STATUS="${NOT_EXIST_STATUS}"
  fi

  # determine how many columns the terminal has
  COLS=$($TPUT cols)
  # MARGIN: printout ends MARGIN columns short of right edge
  MARGIN=0
  # LEN : columns available for printout
  # by subtracting 2 pressing a key during execution does not start new line
  LEN=$((COLS - $MARGIN - ${#STATUS} - 2))
  if [ "$LEN" -gt "${#ORIGINAL_FILE}" ]; then PADLEN=$((LEN - ${#ORIGINAL_FILE} + $MARGIN)); LEN=${#ORIGINAL_FILE}; else PADLEN=$MARGIN; fi
  ORIGINAL_FILE=${ORIGINAL_FILE:${#ORIGINAL_FILE}-$LEN:$LEN}

  case "${STATUS}" in
    "${OK_STATUS}")
      printf '%b%*d %b%s%*.*s\r' "${GREEN}" "$((${#STATUS}-1))" "${COUNTER}" "${NOCOLOR}" "${ORIGINAL_FILE}" 0 "$PADLEN" "$PAD"
      ;;
    "${NOT_EXIST_STATUS}")
      printf '%b%s%b%s%*.*s\n' "${RED}" "${STATUS}" "${NOCOLOR}" "${ORIGINAL_FILE}" 0 "$PADLEN" "$PAD"
      ;;
  esac

done
COLS=$($TPUT cols)
printf '%*.*s\r' 0 "$COLS" "$PAD"

COUNTER=0
echo "find directories in the .signatures directory which do not exist in the source"
find "${START_WITH}" -type d -print0 | while read -d $'\0' directory
do
  COUNTER=$((COUNTER+1))
  SIG_DIR="${directory}"
  SOURCE_DIRECTORY="./${directory#.signatures/}"
  if [[ -d "$SOURCE_DIRECTORY" || -d "$SOURCE_DIRECTORY" ]]; then
    STATUS="${OK_STATUS}"
  else
    STATUS="${NOT_EXIST_STATUS}"
  fi

  # determine how many columns the terminal has
  COLS=$($TPUT cols)
  # MARGIN: printout ends MARGIN columns short of right edge
  MARGIN=0
  # LEN : columns available for printout
  # by subtracting 2 pressing a key during execution does not start new line
  LEN=$((COLS - $MARGIN - ${#STATUS} - 2))
  if [ "$LEN" -gt "${#SIG_DIR}" ]; then PADLEN=$((LEN - ${#SIG_DIR} + $MARGIN)); LEN=${#SIG_DIR}; else PADLEN=$MARGIN; fi
  SIG_DIR=${SIG_DIR:${#SIG_DIR}-$LEN:$LEN}

  case "${STATUS}" in
    "${OK_STATUS}")
      printf '%b%*d %b%s%*.*s\r' "${GREEN}" "$((${#STATUS}-1))" "${COUNTER}" "${NOCOLOR}" "${SIG_DIR}" 0 "$PADLEN" "$PAD"
      ;;
    "${NOT_EXIST_STATUS}")
      printf '%b%s%b%s%*.*s\n' "${GREEN}" "${STATUS}" "${NOCOLOR}" "${SOURCE_DIRECTORY}" 0 "$PADLEN" "$PAD"
      ;;
  esac
done
COLS=$($TPUT cols)
printf '%*.*s\r' 0 "$COLS" "$PAD"
printf '\nGnuPG Logfile = %s\n' "${GNUPG_LOGFILE}"
