#!/bin/bash
set -euo pipefail

API_BASE_URL="http://localhost:8080/api"
DATA_FILE="node_data.json"

if ! command -v jq &> /dev/null; then echo "Error: jq is not installed."; exit 1; fi
if [ ! -f "$DATA_FILE" ]; then echo "Error: Data file not found at '$DATA_FILE'"; exit 1; fi
echo "--- Populating Inventory API from $DATA_FILE ---"

# --- 1. Create Root Node Resources ---
echo "[1/3] Creating root Node resources..."
NODE_NAME=$(jq -r '.name' "$DATA_FILE")
NODE_MANUFACTURER=$(jq -r '.inventory["sys.Manufacturer"]' "$DATA_FILE")
NODE_SERIAL=$(jq -r '.inventory["sys.Serial Number"]' "$DATA_FILE")

# Create the Node's Location and capture its server-generated UID
NODE_LOC_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-location" '{ name: $name, locationType: "Chassis" }')
NODE_LOC_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/locations" -H "Content-Type: application/json" -d "$NODE_LOC_PAYLOAD")
NODE_LOC_UID=$(echo "$NODE_LOC_RESPONSE" | jq -r '.metadata.uid')

# Create the Node's Device and capture its server-generated UID
NODE_DEV_PAYLOAD=$(jq -n \
  --arg name "$NODE_NAME" \
  --arg manufacturer "$NODE_MANUFACTURER" \
  --arg serial "$NODE_SERIAL" \
  --arg locationId "$NODE_LOC_UID" \
  '{ name: $name, componentType: "Node", manufacturer: $manufacturer, serialNumber: $serial, locationId: $locationId }')
NODE_DEV_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/devices" -H "Content-Type: application/json" -d "$NODE_DEV_PAYLOAD")
NODE_DEV_UID=$(echo "$NODE_DEV_RESPONSE" | jq -r '.metadata.uid')

echo "    -> Created Location (UID: $NODE_LOC_UID), Device (UID: $NODE_DEV_UID)"

# --- 2. Create Component Resources ---
echo "[2/3] Creating component resources (CPUs, DIMMs)..."
CHILD_DEVICE_UIDS=()
CHILD_LOCATION_UIDS=()
for i in 1 2; do
  CPU_SERIAL=$(jq -r --arg key "cpu.Proc ${i}.Serial Number" '.inventory[$key]' "$DATA_FILE"); if [[ "$CPU_SERIAL" != "null" ]]; then
    CPU_MANUFACTURER=$(jq -r --arg key "cpu.Proc ${i}.Manufacturer" '.inventory[$key]' "$DATA_FILE")
    CPU_LOC_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-proc-${i}-socket" --arg parentId "$NODE_LOC_UID" '{ name: $name, locationType: "Socket", parentLocationId: $parentId }')
    CPU_LOC_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/locations" -H "Content-Type: application/json" -d "$CPU_LOC_PAYLOAD"); CPU_LOC_UID=$(echo "$CPU_LOC_RESPONSE" | jq -r '.metadata.uid')
    CPU_DEV_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-cpu-${CPU_SERIAL}" --arg manufacturer "$CPU_MANUFACTURER" --arg serial "$CPU_SERIAL" --arg locationId "$CPU_LOC_UID" '{ name: $name, componentType: "CPU", manufacturer: $manufacturer, serialNumber: $serial, locationId: $locationId }')
    CPU_DEV_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/devices" -H "Content-Type: application/json" -d "$CPU_DEV_PAYLOAD"); CPU_DEV_UID=$(echo "$CPU_DEV_RESPONSE" | jq -r '.metadata.uid')
    CHILD_DEVICE_UIDS+=("$CPU_DEV_UID"); CHILD_LOCATION_UIDS+=("$CPU_LOC_UID"); echo "    -> Created CPU Device with UID: $CPU_DEV_UID"; fi
done
DIMM_SERIALS=$(jq -r '.inventory | keys[] | select(startswith("dimm.")) | split(".")[1]' "$DATA_FILE" | sort -u); for serial in $DIMM_SERIALS; do
    DIMM_MANUFACTURER=$(jq -r --arg key "dimm.${serial}.Manufacturer" '.inventory[$key]' "$DATA_FILE"); DIMM_PART_NUMBER=$(jq -r --arg key "dimm.${serial}.Part Number" '.inventory[$key]' "$DATA_FILE"); DIMM_LOCATOR=$(jq -r --arg key "dimm.${serial}.Locator" '.inventory[$key]' "$DATA_FILE" | tr ' ' '-')
    DIMM_LOC_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-${DIMM_LOCATOR}-slot" --arg parentId "$NODE_LOC_UID" '{ name: $name, locationType: "Slot", parentLocationId: $parentId }')
    DIMM_LOC_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/locations" -H "Content-Type: application/json" -d "$DIMM_LOC_PAYLOAD"); DIMM_LOC_UID=$(echo "$DIMM_LOC_RESPONSE" | jq -r '.metadata.uid')
    DIMM_DEV_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-dimm-${serial}" --arg manufacturer "$DIMM_MANUFACTURER" --arg serial "$serial" --arg partNumber "$DIMM_PART_NUMBER" --arg locationId "$DIMM_LOC_UID" '{ name: $name, componentType: "DIMM", manufacturer: $manufacturer, serialNumber: $serial, partNumber: $partNumber, locationId: $locationId }')
    DIMM_DEV_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/devices" -H "Content-Type: application/json" -d "$DIMM_DEV_PAYLOAD"); DIMM_DEV_UID=$(echo "$DIMM_DEV_RESPONSE" | jq -r '.metadata.uid')
    CHILD_DEVICE_UIDS+=("$DIMM_DEV_UID"); CHILD_LOCATION_UIDS+=("$DIMM_LOC_UID"); echo "    -> Created DIMM Device with UID: $DIMM_DEV_UID"
done
echo "[3/3] Linking children to parent node..."
CHILD_DEV_UIDS_JSON=$(printf '%s\n' "${CHILD_DEVICE_UIDS[@]}" | jq -R . | jq -s .)
CHILD_LOC_UIDS_JSON=$(printf '%s\n' "${CHILD_LOCATION_UIDS[@]}" | jq -R . | jq -s .)

# The PUT request still sends the full, nested object to replace the resource
NODE_DEV_UPDATE_PAYLOAD=$(jq -n --arg name "$NODE_NAME" --arg uid "$NODE_DEV_UID" --arg manufacturer "$NODE_MANUFACTURER" --arg serial "$NODE_SERIAL" --arg locationId "$NODE_LOC_UID" --argjson childIds "$CHILD_DEV_UIDS_JSON" '{ apiVersion: "v1", kind: "Device", metadata: { name: $name, uid: $uid }, spec: { componentType: "Node", manufacturer: $manufacturer, serialNumber: $serial, locationId: $locationId, childrenDeviceIds: $childIds } }')
curl -s -X PUT "${API_BASE_URL}/devices/${NODE_DEV_UID}" -H "Content-Type: application/json" -d "$NODE_DEV_UPDATE_PAYLOAD" > /dev/null
NODE_LOC_UPDATE_PAYLOAD=$(jq -n --arg name "${NODE_NAME}-location" --arg uid "$NODE_LOC_UID" --argjson childIds "$CHILD_LOC_UIDS_JSON" '{ apiVersion: "v1", kind: "Location", metadata: { name: $name, uid: $uid }, spec: { locationType: "Chassis", childrenLocationIds: $childIds } }')
curl -s -X PUT "${API_BASE_URL}/locations/${NODE_LOC_UID}" -H "Content-Type: application/json" -d "$NODE_LOC_UPDATE_PAYLOAD" > /dev/null
echo "--- Population complete! ---"