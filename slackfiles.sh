#!/bin/bash

#------------------------------------------------------------------------------
# Description: Slack file lister/getter/deleter.
# Author:      Caleb Gross
# Date:        Tue Jan 30 2018
#
# Notes:       - Requires the 'jq' utility.
#              - Some command syntax may be BSD-flavored. Tweak as needed.
#              - TOKEN and EMAIL variables must be set. Generate a token at:
#                https://api.slack.com/custom-integrations/legacy-tokens
#------------------------------------------------------------------------------

TOKEN=""
EMAIL=""

#--------------------------------
# Usage statement.
#--------------------------------

[[ `which jq` ]] || { echo "'jq' must be installed for this script to work."; exit; }

USAGE="\nUsage:\n$0 [list|get|delete]\n"

if [[ -z "$1" ]]; then
  echo -e "$USAGE"; exit;
elif [[ "$1" = "list" ]] || [[ "$1" = "get" ]] || [[ "$1" = "delete" ]]; then
  COMMAND="$1"
else
  echo -e "\nInvalid command.\n$USAGE"; exit;
fi

#--------------------------------
# Set global variables.
#--------------------------------

SCHEME="https"
HOST_PATH="slack.com/api"
OUT_FILE="filelist.txt"

if [[ -z "$TOKEN" ]] || [[ -z "$EMAIL" ]]; then
  echo "TOKEN and EMAIL variables must be set."; exit;
fi

METHOD="users.list"
QUERY="token=$TOKEN"
URL="$SCHEME://$HOST_PATH/$METHOD?$QUERY"
USER_ID=$( curl --silent --url "$URL" | jq ".members[] | \
  select (.profile.email==\"$EMAIL\") | .id" | tr -d '"' )

#--------------------------------
# List files.
#--------------------------------

if [[ "$COMMAND" = "list" ]]; then

  METHOD="files.list"
  QUERY="token=$TOKEN&user=$USER_ID"
  URL="$SCHEME://$HOST_PATH/$METHOD?$QUERY"

  curl --silent --output "$OUT_FILE" --url "$URL"
  
  echo "File listing located in $OUT_FILE. If any errors, check your curl args."

fi

#--------------------------------
# Prepare to get or delete files.
#--------------------------------

if [[ "$COMMAND" = "get" ]] || [[ "$COMMAND" = "delete" ]]; then

  [[ -f "$OUT_FILE" ]] || { echo "Run '$0 list' first."; exit; }

  COUNT=0
  NO_FILES=$( cat "$OUT_FILE" | jq '.paging | .total' )

fi

#--------------------------------
# Get files.
#--------------------------------

if [[ "$COMMAND" = "get" ]]; then
  
  URL_LIST=$( cat "$OUT_FILE" | jq '.files | .[] | .url_private' | tr -d '"' ) 
  HEADER="Authorization: Bearer $TOKEN"

  mkdir files
  cd files

  for URL in $URL_LIST; do
    (( COUNT++ ))
    REMOTE_NAME="${URL##*/}"
    FILE_NAME="${REMOTE_NAME%.*}"
    EXTENSION="${REMOTE_NAME##*.}"
    LOCAL_NAME="${FILE_NAME}_$RANDOM.$EXTENSION"
    echo -n "Downloading file $COUNT/$NO_FILES $LOCAL_NAME..."
    curl --silent --output "$LOCAL_NAME" --header "$HEADER" --url "$URL" \
      && echo "done." || echo "failed."
  done

fi

#--------------------------------
# Delete files.
#--------------------------------

if [[ "$COMMAND" = "delete" ]]; then

  read -p "Have you already downloaded your files with '$0 get'? " DOWNLOADED
  [[ `echo "$DOWNLOADED" | egrep -i "y"` ]] || exit
  
  METHOD="files.delete"
  ID_LIST=$( cat "$OUT_FILE" | jq '.files | .[] | .id' | tr -d '"' )

  for ID in $ID_LIST; do
    (( COUNT++ ))
    echo -n "Deleting file $COUNT/$NO_FILES $ID..."
    QUERY="token=$TOKEN&file=$ID"
    URL="$SCHEME://$HOST_PATH/$METHOD?$QUERY"
    curl --silent --url "$URL"
    echo
  done

fi


