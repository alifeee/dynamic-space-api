#!/bin/bash
# fill static SpaceAPI with dynamic sensor and state data

state_json=$(./get_open-status.sh | jq -c)
sensors_json=$(./get_sensors.sh | jq -c)
spaceapi_json=$(cat spaceapi.json)

echo "${spaceapi_json}" \
  | jq \
  --argjson state "${state_json}" \
  --argjson sensors "${sensors_json}" \
  '.state = $state |
  .sensors = $sensors
  '
