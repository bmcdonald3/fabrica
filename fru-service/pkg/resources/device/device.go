// Copyright © 2025 OpenCHAMI a Series of LF Projects, LLC
//
// SPDX-License-Identifier: MIT

package device

import (
	"context"

	"github.com/alexlovelltroy/fabrica/pkg/resource"
)

// Device represents a Device resource
type Device struct {
	resource.Resource
	Spec   DeviceSpec   `json:"spec" validate:"required"`
	Status DeviceStatus `json:"status,omitempty"`
}

// DeviceSpec defines the desired state of Device
type DeviceSpec struct {
	ComponentType string `json:"componentType" validate:"required"`
	Manufacturer  string `json:"manufacturer,omitempty"`
	PartNumber    string `json:"partNumber,omitempty"`
	SerialNumber  string `json:"serialNumber,omitempty"`
	LocationID    string `json:"locationId,omitempty"`
	// Add your spec fields here
}

// DeviceStatus defines the observed state of Device
type DeviceStatus struct {
	NumericID         int      `json:"numericId,omitempty"`
	ChildrenDeviceIDs []string `json:"childrenDeviceIds,omitempty"`
	// Add your status fields here
}

// Validate implements custom validation logic for Device
func (r *Device) Validate(ctx context.Context) error {
	// Add custom validation logic here
	// Example:
	// if r.Spec.Name == "forbidden" {
	//     return errors.New("name 'forbidden' is not allowed")
	// }

	return nil
}

func init() {
	// Register resource type prefix for storage
	resource.RegisterResourcePrefix("Device", "dev")
}
