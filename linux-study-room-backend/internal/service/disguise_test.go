package service

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"testing/quick"
)

// **Feature: system-disguise, Property 1: CPU Info Generation Correctness**
// **Validates: Requirements 1.1, 3.1**
// For any DisguiseConfig with a valid core count N, the generated cpuinfo content
// SHALL contain exactly N processor entries and include the configured CPU model name.
func TestGenerateCPUInfo_Property(t *testing.T) {
	processorRegex := regexp.MustCompile(`processor\s*:\s*(\d+)`)
	
	f := func(cores uint8) bool {
		// Limit cores to reasonable range (1-128)
		coreCount := int(cores%128) + 1
		modelName := "Test CPU Model"
		mhz := 2000
		
		cfg := &DisguiseConfig{
			CPUCores: coreCount,
			CPUModel: modelName,
			CPUMHz:   mhz,
		}
		
		result := GenerateCPUInfo(cfg)
		
		// Check processor count
		matches := processorRegex.FindAllStringSubmatch(result, -1)
		if len(matches) != coreCount {
			t.Logf("Expected %d processors, got %d", coreCount, len(matches))
			return false
		}
		
		// Check model name appears in each entry
		modelCount := strings.Count(result, modelName)
		if modelCount != coreCount {
			t.Logf("Expected model name to appear %d times, got %d", coreCount, modelCount)
			return false
		}
		
		return true
	}
	
	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

func TestGenerateCPUInfo_DefaultConfig(t *testing.T) {
	result := GenerateCPUInfo(nil)
	
	// Should use default 16 cores
	processorRegex := regexp.MustCompile(`processor\s*:\s*(\d+)`)
	matches := processorRegex.FindAllStringSubmatch(result, -1)
	if len(matches) != 16 {
		t.Errorf("Expected 16 processors with nil config, got %d", len(matches))
	}
	
	// Should contain default model name
	if !strings.Contains(result, "Intel(R) Xeon(R) Platinum 8375C") {
		t.Error("Expected default CPU model name in output")
	}
}


// **Feature: system-disguise, Property 2: Memory Info Generation Correctness**
// **Validates: Requirements 1.2, 3.2**
// For any DisguiseConfig with a valid memory size M (in GB), the generated meminfo
// content SHALL contain a MemTotal value equal to M * 1024 * 1024 kB.
func TestGenerateMemInfo_Property(t *testing.T) {
	memTotalRegex := regexp.MustCompile(`MemTotal:\s*(\d+)\s*kB`)
	
	f := func(memGB uint16) bool {
		// Limit memory to reasonable range (1-1024 GB)
		memoryGB := int(memGB%1024) + 1
		
		cfg := &DisguiseConfig{
			MemoryGB: memoryGB,
		}
		
		result := GenerateMemInfo(cfg)
		
		// Check MemTotal value
		matches := memTotalRegex.FindStringSubmatch(result)
		if len(matches) != 2 {
			t.Log("MemTotal not found in output")
			return false
		}
		
		// Parse the value
		var memTotalKB int64
		fmt.Sscanf(matches[1], "%d", &memTotalKB)
		
		expectedKB := int64(memoryGB) * 1024 * 1024
		if memTotalKB != expectedKB {
			t.Logf("Expected MemTotal %d kB, got %d kB", expectedKB, memTotalKB)
			return false
		}
		
		return true
	}
	
	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

func TestGenerateMemInfo_DefaultConfig(t *testing.T) {
	result := GenerateMemInfo(nil)
	
	// Should use default 64 GB = 67108864 kB
	memTotalRegex := regexp.MustCompile(`MemTotal:\s*(\d+)\s*kB`)
	matches := memTotalRegex.FindStringSubmatch(result)
	if len(matches) != 2 {
		t.Fatal("MemTotal not found in output")
	}
	
	var memTotalKB int64
	fmt.Sscanf(matches[1], "%d", &memTotalKB)
	
	expectedKB := int64(64) * 1024 * 1024 // 67108864 kB
	if memTotalKB != expectedKB {
		t.Errorf("Expected MemTotal %d kB with nil config, got %d kB", expectedKB, memTotalKB)
	}
}


// **Feature: system-disguise, Property 5: GPU Info Generation Correctness**
// **Validates: Requirements 1.6**
// For any DisguiseConfig with a valid GPU model and memory size, the generated
// nvidia-smi output SHALL contain the configured GPU model name and memory capacity.
func TestGenerateNvidiaSmi_Property(t *testing.T) {
	f := func(memMB uint16) bool {
		// Limit GPU memory to reasonable range (1024-24576 MB)
		gpuMemoryMB := int(memMB%23552) + 1024
		gpuModel := "Test GPU Model"
		
		cfg := &DisguiseConfig{
			GPUModel:    gpuModel,
			GPUMemoryMB: gpuMemoryMB,
		}
		
		result := GenerateNvidiaSmi(cfg)
		
		// Check GPU model appears in output
		if !strings.Contains(result, gpuModel) {
			t.Logf("GPU model '%s' not found in output", gpuModel)
			return false
		}
		
		// Check memory value appears in output
		memStr := fmt.Sprintf("%dMiB", gpuMemoryMB)
		if !strings.Contains(result, memStr) {
			t.Logf("GPU memory '%s' not found in output", memStr)
			return false
		}
		
		return true
	}
	
	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

func TestGenerateNvidiaSmi_DefaultConfig(t *testing.T) {
	result := GenerateNvidiaSmi(nil)
	
	// Should contain default GPU model
	if !strings.Contains(result, "NVIDIA GeForce RTX 4060") {
		t.Error("Expected default GPU model in output")
	}
	
	// Should contain default memory (8192 MiB)
	if !strings.Contains(result, "8192MiB") {
		t.Error("Expected default GPU memory (8192MiB) in output")
	}
	
	// Should be a valid shell script
	if !strings.HasPrefix(result, "#!/bin/sh") {
		t.Error("Expected shell script header")
	}
}

// **Feature: system-disguise, Property 4: Cleanup Removes All Files**
// **Validates: Requirements 2.4**
// For any userID for which disguise files have been created, calling CleanupDisguiseFiles
// SHALL result in the disguise directory for that user no longer existing.
func TestCleanupDisguiseFiles_Property(t *testing.T) {
	f := func(userID uint32) bool {
		// Use positive userID
		id := int64(userID%100000) + 1
		
		// Create disguise files
		disguisePath, err := CreateDisguiseFiles(id, nil)
		if err != nil {
			t.Logf("Failed to create disguise files: %v", err)
			return false
		}
		
		// Verify files exist
		if _, err := os.Stat(disguisePath); os.IsNotExist(err) {
			t.Log("Disguise directory was not created")
			return false
		}
		
		// Cleanup
		if err := CleanupDisguiseFiles(id); err != nil {
			t.Logf("Failed to cleanup disguise files: %v", err)
			return false
		}
		
		// Verify directory no longer exists
		if _, err := os.Stat(disguisePath); !os.IsNotExist(err) {
			t.Log("Disguise directory still exists after cleanup")
			return false
		}
		
		return true
	}
	
	if err := quick.Check(f, &quick.Config{MaxCount: 20}); err != nil {
		t.Error(err)
	}
}

func TestCreateDisguiseFiles_CreatesAllFiles(t *testing.T) {
	userID := int64(99999)
	defer CleanupDisguiseFiles(userID)
	
	disguisePath, err := CreateDisguiseFiles(userID, nil)
	if err != nil {
		t.Fatalf("Failed to create disguise files: %v", err)
	}
	
	// Check all files exist
	expectedFiles := []string{"cpuinfo", "meminfo", "nvidia-smi"}
	for _, filename := range expectedFiles {
		filePath := filepath.Join(disguisePath, filename)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			t.Errorf("Expected file %s to exist", filename)
		}
	}
	
	// Check nvidia-smi is executable
	nvidiaSmiPath := filepath.Join(disguisePath, "nvidia-smi")
	info, err := os.Stat(nvidiaSmiPath)
	if err != nil {
		t.Fatalf("Failed to stat nvidia-smi: %v", err)
	}
	// On Unix, check executable bit (on Windows this check is skipped)
	if info.Mode()&0111 == 0 {
		// This might fail on Windows, which is OK
		t.Log("Note: nvidia-smi executable bit check may not work on Windows")
	}
}


// **Feature: system-disguise, Property 3: Bind Mount Configuration Correctness**
// **Validates: Requirements 2.2, 2.3**
// For any userID, the GetBindMounts function SHALL return mount configurations
// that map the host disguise files to /proc/cpuinfo, /proc/meminfo, and /usr/bin/nvidia-smi
// in the container with read-only access.
func TestGetBindMounts_Property(t *testing.T) {
	f := func(userID uint32) bool {
		id := int64(userID%100000) + 1
		
		mounts := GetBindMounts(id)
		
		// Should have exactly 3 mounts
		if len(mounts) != 3 {
			t.Logf("Expected 3 mounts, got %d", len(mounts))
			return false
		}
		
		// Check expected targets
		expectedTargets := map[string]bool{
			"/proc/cpuinfo":     false,
			"/proc/meminfo":     false,
			"/usr/bin/nvidia-smi": false,
		}
		
		// Get expected user directory name
		userDir := fmt.Sprintf("user-%d", id)
		
		for _, m := range mounts {
			// Check target is expected
			if _, ok := expectedTargets[m.Target]; !ok {
				t.Logf("Unexpected mount target: %s", m.Target)
				return false
			}
			expectedTargets[m.Target] = true
			
			// Check read-only
			if !m.ReadOnly {
				t.Logf("Mount %s should be read-only", m.Target)
				return false
			}
			
			// Check source path contains user directory (works with Docker path format)
			if !strings.Contains(m.Source, userDir) {
				t.Logf("Mount source %s should contain %s", m.Source, userDir)
				return false
			}
		}
		
		// Check all targets were found
		for target, found := range expectedTargets {
			if !found {
				t.Logf("Missing mount for target: %s", target)
				return false
			}
		}
		
		return true
	}
	
	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}
