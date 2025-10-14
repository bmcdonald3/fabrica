// Copyright © 2025 OpenCHAMI a Series of LF Projects, LLC
//
// SPDX-License-Identifier: MIT

package location

import (
	"context"

	"github.com/alexlovelltroy/fabrica/pkg/resource"
)

// Location represents a Location resource
type Location struct {
	resource.Resource
	Spec   LocationSpec   `json:"spec" validate:"required"`
	Status LocationStatus `json:"status,omitempty"`
}

// LocationSpec defines the desired state of Location
type LocationSpec struct {
	ParentLocationID string `json:"parentLocationId,omitempty"`
	LocationType     string `json:"locationType,omitempty"`
	// Add your spec fields here
}

// LocationStatus defines the observed state of Location
type LocationStatus struct {
	NumericID           int      `json:"numericId,omitempty"`
	ChildrenLocationIDs []string `json:"childrenLocationIds,omitempty"`
	// Add your status fields here
}

// Validate implements custom validation logic for Location
func (r *Location) Validate(ctx context.Context) error {
	// Add custom validation logic here
	// Example:
	// if r.Spec.Name == "forbidden" {
	//     return errors.New("name 'forbidden' is not allowed")
	// }

	return nil
}

func init() {
	// Register resource type prefix for storage
	resource.RegisterResourcePrefix("Location", "loc")
}
