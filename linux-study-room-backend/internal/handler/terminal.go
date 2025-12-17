package handler

import (
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/linuxstudyroom/backend/internal/service"
	"github.com/linuxstudyroom/backend/internal/store"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in dev
	},
}

// TerminalHandler handles WebSocket terminal connections
type TerminalHandler struct {
	dockerSvc  *service.DockerService
	cleanupMgr *service.CleanupManager
	db         *sql.DB
}

// NewTerminalHandler creates a new terminal handler
func NewTerminalHandler(dockerSvc *service.DockerService, cleanupMgr *service.CleanupManager, db *sql.DB) *TerminalHandler {
	return &TerminalHandler{dockerSvc: dockerSvc, cleanupMgr: cleanupMgr, db: db}
}

// TerminalMessage represents WebSocket message
type TerminalMessage struct {
	Type string `json:"type"` // "input", "resize", "output", "status"
	Data string `json:"data,omitempty"`
	Cols uint   `json:"cols,omitempty"`
	Rows uint   `json:"rows,omitempty"`
}

// Handle handles WebSocket terminal connection
func (h *TerminalHandler) Handle(c *gin.Context) {
	containerID := c.Query("container_id")
	if containerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container_id required"})
		return
	}

	username := c.Query("username")
	if username == "" {
		username = "User"
	}
	os := c.Query("os")
	if os == "" {
		os = "linux"
	}

	// Upgrade to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("🔌 Terminal WebSocket connected for container: %s", containerID[:12])

	// Notify cleanup manager of connection
	if h.cleanupMgr != nil {
		h.cleanupMgr.OnConnect(containerID)
	}

	// Register session
	// Get avatar from query, fallback to dicebear
	avatar := c.Query("avatar")
	if avatar == "" {
		avatar = "https://api.dicebear.com/7.x/avataaars/svg?seed=" + username
	}
	name := c.Query("name")
	if name == "" {
		name = username
	}

	service.Sessions.Register(containerID, &service.Session{
		Username:    username,
		Name:        name,
		ContainerID: containerID,
		OS:          os,
		Avatar:      avatar,
		Snapshot:    "",
	})
	
	// Record connection for online time tracking
	if h.db != nil {
		store.RecordConnect(h.db, username, avatar)
	}
	
	defer func() {
		// Record disconnect for online time tracking
		if h.db != nil {
			store.RecordDisconnect(h.db, username)
		}
		// Stop container when user disconnects (container persists, just stopped)
		log.Printf("⏹️ Stopping container on disconnect: %s", containerID[:12])
		if err := h.dockerSvc.StopContainer(context.Background(), containerID); err != nil {
			log.Printf("⚠️ Failed to stop container: %v", err)
		}
		// Unregister session
		service.Sessions.Unregister(containerID)
	}()

	// Create exec session in container (works for both new and restarted containers)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	hijack, execID, err := h.dockerSvc.ExecContainer(ctx, containerID)
	if err != nil {
		log.Printf("Failed to exec in container: %v", err)
		conn.WriteJSON(TerminalMessage{Type: "status", Data: "error: " + err.Error()})
		return
	}
	defer hijack.Close()

	// execID is used for resize operations
	log.Printf("📺 Exec session created: %s", execID[:12])

	// Ping ticker to keep connection alive (no ReadDeadline - user may be idle)
	pingTicker := time.NewTicker(30 * time.Second)
	defer pingTicker.Stop()

	go func() {
		for range pingTicker.C {
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				cancel()
				return
			}
		}
	}()

	// Buffers for snapshot
	var cleanSnapshotBuffer strings.Builder
	var rawSnapshotBuffer strings.Builder

	// Goroutine: Container stdout -> WebSocket
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := hijack.Reader.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Container read error: %v", err)
				}
				cancel()
				return
			}
			if n > 0 {
				output := string(buf[:n])
				
				// Store raw output for xterm.js rendering (increased capacity for more history)
				rawSnapshotBuffer.WriteString(output)
				if rawSnapshotBuffer.Len() > 16000 {
					s := rawSnapshotBuffer.String()
					rawSnapshotBuffer.Reset()
					rawSnapshotBuffer.WriteString(s[len(s)-12000:])
				}
				
				// Store cleaned output for fallback text display
				cleanOutput := service.StripANSI(output)
				if len(cleanOutput) > 0 {
					cleanSnapshotBuffer.WriteString(cleanOutput)
					if cleanSnapshotBuffer.Len() > 400 {
						s := cleanSnapshotBuffer.String()
						cleanSnapshotBuffer.Reset()
						cleanSnapshotBuffer.WriteString(s[len(s)-300:])
					}
				}
				
				// Update session with both snapshots
				service.Sessions.UpdateSnapshot(containerID, rawSnapshotBuffer.String(), cleanSnapshotBuffer.String())

				msg := TerminalMessage{Type: "output", Data: output}
				if err := conn.WriteJSON(msg); err != nil {
					log.Printf("WebSocket write error: %v", err)
					cancel()
					return
				}
			}
		}
	}()

	// Idle timeout checker disabled - container stops on disconnect
	// go func() {
	// 	ticker := time.NewTicker(1 * time.Minute)
	// 	defer ticker.Stop()
	// 	for {
	// 		select {
	// 		case <-ctx.Done():
	// 			return
	// 		case <-ticker.C:
	// 			if time.Since(lastActivity) > idleTimeout {
	// 				log.Printf("⏰ Container %s idle timeout, stopping...", containerID[:12])
	// 				h.dockerSvc.StopContainer(context.Background(), containerID)
	// 				conn.WriteJSON(TerminalMessage{Type: "status", Data: "stopped"})
	// 				cancel()
	// 				return
	// 			}
	// 		}
	// 	}
	// }()

	// Main loop: WebSocket -> Container stdin
	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var msg TerminalMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			// Treat as raw input
			msg = TerminalMessage{Type: "input", Data: string(msgBytes)}
		}

		// lastActivity = time.Now() // disabled - no idle timeout

		switch msg.Type {
		case "input":
			if _, err := hijack.Conn.Write([]byte(msg.Data)); err != nil {
				log.Printf("Container write error: %v", err)
				break
			}
		case "resize":
			if err := h.dockerSvc.ResizeExecTTY(ctx, execID, msg.Cols, msg.Rows); err != nil {
				log.Printf("Resize error: %v", err)
			}
		}
	}

	log.Printf("🔌 Terminal WebSocket disconnected for container: %s", containerID[:12])
}

// HandleHelper handles WebSocket connection for helpers
// Helpers can send input to the container but don't own it
func (h *TerminalHandler) HandleHelper(c *gin.Context) {
	containerID := c.Query("container_id")
	if containerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container_id required"})
		return
	}

	helperUsername := c.Query("username")
	if helperUsername == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username required"})
		return
	}

	// Check if this user is a helper for this container
	if !service.Sessions.IsHelper(containerID, helperUsername) {
		c.JSON(http.StatusForbidden, gin.H{"error": "not authorized as helper"})
		return
	}

	// Upgrade to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("👥 Helper %s connected to container: %s", helperUsername, containerID[:12])

	// Create exec session for helper (they can run commands)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	hijack, execID, err := h.dockerSvc.ExecContainer(ctx, containerID)
	if err != nil {
		log.Printf("Failed to exec for helper: %v", err)
		conn.WriteJSON(TerminalMessage{Type: "status", Data: "error: " + err.Error()})
		return
	}
	defer hijack.Close()

	log.Printf("📺 Helper exec session created: %s", execID[:12])

	// Buffers for snapshot (helper's output also updates main session)
	var rawSnapshotBuffer strings.Builder

	// Goroutine: Container stdout -> WebSocket (helper sees output)
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := hijack.Reader.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Container read error (helper): %v", err)
				}
				cancel()
				return
			}
			if n > 0 {
				output := string(buf[:n])
				
				// Also update the main session's snapshot for LiveWall sync
				rawSnapshotBuffer.WriteString(output)
				if rawSnapshotBuffer.Len() > 16000 {
					s := rawSnapshotBuffer.String()
					rawSnapshotBuffer.Reset()
					rawSnapshotBuffer.WriteString(s[len(s)-12000:])
				}
				cleanOutput := service.StripANSI(output)
				service.Sessions.UpdateSnapshot(containerID, rawSnapshotBuffer.String(), cleanOutput)
				
				msg := TerminalMessage{Type: "output", Data: output}
				if err := conn.WriteJSON(msg); err != nil {
					log.Printf("WebSocket write error (helper): %v", err)
					cancel()
					return
				}
			}
		}
	}()

	// Main loop: WebSocket -> Container stdin (helper sends input)
	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error (helper): %v", err)
			}
			break
		}

		// Check if still a helper (could be revoked)
		if !service.Sessions.IsHelper(containerID, helperUsername) {
			conn.WriteJSON(TerminalMessage{Type: "status", Data: "revoked"})
			break
		}

		var msg TerminalMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			msg = TerminalMessage{Type: "input", Data: string(msgBytes)}
		}

		switch msg.Type {
		case "input":
			if _, err := hijack.Conn.Write([]byte(msg.Data)); err != nil {
				log.Printf("Container write error (helper): %v", err)
				break
			}
		case "resize":
			if err := h.dockerSvc.ResizeExecTTY(ctx, execID, msg.Cols, msg.Rows); err != nil {
				log.Printf("Resize error (helper): %v", err)
			}
		}
	}

	log.Printf("👥 Helper %s disconnected from container: %s", helperUsername, containerID[:12])
}
