// Copyright © 2025 OpenCHAMI a Series of LF Projects, LLC
//
// SPDX-License-Identifier: MIT

package connection

import (
	"context"

	"github.com/alexlovelltroy/fabrica/pkg/resource"
)

type Endpoint struct {
	DeviceID string `json:"deviceId" validate:"required,uuid"`
	PortName string `json:"portName" validate:"required"`
}

// Connection represents a Connection resource
type Connection struct {
	resource.Resource
	Spec   ConnectionSpec   `json:"spec" validate:"required"`
	Status ConnectionStatus `json:"status,omitempty"`
}

// ConnectionSpec defines the desired state of Connection
type ConnectionSpec struct {
	ConnectionType string   `json:"connectionType" validate:"required"`
	MediumID       string   `json:"mediumId,omitempty" validate:"omitempty,uuid"`
	EndpointA      Endpoint `json:"endpointA" validate:"required"`
	EndpointB      Endpoint `json:"endpointB" validate:"required"`
	// Add your spec fields here
}

// ConnectionStatus defines the observed state of Connection
type ConnectionStatus struct {
	NumericID int `json:"numericId,omitempty"`
	// Add your status fields here
}

// Validate implements custom validation logic for Connection
func (r *Connection) Validate(ctx context.Context) error {
	// Add custom validation logic here
	// Example:
	// if r.Spec.Name == "forbidden" {
	//     return errors.New("name 'forbidden' is not allowed")
	// }

	return nil
}

func init() {
	// Register resource type prefix for storage
	resource.RegisterResourcePrefix("Connection", "con")
}
