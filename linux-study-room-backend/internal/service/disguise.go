package service

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/docker/docker/api/types/mount"
)

// DisguiseConfig holds the fake hardware specifications
type DisguiseConfig struct {
	CPUCores    int    // Number of CPU cores (default: 16)
	CPUModel    string // CPU model name (default: "Intel Xeon Platinum 8375C")
	CPUMHz      int    // CPU clock speed in MHz (default: 3500)
	MemoryGB    int    // Total memory in GB (default: 64)
	DiskGB      int    // Total disk in GB (default: 2000)
	GPUModel    string // GPU model name (default: "NVIDIA GeForce RTX 4060")
	GPUMemoryMB int    // GPU memory in MB (default: 8192)
}

// DefaultDisguiseConfig returns the default "luxury" configuration
func DefaultDisguiseConfig() *DisguiseConfig {
	return &DisguiseConfig{
		CPUCores:    16,
		CPUModel:    "Intel(R) Xeon(R) Platinum 8375C CPU @ 3.50GHz",
		CPUMHz:      3500,
		MemoryGB:    64,
		DiskGB:      2000,
		GPUModel:    "NVIDIA GeForce RTX 4060",
		GPUMemoryMB: 8192,
	}
}

// GetDisguiseBasePath returns the base directory for disguise files
// Uses OS temp directory for cross-platform compatibility
func GetDisguiseBasePath() string {
	return filepath.Join(os.TempDir(), "lsr-disguise")
}

// GetDisguisePath returns the disguise directory path for a user
func GetDisguisePath(userID int64) string {
	return filepath.Join(GetDisguiseBasePath(), fmt.Sprintf("user-%d", userID))
}


// GenerateCPUInfo generates fake /proc/cpuinfo content
func GenerateCPUInfo(cfg *DisguiseConfig) string {
	if cfg == nil {
		cfg = DefaultDisguiseConfig()
	}
	// Ensure valid values
	if cfg.CPUCores <= 0 {
		cfg.CPUCores = 16
	}
	if cfg.CPUModel == "" {
		cfg.CPUModel = "Intel(R) Xeon(R) Platinum 8375C CPU @ 3.50GHz"
	}
	if cfg.CPUMHz <= 0 {
		cfg.CPUMHz = 3500
	}

	var sb strings.Builder
	for i := 0; i < cfg.CPUCores; i++ {
		sb.WriteString(fmt.Sprintf(`processor	: %d
vendor_id	: GenuineIntel
cpu family	: 6
model		: 106
model name	: %s
stepping	: 6
microcode	: 0xd0003a5
cpu MHz		: %d.000
cache size	: 55296 KB
physical id	: 0
siblings	: %d
core id		: %d
cpu cores	: %d
apicid		: %d
initial apicid	: %d
fpu		: yes
fpu_exception	: yes
cpuid level	: 27
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon rep_good nopl xtopology tsc_reliable nonstop_tsc cpuid pni pclmulqdq vmx ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch invpcid_single ssbd ibrs ibpb stibp ibrs_enhanced fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves avx512vbmi umip avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq rdpid md_clear flush_l1d arch_capabilities
bugs		: spectre_v1 spectre_v2 spec_store_bypass swapgs
bogomips	: %d.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

`, i, cfg.CPUModel, cfg.CPUMHz, cfg.CPUCores, i, cfg.CPUCores, i, i, cfg.CPUMHz*2))
	}
	return sb.String()
}


// GenerateMemInfo generates fake /proc/meminfo content
func GenerateMemInfo(cfg *DisguiseConfig) string {
	if cfg == nil {
		cfg = DefaultDisguiseConfig()
	}
	// Ensure valid values
	if cfg.MemoryGB <= 0 {
		cfg.MemoryGB = 64
	}

	// Convert GB to kB (1 GB = 1024 * 1024 kB)
	memTotalKB := int64(cfg.MemoryGB) * 1024 * 1024
	memFreeKB := memTotalKB * 90 / 100      // 90% free
	memAvailableKB := memTotalKB * 92 / 100 // 92% available
	buffersKB := memTotalKB * 2 / 100       // 2% buffers
	cachedKB := memTotalKB * 5 / 100        // 5% cached
	swapTotalKB := memTotalKB / 2           // swap = half of RAM
	swapFreeKB := swapTotalKB               // all swap free

	return fmt.Sprintf(`MemTotal:       %d kB
MemFree:        %d kB
MemAvailable:   %d kB
Buffers:        %d kB
Cached:         %d kB
SwapCached:     0 kB
Active:         %d kB
Inactive:       %d kB
Active(anon):   %d kB
Inactive(anon): 0 kB
Active(file):   %d kB
Inactive(file): %d kB
Unevictable:    0 kB
Mlocked:        0 kB
SwapTotal:      %d kB
SwapFree:       %d kB
Dirty:          0 kB
Writeback:      0 kB
AnonPages:      %d kB
Mapped:         %d kB
Shmem:          %d kB
KReclaimable:   %d kB
Slab:           %d kB
SReclaimable:   %d kB
SUnreclaim:     %d kB
KernelStack:    %d kB
PageTables:     %d kB
NFS_Unstable:   0 kB
Bounce:         0 kB
WritebackTmp:   0 kB
CommitLimit:    %d kB
Committed_AS:   %d kB
VmallocTotal:   34359738367 kB
VmallocUsed:    %d kB
VmallocChunk:   0 kB
Percpu:         %d kB
HardwareCorrupted: 0 kB
AnonHugePages:  0 kB
ShmemHugePages: 0 kB
ShmemPmdMapped: 0 kB
FileHugePages:  0 kB
FilePmdMapped:  0 kB
HugePages_Total: 0
HugePages_Free: 0
HugePages_Rsvd: 0
HugePages_Surp: 0
Hugepagesize:   2048 kB
Hugetlb:        0 kB
DirectMap4k:    %d kB
DirectMap2M:    %d kB
DirectMap1G:    %d kB
`,
		memTotalKB,
		memFreeKB,
		memAvailableKB,
		buffersKB,
		cachedKB,
		memTotalKB*3/100,  // Active
		memTotalKB*2/100,  // Inactive
		memTotalKB*1/100,  // Active(anon)
		memTotalKB*2/100,  // Active(file)
		memTotalKB*1/100,  // Inactive(file)
		swapTotalKB,
		swapFreeKB,
		memTotalKB*1/100,  // AnonPages
		memTotalKB*1/100,  // Mapped
		memTotalKB*1/1000, // Shmem
		memTotalKB*1/100,  // KReclaimable
		memTotalKB*2/100,  // Slab
		memTotalKB*1/100,  // SReclaimable
		memTotalKB*1/100,  // SUnreclaim
		16384,             // KernelStack
		memTotalKB*1/1000, // PageTables
		memTotalKB+swapTotalKB, // CommitLimit
		memTotalKB*5/100,       // Committed_AS
		memTotalKB*1/1000,      // VmallocUsed
		8192,                   // Percpu
		memTotalKB*1/100,       // DirectMap4k
		memTotalKB*30/100,      // DirectMap2M
		memTotalKB*60/100,      // DirectMap1G
	)
}


// GenerateNvidiaSmi generates a fake nvidia-smi shell script
func GenerateNvidiaSmi(cfg *DisguiseConfig) string {
	if cfg == nil {
		cfg = DefaultDisguiseConfig()
	}
	// Ensure valid values
	if cfg.GPUModel == "" {
		cfg.GPUModel = "NVIDIA GeForce RTX 4060"
	}
	if cfg.GPUMemoryMB <= 0 {
		cfg.GPUMemoryMB = 8192
	}

	// Create a shell script that outputs fake nvidia-smi info
	return fmt.Sprintf(`#!/bin/sh
cat << 'EOF'
Mon Dec  8 12:00:00 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.54.15              Driver Version: 550.54.15      CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  %s       Off  | 00000000:01:00.0  Off |                  N/A |
|  0%%   35C    P8               5W / 115W |       0MiB /  %dMiB |      0%%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
EOF
`, cfg.GPUModel, cfg.GPUMemoryMB)
}


// CreateDisguiseFiles creates fake proc files on host for a container
// Returns the path to the disguise directory
func CreateDisguiseFiles(userID int64, cfg *DisguiseConfig) (string, error) {
	if cfg == nil {
		cfg = DefaultDisguiseConfig()
	}

	disguisePath := GetDisguisePath(userID)

	// Create directory
	if err := os.MkdirAll(disguisePath, 0755); err != nil {
		return "", fmt.Errorf("failed to create disguise directory: %w", err)
	}

	// Write cpuinfo
	cpuinfoPath := filepath.Join(disguisePath, "cpuinfo")
	if err := os.WriteFile(cpuinfoPath, []byte(GenerateCPUInfo(cfg)), 0644); err != nil {
		return "", fmt.Errorf("failed to write cpuinfo: %w", err)
	}

	// Write meminfo
	meminfoPath := filepath.Join(disguisePath, "meminfo")
	if err := os.WriteFile(meminfoPath, []byte(GenerateMemInfo(cfg)), 0644); err != nil {
		return "", fmt.Errorf("failed to write meminfo: %w", err)
	}

	// Write nvidia-smi script (executable)
	nvidiaSmiPath := filepath.Join(disguisePath, "nvidia-smi")
	if err := os.WriteFile(nvidiaSmiPath, []byte(GenerateNvidiaSmi(cfg)), 0755); err != nil {
		return "", fmt.Errorf("failed to write nvidia-smi: %w", err)
	}

	return disguisePath, nil
}


// CleanupDisguiseFiles removes fake proc files for a container
func CleanupDisguiseFiles(userID int64) error {
	disguisePath := GetDisguisePath(userID)
	return os.RemoveAll(disguisePath)
}


// toDockerPath converts a Windows path to Docker-compatible path
// Docker Desktop on Windows needs paths like /c/Users/... or //c/Users/...
func toDockerPath(windowsPath string) string {
	// Replace backslashes with forward slashes
	path := strings.ReplaceAll(windowsPath, "\\", "/")
	
	// Convert C:\path to /c/path for Docker Desktop
	if len(path) >= 2 && path[1] == ':' {
		driveLetter := strings.ToLower(string(path[0]))
		path = "/" + driveLetter + path[2:]
	}
	
	return path
}

// GetBindMounts returns Docker bind mount configurations for disguise files
func GetBindMounts(userID int64) []mount.Mount {
	disguisePath := GetDisguisePath(userID)
	
	// Convert paths for Docker Desktop on Windows
	cpuinfoSource := toDockerPath(filepath.Join(disguisePath, "cpuinfo"))
	meminfoSource := toDockerPath(filepath.Join(disguisePath, "meminfo"))
	nvidiaSmiSource := toDockerPath(filepath.Join(disguisePath, "nvidia-smi"))
	
	return []mount.Mount{
		{
			Type:     mount.TypeBind,
			Source:   cpuinfoSource,
			Target:   "/proc/cpuinfo",
			ReadOnly: true,
		},
		{
			Type:     mount.TypeBind,
			Source:   meminfoSource,
			Target:   "/proc/meminfo",
			ReadOnly: true,
		},
		{
			Type:     mount.TypeBind,
			Source:   nvidiaSmiSource,
			Target:   "/usr/bin/nvidia-smi",
			ReadOnly: true,
		},
	}
}
