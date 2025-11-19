package codegen

import (
	"testing"
)

// 1. Define a Mock Resource with both Spec and Status
type TestResource struct {
	Spec   TestResourceSpec
	Status TestResourceStatus
}

type TestResourceSpec struct {
	DesiredState string `json:"desiredState"`
}

type TestResourceStatus struct {
	ObservedState string `json:"observedState"`
	ErrorCount    int    `json:"errorCount"`
}

func TestRegisterResource_ExtractsStatusFields(t *testing.T) {
	// 2. Initialize the Generator
	gen := NewGenerator("./out", "main", "github.com/test/app")

	// 3. Register the mock resource
	err := gen.RegisterResource(&TestResource{})
	if err != nil {
		t.Fatalf("RegisterResource failed: %v", err)
	}

	if len(gen.Resources) == 0 {
		t.Fatal("Expected 1 resource to be registered")
	}

	resource := gen.Resources[0]

	// 4. Verify Spec Fields (Existing functionality)
	if len(resource.SpecFields) != 1 {
		t.Errorf("Expected 1 Spec field, got %d", len(resource.SpecFields))
	}
	if resource.SpecFields[0].Name != "DesiredState" {
		t.Errorf("Expected Spec field 'DesiredState', got '%s'", resource.SpecFields[0].Name)
	}

	// 5. Verify Status Fields (NEW Functionality)
	// This is the critical check for the changes we just made.
	if len(resource.StatusFields) != 2 {
		t.Errorf("Expected 2 Status fields, got %d", len(resource.StatusFields))
	}

	// Helper map to check field existence
	statusMap := make(map[string]bool)
	for _, f := range resource.StatusFields {
		statusMap[f.Name] = true
	}

	if !statusMap["ObservedState"] {
		t.Error("Missing status field: ObservedState")
	}
	if !statusMap["ErrorCount"] {
		t.Error("Missing status field: ErrorCount")
	}
}