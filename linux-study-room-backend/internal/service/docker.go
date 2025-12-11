package service

import (
	"archive/tar"
	"bytes"
	"context"
	"fmt"
	"io"
	"log"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/mount"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
)

// 安全网络配置
const (
	// IsolatedNetworkName 隔离网络名称，禁止容器间互通
	IsolatedNetworkName = "lsr-isolated"
	// IsolatedNetworkSubnet 隔离网络子网
	IsolatedNetworkSubnet = "172.28.0.0/16"
)

// DockerService wraps Docker API operations
type DockerService struct {
	cli *client.Client
}

// ContainerConfig holds container creation options
type ContainerConfig struct {
	UserID   int64
	OSType   string // "alpine" or "debian"
	Username string
}

// Dockerfile templates for pre-built images
var dockerfiles = map[string]string{
	"lsr-alpine": `FROM alpine:3.19
RUN apk add --no-cache fish
CMD ["fish"]`,
	"lsr-debian": `FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends fish && rm -rf /var/lib/apt/lists/*
CMD ["fish"]`,
}

// NewDockerService creates a new Docker service
func NewDockerService() (*DockerService, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, err
	}
	
	// Test connection
	_, err = cli.Ping(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Docker: %w", err)
	}
	
	log.Println("✅ Connected to Docker daemon")
	
	svc := &DockerService{cli: cli}
	
	// Auto-build images if they don't exist
	if err := svc.buildImagesIfNeeded(context.Background()); err != nil {
		log.Printf("⚠️ Warning: Failed to build images: %v", err)
	}
	
	// Create isolated network for security
	if err := svc.createIsolatedNetwork(context.Background()); err != nil {
		log.Printf("⚠️ Warning: Failed to create isolated network: %v", err)
	}
	
	return svc, nil
}

// buildImagesIfNeeded checks and builds lsr-alpine and lsr-debian images
func (d *DockerService) buildImagesIfNeeded(ctx context.Context) error {
	for imageName, dockerfile := range dockerfiles {
		// Check if image exists
		_, _, err := d.cli.ImageInspectWithRaw(ctx, imageName)
		if err == nil {
			log.Printf("✅ Image already exists: %s", imageName)
			continue
		}
		
		// Build image
		log.Printf("🔨 Building image: %s (this may take a while...)", imageName)
		
		// Create tar archive with Dockerfile
		buf := new(bytes.Buffer)
		tw := tar.NewWriter(buf)
		dockerfileBytes := []byte(dockerfile)
		tw.WriteHeader(&tar.Header{
			Name: "Dockerfile",
			Size: int64(len(dockerfileBytes)),
		})
		tw.Write(dockerfileBytes)
		tw.Close()
		
		// Build
		resp, err := d.cli.ImageBuild(ctx, buf, types.ImageBuildOptions{
			Tags:       []string{imageName},
			Dockerfile: "Dockerfile",
			Remove:     true,
		})
		if err != nil {
			return fmt.Errorf("failed to build %s: %w", imageName, err)
		}
		
		// Wait for build to complete
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		
		log.Printf("✅ Image built: %s", imageName)
	}
	return nil
}

// createIsolatedNetwork creates an isolated Docker network for container security
// This network disables inter-container communication (ICC)
func (d *DockerService) createIsolatedNetwork(ctx context.Context) error {
	// Check if network already exists
	_, err := d.cli.NetworkInspect(ctx, IsolatedNetworkName, types.NetworkInspectOptions{})
	if err == nil {
		log.Printf("✅ Isolated network already exists: %s", IsolatedNetworkName)
		return nil
	}

	// Create the network with ICC disabled
	log.Printf("🔒 Creating isolated network: %s", IsolatedNetworkName)
	
	_, err = d.cli.NetworkCreate(ctx, IsolatedNetworkName, types.NetworkCreate{
		Driver: "bridge",
		IPAM: &network.IPAM{
			Config: []network.IPAMConfig{
				{Subnet: IsolatedNetworkSubnet},
			},
		},
		Options: map[string]string{
			// Disable Inter-Container Communication
			"com.docker.network.bridge.enable_icc": "false",
		},
	})
	if err != nil {
		return fmt.Errorf("failed to create isolated network: %w", err)
	}

	log.Printf("✅ Isolated network created: %s (ICC disabled)", IsolatedNetworkName)
	return nil
}

// CreateContainer creates a new user container
func (d *DockerService) CreateContainer(ctx context.Context, cfg *ContainerConfig) (string, error) {
	// Select image based on OS type - use pre-built images with fish
	imageName := "lsr-alpine"
	if cfg.OSType == "debian" {
		imageName = "lsr-debian"
	}

	// Check if image already exists
	_, _, err := d.cli.ImageInspectWithRaw(ctx, imageName)
	if err != nil {
		// Image doesn't exist, try to pull or build
		log.Printf("⚠️ Image %s not found. Please build it first with: docker build -t %s .", imageName, imageName)
		return "", fmt.Errorf("image %s not found - please build it first", imageName)
	} else {
		log.Printf("✅ Using pre-built image: %s", imageName)
	}

	// Container name
	containerName := fmt.Sprintf("lsr-user-%d", cfg.UserID)

	// Remove any existing container with the same name to avoid conflicts
	// This handles cases where database lost track of a container but Docker still has it
	if oldInfo, err := d.cli.ContainerInspect(ctx, containerName); err == nil {
		log.Printf("⚠️ Found orphaned container %s, removing it...", containerName)
		d.cli.ContainerRemove(ctx, oldInfo.ID, container.RemoveOptions{Force: true})
	}

	// Fish is pre-installed, just run it directly
	shellCmd := []string{"fish"}

	// Create disguise files for system info spoofing (fun feature)
	_, disguiseErr := CreateDisguiseFiles(cfg.UserID, nil)
	if disguiseErr != nil {
		log.Printf("⚠️ Warning: Failed to create disguise files: %v", disguiseErr)
		// Continue without disguise - it's a non-critical feature
	}

	// Get bind mounts for disguise files
	var mounts []mount.Mount
	if disguiseErr == nil {
		mounts = GetBindMounts(cfg.UserID)
		log.Printf("🎭 System disguise enabled: 16-core CPU, 64GB RAM, RTX 4060")
	}

	// Create container
	resp, err := d.cli.ContainerCreate(ctx,
		&container.Config{
			Image:        imageName,
			Cmd:          shellCmd,
			Tty:          true,
			OpenStdin:    true,
			AttachStdin:  true,
			AttachStdout: true,
			AttachStderr: true,
			Env: []string{
				fmt.Sprintf("USER=%s", cfg.Username),
				"TERM=xterm-256color",
				"COLORTERM=truecolor",
			},
		},
		&container.HostConfig{
			NetworkMode: container.NetworkMode(IsolatedNetworkName),
			Resources: container.Resources{
				Memory:   256 * 1024 * 1024, // 256MB
				NanoCPUs: 500000000,          // 0.5 CPU
			},
			Mounts: mounts,
			// Security: Drop unnecessary capabilities
			CapDrop: []string{"ALL"},
			CapAdd:  []string{"CHOWN", "SETUID", "SETGID"},
			// Security: Read-only root filesystem (optional, may break some commands)
			// ReadonlyRootfs: true,
			// Security: Prevent privilege escalation
			SecurityOpt: []string{"no-new-privileges"},
		},
		nil, nil, containerName,
	)
	if err != nil {
		return "", fmt.Errorf("failed to create container: %w", err)
	}

	// Start container
	if err := d.cli.ContainerStart(ctx, resp.ID, container.StartOptions{}); err != nil {
		return "", fmt.Errorf("failed to start container: %w", err)
	}

	log.Printf("✅ Container created and started: %s", resp.ID[:12])
	return resp.ID, nil
}

// StopContainer stops a container
func (d *DockerService) StopContainer(ctx context.Context, containerID string) error {
	timeout := 10
	return d.cli.ContainerStop(ctx, containerID, container.StopOptions{Timeout: &timeout})
}

// StartContainer starts a stopped container
func (d *DockerService) StartContainer(ctx context.Context, containerID string) error {
	return d.cli.ContainerStart(ctx, containerID, container.StartOptions{})
}

// RemoveContainer removes a container and cleans up disguise files
func (d *DockerService) RemoveContainer(ctx context.Context, containerID string) error {
	// Try to get container info to extract userID for cleanup
	info, err := d.cli.ContainerInspect(ctx, containerID)
	if err == nil {
		// Container name format: /lsr-user-{userID}
		name := info.Name
		var userID int64
		if _, scanErr := fmt.Sscanf(name, "/lsr-user-%d", &userID); scanErr == nil && userID > 0 {
			// Cleanup disguise files
			if cleanupErr := CleanupDisguiseFiles(userID); cleanupErr != nil {
				log.Printf("⚠️ Warning: Failed to cleanup disguise files for user %d: %v", userID, cleanupErr)
			} else {
				log.Printf("🧹 Cleaned up disguise files for user %d", userID)
			}
		}
	}
	
	return d.cli.ContainerRemove(ctx, containerID, container.RemoveOptions{Force: true})
}

// GetContainerStatus returns container status
func (d *DockerService) GetContainerStatus(ctx context.Context, containerID string) (string, error) {
	info, err := d.cli.ContainerInspect(ctx, containerID)
	if err != nil {
		return "", err
	}
	return info.State.Status, nil
}

// AttachContainer attaches to container stdin/stdout
func (d *DockerService) AttachContainer(ctx context.Context, containerID string) (types.HijackedResponse, error) {
	return d.cli.ContainerAttach(ctx, containerID, container.AttachOptions{
		Stream: true,
		Stdin:  true,
		Stdout: true,
		Stderr: true,
	})
}

// ResizeContainerTTY resizes container terminal
func (d *DockerService) ResizeContainerTTY(ctx context.Context, containerID string, cols, rows uint) error {
	return d.cli.ContainerResize(ctx, containerID, container.ResizeOptions{
		Height: rows,
		Width:  cols,
	})
}


// ExecContainer creates an exec instance and attaches to it (for reconnecting to stopped containers)
func (d *DockerService) ExecContainer(ctx context.Context, containerID string) (types.HijackedResponse, string, error) {
	// Create exec instance
	execResp, err := d.cli.ContainerExecCreate(ctx, containerID, types.ExecConfig{
		Cmd:          []string{"fish"},
		AttachStdin:  true,
		AttachStdout: true,
		AttachStderr: true,
		Tty:          true,
		Env: []string{
			"TERM=xterm-256color",
			"COLORTERM=truecolor",
		},
	})
	if err != nil {
		return types.HijackedResponse{}, "", fmt.Errorf("failed to create exec: %w", err)
	}

	// Attach to exec
	attachResp, err := d.cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{
		Tty: true,
	})
	if err != nil {
		return types.HijackedResponse{}, "", fmt.Errorf("failed to attach exec: %w", err)
	}

	return attachResp, execResp.ID, nil
}

// ResizeExecTTY resizes exec terminal
func (d *DockerService) ResizeExecTTY(ctx context.Context, execID string, cols, rows uint) error {
	return d.cli.ContainerExecResize(ctx, execID, container.ResizeOptions{
		Height: rows,
		Width:  cols,
	})
}
