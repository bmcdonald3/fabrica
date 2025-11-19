# POC: Fabrica "Flat API" Sidecar

This proof of concept demonstrates a "Dual-Mode" API generation strategy for Fabrica. It enables the generator to produce two distinct API surfaces for the same underlying resource: the standard Kubernetes-style "Envelope" API and a simplified "Flat" API.

## 1. The Objective

Fabrica default behavior generates resources using a strict Kubernetes envelope pattern (separating `Spec` and `Status`), which is not always desired.

Here, I've modified the generator to create a "translation layer" that exposes a flat JSON structure alongside the standard API, without duplicating logic.

## 2. Test Output

The following output demonstrates the successful implementation. We create a resource via the Flat API, then view it through both the Standard (Nested) and Flat lenses.

### Create Resource (Via Flat API)
*Note: We attempt to inject `status: "active"` (Spec) and `health: "healthy"` (Status). The system correctly accepts the Spec field but ignores the Status field.*

```bash
curl -X POST http://localhost:8080/spec2/devices \
  -H "Content-Type: application/json" \
  -d '{
    "type": "server",
    "ipAddress": "10.0.0.50",
    "status": "active",
    "health": "healthy"
  }'
```

Returns:
```json
{
  "id": "dev-4674f808",
  "createdAt": "2025-11-19T11:39:23.336736-08:00",
  "updatedAt": "2025-11-19T11:39:23.336736-08:00",
  "type": "server",
  "ipAddress": "10.0.0.50",
  "status": "active",
  "ready": false,
  "lastChecked": "0001-01-01T00:00:00Z"
}
```

### Read Verification: Standard API vs. Flat API

**Standard API (`GET /devices`) - The Envelope View:**
```json
[
  {
    "apiVersion": "",
    "kind": "Device",
    "metadata": {
      "uid": "dev-4674f808",
      ...
    },
    "spec": {
      "type": "server",
      "ipAddress": "10.0.0.50",
      "status": "active"
    },
    "status": {
      "ready": false,
      ...
    }
  }
]
```

**Flat API (`GET /spec2/devices`) - The Simplified View:**
```json
[
  {
    "id": "dev-4674f808",
    "type": "server",
    "ipAddress": "10.0.0.50",
    "status": "active",
    "ready": false,
    ...
  }
]
```

## 3. How to Run

Follow these steps to reproduce the POC using the modified generator.

### Step 1: Build the Generator
Templates are embedded in the binary, so we must rebuild the tool to capture the new `flat_*.tmpl` files.

```bash
# From the root of the fabrica repository
go build -mod=mod -o bin/fabrica ./cmd/fabrica
```

### Step 2: Initialize a Test Project

```bash
# Initialize project
./bin/fabrica init di
cd di

# Add a resource
../bin/fabrica add resource Device
```

### Step 3: Define Resource Fields
Update `pkg/resources/device/device.go` to match the test data:

```go
type DeviceSpec struct {
    Type      string `json:"type"`
    IPAddress string `json:"ipAddress"`
    Status    string `json:"status"` // Desired state
}

type DeviceStatus struct {
    Health      string    `json:"health,omitempty"`
    Ready       bool      `json:"ready"`
    LastChecked time.Time `json:"lastChecked,omitempty"`
}
```

### Step 4: Generate Code
Run the generator. This will now produce `*_flat_handlers_generated.go` and `flat_models_generated.go`.

```bash
../bin/fabrica generate
go mod tidy
```

### Step 5: Run Server
Start the server. The new routes will be available at `/spec2`.

```bash
go run ./cmd/server
```

### Step 6: Verify
Execute the curl commands listed in the "Test Output" section above.