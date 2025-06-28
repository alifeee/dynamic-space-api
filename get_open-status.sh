#!/bin/bash

query='from(bucket: "test")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "doorstate")
  |> filter(fn: (r) => r["_field"] == "state")
  |> last()'

result=$(./request.sh "${query}")
if [[ "${?}" != 0 ]]; then
  echo "fetch script failed :("
  exit 1
fi

echo "got ${result}" >> /dev/stderr

state=$(echo "${result}" | csvtool namedcol "_value" - | head -n2 | tail -n1)
modifiedtime=$(date --date=$(echo "${result}" | csvtool namedcol "_time" - | head -n2 | tail -n1) '+%s')

if [[ "${state}" == "OCCUPIED" ]]; then
  open="true"
else
  open="false"
fi

jq -n \
  --arg open "${open}" \
  --arg lastchange "${modifiedtime}" \
  --arg iconopen "https://server.alifeee.net/static/images/sh-open.svg" \
  --arg iconclosed "https://server.alifeee.net/static/images/sh-open.svg" \
  '{
    "state": {
      "open": $open,
      "lastchange": $lastchange,
      "message": "checked by pi",
      "icon": {
        "open": $iconopen,
        "closed": $iconclosed
      }
    }
  }'
