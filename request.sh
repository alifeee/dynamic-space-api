#!/bin/bash
# make a request to the influxdb API with a query specified as an argument to the script

query="${1}"
if [[ -z "${query}" ]]; then
  echo "specify query! ./request.sh {query}"
  exit 1
fi

source .env

resultfile="/tmp/829utfgj2w"
code=$(curl --request POST \
  "${INFLUX_URL}/api/v2/query?orgID=${ORGID}" \
  --header "Authorization: Token ${TOKEN}" \
  --header 'Accept: application/csv' \
	--header 'Cache-control: no-cache' \
  --header 'Content-type: application/vnd.flux' \
  --data "${query}" \
  -o "${resultfile}" \
  -w "%{http_code}"
)

if [[ "${code}" != 200 ]]; then
  echo "got bad HTTP code! ${code}"
  exit 1
fi

cat "${resultfile}"
