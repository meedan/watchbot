#!/bin/bash
# This script tests all API methods

HOST=$1
if [ -z "$HOST" ]
then
  HOST='http://localhost:3000'
fi

KEY=$(bundle exec rake watchbot:api_keys:create application=bridge-api | sed 's/.*token \([^ ]\+\) .*/\1/g' | tail -1)

function urlencode {
  local length="${#1}"
  for (( i = 0; i < length; i++ ))
  do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      *) printf '%%%02X' "'$c"
    esac
  done
}

function call {
  verb=$1
  path=$2
  params=$3
  if [ -z "$params" ]
  then
    params='{}'
  fi
  
  echo "Calling: $verb $path with params $params"
  
  curl -s -X $verb "$HOST/$path" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token token=\"$KEY\"" \
  -d "$params" | python -mjson.tool; echo
}

call POST links '{"url":"http://meedan.com"}'
url=$(urlencode http://meedan.com)
call DELETE "links/$url"
call POST links/bulk '{"url1":"http://meedan.com","url2":"http://meedan.com/bridge"}'
call DELETE links/bulk '{"url1":"http://meedan.com","url2":"http://meedan.com/bridge"}'
