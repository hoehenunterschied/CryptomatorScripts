#!/bin/bash
# Ralf Lange 2020

# switch to the direcory this script resides in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if ! cd "${DIR}"; then
    echo -e "####\n#### Could not make \"${DIR}\" the current directory.\n#### Exiting.\n####"
    exit
fi

TARGET_NAME=();                 TARGET_LIST=();                                                       CRYPTOMATOR_LIST=();
TARGET_NAME+=("Master");        TARGET_LIST+=("/Users/lange/Cryptomator/Master")                      CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("iCloudDrive");   TARGET_LIST+=("/Users/lange/Cryptomator/iCloudDriveMasterCopy")       CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("GoogleDrive");   TARGET_LIST+=("/Users/lange/Cryptomator/GoogleDriveMasterCopy");      CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("OraDocs");       TARGET_LIST+=("/Users/lange/Cryptomator/OraDocsMasterCopy");          CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("Corsair");       TARGET_LIST+=("/Users/lange/Cryptomator/CorsairMasterCopy");          CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("TimeMachine");   TARGET_LIST+=("/Volumes/Media/Cryptomator/MasterCopy");               CRYPTOMATOR_LIST+=(false);
TARGET_NAME+=("JohnPeel");      TARGET_LIST+=("/Users/lange/Cryptomator/JohnPeelSessions");           CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("JohnPeelCopy");  TARGET_LIST+=("/Volumes/Media/JohnPeelSessions");                     CRYPTOMATOR_LIST+=(false);
TARGET_NAME+=("SanDisk");       TARGET_LIST+=("/Users/lange/Cryptomator/SanDiskMasterCopy");          CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("Stick");         TARGET_LIST+=("/Users/lange/Cryptomator/StickMasterCopy");            CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("ThumbDrive");    TARGET_LIST+=("/Users/lange/Cryptomator/ThumbDriveMasterCopy");       CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("Stick16");       TARGET_LIST+=("/Users/lange/Cryptomator/Stick16MasterCopy");          CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("Spaceloop");     TARGET_LIST+=("/Users/lange/Cryptomator/SpaceloopMasterCopy");        CRYPTOMATOR_LIST+=(true);
TARGET_NAME+=("Crucial");       TARGET_LIST+=("/Volumes/JohnPeel/JohnPeelSessions");                  CRYPTOMATOR_LIST+=(false);

SIGNATUR_DIR=".signatures"
# create STOPFILE with zero size to stop this script
STOPFILE="${HOME}/tmp/stopfile"

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

usage()
{
  echo -e "\nUsage: $(basename $0) integrity|stopfile\n"
}

togglestopfile()
{
    if [ -f "${STOPFILE}" ] && [ ! -s "${STOPFILE}" ]; then
      # exists and is empty
      rm "${STOPFILE}";
      echo -e "${YELLOW}####${NOCOLOR} stopfile ${STOPFILE} ${YELLOW}removed${NOCOLOR}"
    else
      touch "${STOPFILE}";
      echo -e "${YELLOW}####${NOCOLOR} stopfile ${STOPFILE} ${GREEN}created${NOCOLOR}"
    fi
}

run_check()
{
  RUN=true;
  while ${RUN}; do
    # should we run ?
    if [ -f "${STOPFILE}" ] && [ ! -s "${STOPFILE}" ]; then
      RUN=false;
      rm "${STOPFILE}";
      echo -e "${YELLOW}####${NOCOLOR} stopfile ${STOPFILE} ${YELLOW}removed${NOCOLOR}"
      continue;
    fi;
    NAMES=(); DIRS=()
    for i in "${!TARGET_LIST[@]}"; do
      # does the directory exist?
      if [ ! -d "${TARGET_LIST[$i]}" ]; then
        continue;
      fi
      # if directory is Crypotmator vault, check if it is opened
      if ${CRYPTOMATOR_LIST[$i]}; then
        #if ! mount | grep "^Cryptomator@macfuse[0-9]\+ on ${TARGET_LIST[$i]} " > /dev/null 2>&1; then
        if ! mount | grep "^Cryptomator@macfuse[0-9]\+ on ${TARGET_LIST[$i]} \|^localhost:[[:print:]]\+ on ${TARGET_LIST[$i]} " > /dev/null 2>&1; then
          continue
        fi
      fi
      #printf "%-33s %s\n" "TARGET_NAME+=(\"${TARGET_NAME[$i]}\");" "TARGET_LIST+=(\"${TARGET_LIST[$i]}\");"
      if [[ -x "${TARGET_LIST[$i]}/${SCRIPT}" ]] && [[ -d "${TARGET_LIST[$i]}/${SIGNATUR_DIR}" ]]; then
        NAMES+=("${TARGET_NAME[$i]}"); DIRS+=("${TARGET_LIST[$i]}");
      fi
    done

    if [ ${#NAMES[@]} -ne 0 ]; then
      echo -e "${YELLOW}#############################################################"
      echo -e "${YELLOW}####${NOCOLOR} available targets: ${NAMES[*]}"
        for i in "${!DIRS[@]}"; do
          if [ -f "${STOPFILE}" ] && [ ! -s "${STOPFILE}" ]; then
            rm "${STOPFILE}";
            echo -e "${YELLOW}####${NOCOLOR} stopfile ${STOPFILE} ${YELLOW}removed${NOCOLOR}"
            RUN=false;
            break;
          fi;
          echo -e "${YELLOW}#############################################################"
          # skip directory if script is not executable or checksum file not readable
          if [[ -x "${DIRS[$i]}/${SCRIPT}" ]] && [[ -d "${DIRS[$i]}/${SIGNATUR_DIR}" ]]; then
            echo -ne "####${NOCOLOR} $(date +'%Y%m%d %H:%M:%S') "
            echo -e "${YELLOW}${NAMES[$i]}${NOCOLOR}->${DIRS[$i]}";
          else
            echo -ne "####${NOCOLOR} $(date +'%Y%m%d %H:%M:%S') ${RED}skipping${NOCOLOR} "
            echo -e "${NAMES[$i]}->${YELLOW}${DIRS[$i]}${NOCOLOR}";
            continue
          fi
          "${DIRS[$i]}/${SCRIPT}";
        done;
      echo -e "${YELLOW}####${NOCOLOR} $(date +'%Y%m%d %H:%M:%S')\n"
    else
      # no targets left. Exit
      echo -e "${YELLOW}#############################################################"
      echo -e "####${NOCOLOR} $(date +'%Y%m%d %H:%M:%S') ${YELLOW}${dir}${NOCOLOR}";
      exit
    fi
  done;
}

case "$1" in
  integrity)
    SCRIPT="integritycheck.bash"
    run_check
    ;;
  stopfile)
    togglestopfile
    ;;
  *)
    usage;
esac
