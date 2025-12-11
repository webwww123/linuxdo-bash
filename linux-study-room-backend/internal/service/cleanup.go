package service

import (
	"context"
	"database/sql"
	"log"
	"sync"
	"time"

	"github.com/docker/docker/api/types/container"
)

// ContainerOperations defines the interface for container operations (for testing)
type ContainerOperations interface {
	StopContainer(ctx context.Context, containerID string) error
	RemoveContainer(ctx context.Context, containerID string) error
}

// CleanupManager manages container cleanup timers and connection counting
type CleanupManager struct {
	mu              sync.RWMutex
	timers          map[string]*time.Timer // containerID -> cleanup timer
	connectionCount map[string]int         // containerID -> active connection count
	dockerSvc       *DockerService
	containerOps    ContainerOperations // for testing with mock
	db              *sql.DB
	cleanupDelay    time.Duration
	// Metrics for testing
	StopAttempts   int
	RemoveAttempts int
}

// NewCleanupManager creates a new cleanup manager
func NewCleanupManager(dockerSvc *DockerService, db *sql.DB) *CleanupManager {
	return &CleanupManager{
		timers:          make(map[string]*time.Timer),
		connectionCount: make(map[string]int),
		dockerSvc:       dockerSvc,
		db:              db,
		cleanupDelay:    20 * time.Minute,
	}
}

// NewCleanupManagerWithDelay creates a cleanup manager with custom delay (for testing)
func NewCleanupManagerWithDelay(dockerSvc *DockerService, db *sql.DB, delay time.Duration) *CleanupManager {
	cm := NewCleanupManager(dockerSvc, db)
	cm.cleanupDelay = delay
	return cm
}

// NewCleanupManagerWithOps creates a cleanup manager with custom container operations (for testing)
func NewCleanupManagerWithOps(ops ContainerOperations, db *sql.DB, delay time.Duration) *CleanupManager {
	return &CleanupManager{
		timers:          make(map[string]*time.Timer),
		connectionCount: make(map[string]int),
		containerOps:    ops,
		db:              db,
		cleanupDelay:    delay,
	}
}

// OnConnect is called when a user connects to a container
func (cm *CleanupManager) OnConnect(containerID string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	// Increment connection count
	cm.connectionCount[containerID]++
	count := cm.connectionCount[containerID]

	log.Printf("🔗 Container %s: connection added (total: %d)", containerID[:min(12, len(containerID))], count)

	// Cancel any pending cleanup timer
	if timer, exists := cm.timers[containerID]; exists {
		timer.Stop()
		delete(cm.timers, containerID)
		log.Printf("⏹️ Container %s: cleanup timer cancelled due to reconnection", containerID[:min(12, len(containerID))])
	}
}

// OnDisconnect is called when a user disconnects from a container
func (cm *CleanupManager) OnDisconnect(containerID string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	// Decrement connection count
	if count, exists := cm.connectionCount[containerID]; exists && count > 0 {
		cm.connectionCount[containerID]--
	}

	count := cm.connectionCount[containerID]
	log.Printf("🔌 Container %s: connection removed (remaining: %d)", containerID[:min(12, len(containerID))], count)

	// Only start cleanup timer when all connections are closed
	if count == 0 {
		cm.startCleanupTimer(containerID)
	}
}

// startCleanupTimer starts a cleanup timer for the container
func (cm *CleanupManager) startCleanupTimer(containerID string) {
	// Cancel existing timer if any
	if timer, exists := cm.timers[containerID]; exists {
		timer.Stop()
	}

	cleanupTime := time.Now().Add(cm.cleanupDelay)
	log.Printf("⏰ Container %s: cleanup scheduled at %s", containerID[:min(12, len(containerID))], cleanupTime.Format("15:04:05"))

	cm.timers[containerID] = time.AfterFunc(cm.cleanupDelay, func() {
		cm.executeCleanup(containerID)
	})
}

// executeCleanup performs the actual container cleanup
func (cm *CleanupManager) executeCleanup(containerID string) {
	cm.mu.Lock()
	// Check if user reconnected while we were waiting
	if cm.connectionCount[containerID] > 0 {
		log.Printf("⏹️ Container %s: cleanup aborted - user reconnected", containerID[:min(12, len(containerID))])
		delete(cm.timers, containerID)
		cm.mu.Unlock()
		return
	}
	delete(cm.timers, containerID)
	delete(cm.connectionCount, containerID)
	cm.mu.Unlock()

	log.Printf("🧹 Container %s: starting cleanup...", containerID[:min(12, len(containerID))])

	ctx := context.Background()
	var lastErr error

	// Determine which container operations to use
	var stopFunc func(context.Context, string) error
	var removeFunc func(context.Context, string) error

	if cm.containerOps != nil {
		stopFunc = cm.containerOps.StopContainer
		removeFunc = cm.containerOps.RemoveContainer
	} else if cm.dockerSvc != nil {
		stopFunc = cm.dockerSvc.StopContainer
		removeFunc = cm.dockerSvc.RemoveContainer
	}

	// Stop and remove container (only if operations are available)
	if stopFunc != nil && removeFunc != nil {
		// Stop container with retry
		for i := 0; i < 2; i++ {
			cm.StopAttempts++
			if err := stopFunc(ctx, containerID); err != nil {
				log.Printf("⚠️ Container %s: stop attempt %d failed: %v", containerID[:min(12, len(containerID))], i+1, err)
				lastErr = err
				time.Sleep(2 * time.Second)
			} else {
				lastErr = nil
				break
			}
		}

		// Remove container with retry (up to 3 times)
		for i := 0; i < 3; i++ {
			cm.RemoveAttempts++
			if err := removeFunc(ctx, containerID); err != nil {
				log.Printf("⚠️ Container %s: remove attempt %d failed: %v", containerID[:min(12, len(containerID))], i+1, err)
				lastErr = err
				time.Sleep(5 * time.Second)
			} else {
				lastErr = nil
				log.Printf("✅ Container %s: removed successfully", containerID[:min(12, len(containerID))])
				break
			}
		}

		if lastErr != nil {
			log.Printf("❌ Container %s: cleanup failed after retries: %v", containerID[:min(12, len(containerID))], lastErr)
		}
	}

	// Update database status
	if cm.db != nil {
		_, err := cm.db.Exec(
			"UPDATE containers SET status = 'removed', last_active = CURRENT_TIMESTAMP WHERE docker_id = ?",
			containerID,
		)
		if err != nil {
			log.Printf("⚠️ Container %s: database update failed: %v", containerID[:min(12, len(containerID))], err)
		}
	}

	// Unregister session
	Sessions.Unregister(containerID)
}

// CancelCleanup cancels any pending cleanup for a container
func (cm *CleanupManager) CancelCleanup(containerID string) bool {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	if timer, exists := cm.timers[containerID]; exists {
		timer.Stop()
		delete(cm.timers, containerID)
		log.Printf("⏹️ Container %s: cleanup timer cancelled", containerID[:min(12, len(containerID))])
		return true
	}
	return false
}

// GetConnectionCount returns the current connection count for a container
func (cm *CleanupManager) GetConnectionCount(containerID string) int {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	return cm.connectionCount[containerID]
}

// HasPendingCleanup checks if a container has a pending cleanup timer
func (cm *CleanupManager) HasPendingCleanup(containerID string) bool {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	_, exists := cm.timers[containerID]
	return exists
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}


// CleanupStaleContainers removes all lsr-user-* containers that are currently running
// This should be called at startup to clean up containers from previous sessions
func (cm *CleanupManager) CleanupStaleContainers() {
	if cm.dockerSvc == nil || cm.dockerSvc.cli == nil {
		log.Println("⚠️ Docker service not available, skipping stale container cleanup")
		return
	}

	log.Println("🔍 Scanning for stale containers...")

	ctx := context.Background()

	// List all containers (including stopped ones)
	containers, err := cm.dockerSvc.cli.ContainerList(ctx, container.ListOptions{
		All: true,
	})
	if err != nil {
		log.Printf("⚠️ Failed to list containers: %v", err)
		return
	}

	cleanedCount := 0
	for _, c := range containers {
		// Check if it's an lsr-user container
		for _, name := range c.Names {
			if len(name) > 0 && name[0] == '/' {
				name = name[1:] // Remove leading slash
			}
			if len(name) >= 8 && name[:8] == "lsr-user" {
				log.Printf("🧹 Cleaning stale container: %s (%s)", name, c.ID[:12])

				// Stop if running
				if c.State == "running" {
					if err := cm.dockerSvc.StopContainer(ctx, c.ID); err != nil {
						log.Printf("⚠️ Failed to stop %s: %v", name, err)
					}
				}

				// Remove container
				if err := cm.dockerSvc.RemoveContainer(ctx, c.ID); err != nil {
					log.Printf("⚠️ Failed to remove %s: %v", name, err)
				} else {
					cleanedCount++
				}
				break
			}
		}
	}

	if cleanedCount > 0 {
		log.Printf("✅ Cleaned up %d stale containers", cleanedCount)
	} else {
		log.Println("✅ No stale containers found")
	}
}
