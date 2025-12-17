package handler

import (
	"context"
	"database/sql"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/linuxstudyroom/backend/internal/service"
	"github.com/linuxstudyroom/backend/internal/store"
)

// ContainerHandler handles container API requests
type ContainerHandler struct {
	dockerSvc *service.DockerService
	db        *sql.DB
}

// NewContainerHandler creates a new container handler
func NewContainerHandler(dockerSvc *service.DockerService, db *sql.DB) *ContainerHandler {
	return &ContainerHandler{dockerSvc: dockerSvc, db: db}
}

// LaunchRequest represents container launch request
type LaunchRequest struct {
	OSType   string `json:"os_type" binding:"required,oneof=alpine debian ubuntu arch"`
	Username string `json:"username"`
}

// Launch creates and starts a new container, or reuses existing one
func (h *ContainerHandler) Launch(c *gin.Context) {
	var req LaunchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Generate unique user ID from username (or use timestamp if no username)
	username := req.Username
	if username == "" {
		username = "User_" + c.ClientIP()
	}
	
	// Create a stable unique ID based on username hash (no timestamp for consistency)
	var userID int64
	for _, b := range username {
		userID = userID*31 + int64(b)
	}
	if userID < 0 {
		userID = -userID
	}
	userID = userID % 1000000

	ctx := context.Background()

	// Check if user already has a container
	existingContainer, err := store.GetContainerByUserID(h.db, userID)
	if err == nil && existingContainer != nil && existingContainer.DockerID != "" {
		// User has existing container, try to reuse it
		status, err := h.dockerSvc.GetContainerStatus(ctx, existingContainer.DockerID)
		if err == nil {
			// Container exists in Docker
			if status == "exited" || status == "stopped" {
				// Start the stopped container
				if err := h.dockerSvc.StartContainer(ctx, existingContainer.DockerID); err != nil {
					log.Printf("Failed to start existing container: %v", err)
				} else {
					log.Printf("✅ Reusing existing container for user %s: %s", username, existingContainer.DockerID[:12])
					store.UpdateContainerStatus(h.db, existingContainer.ID, "running", existingContainer.DockerID)
					c.JSON(http.StatusOK, gin.H{
						"container_id": existingContainer.DockerID,
						"status":       "running",
						"os_type":      existingContainer.OSType,
						"username":     username,
						"reused":       true,
					})
					return
				}
			} else if status == "running" {
				// Container already running
				log.Printf("✅ Container already running for user %s: %s", username, existingContainer.DockerID[:12])
				c.JSON(http.StatusOK, gin.H{
					"container_id": existingContainer.DockerID,
					"status":       "running",
					"os_type":      existingContainer.OSType,
					"username":     username,
					"reused":       true,
				})
				return
			}
		}
		// Container not found in Docker, will create new one
		log.Printf("⚠️ Existing container not found in Docker, creating new one for user %s", username)
	}

	// Create new container
	dockerID, err := h.dockerSvc.CreateContainer(ctx, &service.ContainerConfig{
		UserID:   userID,
		OSType:   req.OSType,
		Username: username,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Save or update database
	if existingContainer != nil {
		// Update existing record
		store.UpdateContainerStatus(h.db, existingContainer.ID, "running", dockerID)
	} else {
		// Create new record
		container := &store.Container{
			UserID:   userID,
			DockerID: dockerID,
			OSType:   req.OSType,
			Status:   "running",
		}
		store.CreateContainer(h.db, container)
	}

	c.JSON(http.StatusOK, gin.H{
		"container_id": dockerID,
		"status":       "running",
		"os_type":      req.OSType,
		"username":     username,
		"reused":       false,
	})
}

// Restart restarts a container
func (h *ContainerHandler) Restart(c *gin.Context) {
	containerID := c.Param("id")
	if containerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container ID required"})
		return
	}

	ctx := context.Background()

	// Stop container
	if err := h.dockerSvc.StopContainer(ctx, containerID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to stop: " + err.Error()})
		return
	}

	// Start container
	if err := h.dockerSvc.StartContainer(ctx, containerID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to start: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "running", "message": "container restarted"})
}

// Reset destroys and recreates a container
func (h *ContainerHandler) Reset(c *gin.Context) {
	containerID := c.Param("id")
	if containerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container ID required"})
		return
	}

	ctx := context.Background()

	// Remove container
	if err := h.dockerSvc.RemoveContainer(ctx, containerID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to remove: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "destroyed", "message": "container destroyed, use /launch to create new one"})
}

// Status returns container status
func (h *ContainerHandler) Status(c *gin.Context) {
	containerID := c.Param("id")
	if containerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container ID required"})
		return
	}

	status, err := h.dockerSvc.GetContainerStatus(context.Background(), containerID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "container not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"container_id": containerID, "status": status})
}


// CheckRequest represents container check request
type CheckRequest struct {
	Username string `json:"username" binding:"required"`
}

// Check checks if user has an existing container and returns its info
func (h *ContainerHandler) Check(c *gin.Context) {
	var req CheckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	username := req.Username

	// Create stable user ID from username
	var userID int64
	for _, b := range username {
		userID = userID*31 + int64(b)
	}
	if userID < 0 {
		userID = -userID
	}
	userID = userID % 1000000

	ctx := context.Background()

	// Check if user has a container in database
	existingContainer, err := store.GetContainerByUserID(h.db, userID)
	if err != nil || existingContainer == nil || existingContainer.DockerID == "" {
		c.JSON(http.StatusOK, gin.H{
			"has_container": false,
		})
		return
	}

	// Check if container exists in Docker
	status, err := h.dockerSvc.GetContainerStatus(ctx, existingContainer.DockerID)
	if err != nil {
		// Container not found in Docker
		c.JSON(http.StatusOK, gin.H{
			"has_container": false,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"has_container": true,
		"container_id":  existingContainer.DockerID,
		"os_type":       existingContainer.OSType,
		"status":        status,
	})
}
