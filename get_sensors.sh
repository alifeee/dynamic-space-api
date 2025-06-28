#!/bin/bash
# get all most recent measurements from InfluxDB and export them

tempfile="/tmp/72gfywui228.tmp"
rm -f "${tempfile}"

query='from(bucket: "test")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "environment")
  |> filter(fn: (r) => r["Device"] == "Env-02" or r["device"] == "ESP8266-TRAINSIGN")
  |> filter(fn: (r) =>
  	r["_field"] == "Temperature" or r["_field"] == "Pressure" or r["_field"] == "Humidity" or
  	r["_field"] == "temperature" or r["_field"] == "humidity" or r["_field"] == "co2" or
  	r["_field"] == "rssi"
	)
  |> last()
  |> toFloat()
  |> group()'

result=$(./request.sh "${query}")
if [[ "${?}" != 0 ]]; then
  echo "fetch script failed :("
  exit 1
fi

echo "got ${result}" >> /dev/stderr

# convert CSV -> JSON
json=$(echo "${result}" | python3 -c 'import csv, json, sys; print(json.dumps([dict(r) for r in csv.DictReader(sys.stdin)]))')

# set "device" key to be "Device" key (join)
json=$(echo "${json}" | jq '.[] |= (if .device == "" then .device  = .Device else . end)')
# turn "_time" into unix timestamps
json=$(echo "${json}" | jq '.[] |= (._time = (._time | .[0:19] + "Z" | fromdate))')
# multiply pressure by 0.01 (it should be in hPa for the SpaceAPI schema)
json=$(echo "${json}" | jq '.[] |= (if (.Device == "Env-02" and ._field == "Pressure") then ._value = (._value|tonumber * 0.01) else . end)')


# output json given a device ID, measurement, and some metadata
function output_sensor {
  json="${1}"
  device="${2}"
  field="${3}"
  sensortype="${4}"
  unit="${5}"
  location="${6}"
  description="${7}"
  echo "${1}" \
    | jq \
    --arg device "${device}" \
    --arg field "${field}" \
    --arg sensortype "${sensortype}" \
    --arg unit "${unit}" \
    --arg location "${location}" \
    --arg description "${description}" \
    '.[] | select(.device == $device and ._field == $field) |
    {
      sensortype: $sensortype,
      value: ._value|tonumber,
      unit: $unit,
      location: $location,
      name: $device,
      description: $description,
      lastchange: ._time
    }' >> "${tempfile}"
}

# re-usable stuff
trainsign_id="ESP8266-TRAINSIGN"
trainsign_desc="SCD40. this sensor is inside a box (the train sign), interpret as appropriate. https://github.com/sheffieldhackspace/co2-train-sign"

bme_id="Env-02"
bme_desc="BME280"

common="common room"

# output json for each sensor
# output_sensor "${json}" \
#   id of device (from InfluxDB) \
#   id of _field measurement (from InfluxDB) \
#   type of sensor (from SpaceAPI schema) \
#   unit (from SpaceAPI schema) \
#   location (freeform text) \
#   description (freeform text)
output_sensor "${json}" \
  "${trainsign_id}" \
  temperature \
  temperature \
  "°C" \
  "${common}" \
  "${trainsign_desc}"
output_sensor "${json}" \
  "${bme_id}" \
  Temperature \
  temperature \
  "°C" \
  "${common}" \
  "${bme_desc}"
output_sensor "${json}" \
  "${trainsign_id}" \
  co2 \
  carbondioxide \
  ppm \
  "${common}" \
  "${trainsign_desc}"
output_sensor "${json}" \
  "${bme_id}" \
  Pressure \
  barometer \
  hPa \
  "${common}" \
  "${bme_desc}"
output_sensor "${json}" \
  "${trainsign_id}" \
  "humidity" \
  "humidity" \
  "%" \
  "${common}" \
  "${trainsign_desc}"
output_sensor "${json}" \
  "${bme_id}" \
  "Humidity" \
  "humidity" \
  "%" \
  "${common}" \
  "${bme_desc}"

# collect into sensor types for schema
# e.g., turn
#    {"sensortype": "temp", "value": …}
#    {"sensortype": "temp", "value": …}
#    {"sensortype": "humidity", "value": …}
# into
#   {
#     "temp": [
#       {"value": …},
#       {"value": …}
#     ],
#     "humidity": [
#       {"value": …}
#     ]
#   }
cat "${tempfile}" | jq --slurp '
  . as $sensors
  | [.[] | .sensortype] | unique as $types
  | $types | map(
    . as $type
    | {
      ($type): [
        $sensors | .[]
          | select(.sensortype == $type)
      ]
    })
    | .[]' \
  | jq --slurp '
    add
    | .[] |= (.[] |= (del(.sensortype)))'
