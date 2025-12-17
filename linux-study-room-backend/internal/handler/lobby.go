package handler

import (
	"database/sql"
	"encoding/json"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/linuxstudyroom/backend/internal/service"
	"github.com/linuxstudyroom/backend/internal/store"
)

// Invite cooldown duration
const inviteCooldownSeconds = 30

// LobbyHandler handles lobby/chat WebSocket connections
type LobbyHandler struct {
	clients         map[*websocket.Conn]*LobbyClient
	mu              sync.RWMutex
	db              *sql.DB
	inviteCooldowns map[string]time.Time // Track invite cooldowns per user
	cooldownMu      sync.RWMutex
}

// LobbyClient represents a connected client
type LobbyClient struct {
	Username string
	Name     string // Display name (nickname)
	Avatar   string
	OS       string
}

// LobbyMessage represents lobby WebSocket message
type LobbyMessage struct {
	Type              string        `json:"type"` // "users", "chat", "join", "leave", "snapshots", "like", "pin", "unpin", "history", "invite", "invite_accept", "invite_reject", "invite_sent", "invite_rejected_notify", "control_revoke", "helper_leave", "owner_cancel"
	Count             int           `json:"count,omitempty"`
	Sessions          []SessionInfo `json:"sessions,omitempty"`
	User              string        `json:"user,omitempty"`
	UserName          string        `json:"userName,omitempty"`          // Display name for chat messages
	Content           string        `json:"content,omitempty"`
	Timestamp         int64         `json:"ts,omitempty"`
	TargetContainerID string        `json:"targetContainerId,omitempty"` // For like/pin/unpin
	TargetUsername    string        `json:"targetUsername,omitempty"`    // Target user for display
	Messages          []ChatHistory `json:"messages,omitempty"`          // For history
	InviteFrom        string        `json:"inviteFrom,omitempty"`        // Inviter username (for invite messages)
	InviteTo          string        `json:"inviteTo,omitempty"`          // Invitee username (for invite messages)
	CooldownRemaining int           `json:"cooldownRemaining,omitempty"` // Remaining cooldown seconds
}

// ChatHistory represents a historical chat message
type ChatHistory struct {
	User      string `json:"user"`
	Content   string `json:"content"`
	Timestamp string `json:"ts"`
}

// SessionInfo represents a user session with snapshot
type SessionInfo struct {
	ID          int      `json:"id"`
	ContainerID string   `json:"containerId"`
	Username    string   `json:"username"`
	Name        string   `json:"name"`
	OS          string   `json:"os"`
	Avatar      string   `json:"avatar"`
	Snapshot    string   `json:"snapshot,omitempty"`
	RawSnapshot string   `json:"rawSnapshot,omitempty"`
	PinCount    int      `json:"pinCount"`
	Helpers     []string `json:"helpers,omitempty"` // List of usernames helping this session
}

// NewLobbyHandler creates a new lobby handler
func NewLobbyHandler(db *sql.DB) *LobbyHandler {
	h := &LobbyHandler{
		clients:         make(map[*websocket.Conn]*LobbyClient),
		db:              db,
		inviteCooldowns: make(map[string]time.Time),
	}
	
	// Start snapshot broadcaster
	go h.broadcastSnapshots()
	
	return h
}

// broadcastSnapshots sends terminal snapshots every 3 seconds
func (h *LobbyHandler) broadcastSnapshots() {
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()
	
	for range ticker.C {
		sessions := service.Sessions.GetAllSessions()
		if len(sessions) == 0 {
			continue
		}
		
		sessionInfos := make([]SessionInfo, 0, len(sessions))
		for _, s := range sessions {
			sessionInfos = append(sessionInfos, SessionInfo{
				ContainerID: s.ContainerID,
				Username:    s.Username,
				Name:        s.Name,
				OS:          s.OS,
				Avatar:      s.Avatar,
				Snapshot:    s.Snapshot,
				RawSnapshot: s.RawSnapshot,
				PinCount:    s.PinCount,
				Helpers:     s.Helpers,
			})
		}
		
		// Sort by PinCount descending, then by Username for stable order
		sort.Slice(sessionInfos, func(i, j int) bool {
			if sessionInfos[i].PinCount != sessionInfos[j].PinCount {
				return sessionInfos[i].PinCount > sessionInfos[j].PinCount
			}
			return sessionInfos[i].Username < sessionInfos[j].Username
		})
		
		// Assign IDs after sorting
		for i := range sessionInfos {
			sessionInfos[i].ID = i + 1
		}
		
		msg := LobbyMessage{
			Type:     "snapshots",
			Count:    len(sessions),
			Sessions: sessionInfos,
		}
		
		h.broadcast(msg)
	}
}

// Handle handles lobby WebSocket connection
func (h *LobbyHandler) Handle(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	username := c.Query("username")
	if username == "" {
		username = "Guest_" + c.ClientIP()
	}
	
	// Get display name from query, fallback to username
	name := c.Query("name")
	if name == "" {
		name = username
	}
	
	// Get avatar from query, fallback to dicebear
	avatar := c.Query("avatar")
	if avatar == "" {
		avatar = "https://api.dicebear.com/7.x/avataaars/svg?seed=" + username
	}

	client := &LobbyClient{
		Username: username,
		Name:     name,
		Avatar:   avatar,
		OS:       c.Query("os"),
	}

	// Register client
	h.mu.Lock()
	h.clients[conn] = client
	h.mu.Unlock()

	log.Printf("👋 Lobby: %s joined (%d online)", username, len(h.clients))

	// Send initial session list
	h.sendSessionList(conn)
	
	// Send chat history
	h.sendChatHistory(conn)

	// Ping ticker to keep connection alive (no ReadDeadline - user may be idle)
	pingTicker := time.NewTicker(30 * time.Second)
	defer pingTicker.Stop()

	// Start ping goroutine
	done := make(chan struct{})
	go func() {
		for {
			select {
			case <-done:
				return
			case <-pingTicker.C:
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			}
		}
	}()

	// Read messages
	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			close(done)
			break
		}

		var msg LobbyMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			continue
		}

		switch msg.Type {
		case "chat":
			// Save to database (use username for storage, name for display)
			if h.db != nil {
				store.SaveChatMessage(h.db, client.Name, client.Avatar, msg.Content, "text")
			}
			// Broadcast chat message with display name
			chatMsg := LobbyMessage{
				Type:      "chat",
				User:      client.Name, // Use display name instead of username
				UserName:  username,    // Keep username for internal reference
				Content:   msg.Content,
				Timestamp: time.Now().Unix(),
			}
			h.broadcast(chatMsg)
		
		case "like":
			// Broadcast like event to all clients
			if msg.TargetContainerID != "" {
				targetSession := service.Sessions.GetSession(msg.TargetContainerID)
				targetUsername := ""
				if targetSession != nil {
					targetUsername = targetSession.Username
				}
				likeMsg := LobbyMessage{
					Type:              "like",
					User:              username,
					TargetContainerID: msg.TargetContainerID,
					TargetUsername:    targetUsername,
					Timestamp:         time.Now().Unix(),
				}
				h.broadcast(likeMsg)
				log.Printf("❤️ %s liked %s", username, msg.TargetContainerID[:12])
			}
		
		case "pin":
			// Pin a session
			if msg.TargetContainerID != "" {
				if service.Sessions.PinSession(msg.TargetContainerID, username) {
					targetSession := service.Sessions.GetSession(msg.TargetContainerID)
					targetUsername := ""
					if targetSession != nil {
						targetUsername = targetSession.Username
					}
					pinMsg := LobbyMessage{
						Type:              "pin",
						User:              username,
						TargetContainerID: msg.TargetContainerID,
						TargetUsername:    targetUsername,
						Timestamp:         time.Now().Unix(),
					}
					h.broadcast(pinMsg)
					log.Printf("📌 %s pinned %s", username, msg.TargetContainerID[:12])
				}
			}
		
		case "unpin":
			// Unpin a session
			if msg.TargetContainerID != "" {
				if service.Sessions.UnpinSession(msg.TargetContainerID, username) {
					unpinMsg := LobbyMessage{
						Type:              "unpin",
						User:              username,
						TargetContainerID: msg.TargetContainerID,
						Timestamp:         time.Now().Unix(),
					}
					h.broadcast(unpinMsg)
					log.Printf("📍 %s unpinned %s", username, msg.TargetContainerID[:12])
				}
			}
		
		case "invite":
			// User invites another user to help control their terminal
			// msg.InviteTo = target username to invite
			log.Printf("📨 Invite request received: from=%s, to=%s", username, msg.InviteTo)
			if msg.InviteTo != "" {
				// Check cooldown
				h.cooldownMu.RLock()
				lastInvite, hasCooldown := h.inviteCooldowns[username]
				h.cooldownMu.RUnlock()
				
				if hasCooldown {
					remaining := int(inviteCooldownSeconds - time.Since(lastInvite).Seconds())
					if remaining > 0 {
						// Send cooldown error back to sender
						errMsg := LobbyMessage{
							Type:              "invite_error",
							User:              username,
							Content:           "请等待冷却时间结束后再邀请",
							CooldownRemaining: remaining,
							Timestamp:         time.Now().Unix(),
						}
						conn.WriteJSON(errMsg)
						log.Printf("❌ Invite cooldown: %s has %d seconds remaining", username, remaining)
						continue
					}
				}
				
				// Find inviter's session
				inviterSession := service.Sessions.GetSessionByUsername(username)
				if inviterSession == nil {
					log.Printf("⚠️ Invite failed: %s has no active session", username)
					continue
				}
				
				log.Printf("✅ Inviter session found: %s -> container %s", username, inviterSession.ContainerID[:12])
				
				// Update cooldown
				h.cooldownMu.Lock()
				h.inviteCooldowns[username] = time.Now()
				h.cooldownMu.Unlock()
				
				// Set pending invite
				service.Sessions.SetPendingInvite(inviterSession.ContainerID, msg.InviteTo)
				
				// Send confirmation to inviter
				sentMsg := LobbyMessage{
					Type:              "invite_sent",
					User:              username,
					InviteTo:          msg.InviteTo,
					TargetContainerID: inviterSession.ContainerID,
					Content:           "邀请已发送，等待 " + msg.InviteTo + " 回应",
					Timestamp:         time.Now().Unix(),
				}
				conn.WriteJSON(sentMsg)
				
				// Broadcast invite to all (target will filter)
				inviteMsg := LobbyMessage{
					Type:              "invite",
					InviteFrom:        username,
					InviteTo:          msg.InviteTo,
					TargetContainerID: inviterSession.ContainerID,
					Timestamp:         time.Now().Unix(),
				}
				h.broadcast(inviteMsg)
				
				// Also broadcast a chat message so everyone can see
				chatMsg := LobbyMessage{
					Type:      "chat",
					User:      "System",
					Content:   username + " 邀请 " + msg.InviteTo + " 远程协助控制终端",
					Timestamp: time.Now().Unix(),
				}
				h.broadcast(chatMsg)
				
				log.Printf("📨 %s invited %s to help control", username, msg.InviteTo)
			}
		
		case "invite_accept":
			// User accepts an invite
			// msg.TargetContainerID = the inviter's container ID
			if msg.TargetContainerID != "" {
				// Add helper to session
				if service.Sessions.AddHelper(msg.TargetContainerID, username) {
					targetSession := service.Sessions.GetSession(msg.TargetContainerID)
					inviterUsername := ""
					if targetSession != nil {
						inviterUsername = targetSession.Username
					}
					
					acceptMsg := LobbyMessage{
						Type:              "invite_accept",
						User:              username,          // Helper who accepted
						TargetContainerID: msg.TargetContainerID,
						TargetUsername:    inviterUsername,   // Session owner
						Timestamp:         time.Now().Unix(),
					}
					h.broadcast(acceptMsg)
					log.Printf("✅ %s accepted invite from %s", username, inviterUsername)
				}
			}
		
		case "invite_reject":
			// User rejects an invite
			if msg.TargetContainerID != "" {
				service.Sessions.ClearPendingInvite(msg.TargetContainerID)
				
				targetSession := service.Sessions.GetSession(msg.TargetContainerID)
				inviterUsername := ""
				if targetSession != nil {
					inviterUsername = targetSession.Username
				}
				
				// Broadcast reject event
				rejectMsg := LobbyMessage{
					Type:              "invite_reject",
					User:              username,
					TargetContainerID: msg.TargetContainerID,
					TargetUsername:    inviterUsername,
					Timestamp:         time.Now().Unix(),
				}
				h.broadcast(rejectMsg)
				
				// Send direct notification to inviter
				notifyMsg := LobbyMessage{
					Type:              "invite_rejected_notify",
					User:              username, // Person who rejected
					TargetUsername:    inviterUsername,
					Content:           username + " 拒绝了你的邀请",
					TargetContainerID: msg.TargetContainerID,
					Timestamp:         time.Now().Unix(),
				}
				h.broadcast(notifyMsg)
				
				log.Printf("❌ %s rejected invite from %s", username, inviterUsername)
			}
		
		case "control_revoke":
			// Session owner revokes a helper's access
			// msg.TargetUsername = helper to revoke
			if msg.TargetUsername != "" {
				// Find owner's session
				ownerSession := service.Sessions.GetSessionByUsername(username)
				if ownerSession != nil {
					if service.Sessions.RemoveHelper(ownerSession.ContainerID, msg.TargetUsername) {
						revokeMsg := LobbyMessage{
							Type:              "control_revoke",
							User:              username,                   // Owner who revoked
							TargetContainerID: ownerSession.ContainerID,
							TargetUsername:    msg.TargetUsername,         // Helper who was revoked
							Timestamp:         time.Now().Unix(),
						}
						h.broadcast(revokeMsg)
						log.Printf("🚫 %s revoked %s's control access", username, msg.TargetUsername)
					}
				}
			}
		
		case "helper_leave":
			// Helper voluntarily leaves
			// msg.TargetContainerID = the session they're helping
			if msg.TargetContainerID != "" {
				if service.Sessions.RemoveHelper(msg.TargetContainerID, username) {
					targetSession := service.Sessions.GetSession(msg.TargetContainerID)
					ownerUsername := ""
					if targetSession != nil {
						ownerUsername = targetSession.Username
					}
					
					leaveMsg := LobbyMessage{
						Type:              "helper_leave",
						User:              username,              // Helper who left
						TargetContainerID: msg.TargetContainerID,
						TargetUsername:    ownerUsername,         // Session owner
						Timestamp:         time.Now().Unix(),
					}
					h.broadcast(leaveMsg)
					log.Printf("👋 %s stopped helping %s", username, ownerUsername)
				}
			}
		
		case "owner_cancel":
			// Owner cancels pending invite or kicks all helpers
			ownerSession := service.Sessions.GetSessionByUsername(username)
			if ownerSession != nil {
				// Clear pending invite if any
				service.Sessions.ClearPendingInvite(ownerSession.ContainerID)
				
				// Remove all helpers
				service.Sessions.ClearAllHelpers(ownerSession.ContainerID)
				
				cancelMsg := LobbyMessage{
					Type:              "owner_cancel",
					User:              username,
					TargetContainerID: ownerSession.ContainerID,
					Content:           username + " 取消了邀请/结束了协助",
					Timestamp:         time.Now().Unix(),
				}
				h.broadcast(cancelMsg)
				log.Printf("🚫 %s cancelled invite/helpers", username)
			}
		}
	}

	// Unregister client
	h.mu.Lock()
	delete(h.clients, conn)
	h.mu.Unlock()

	log.Printf("👋 Lobby: %s left (%d online)", username, len(h.clients))
}

// broadcast sends message to all clients
func (h *LobbyHandler) broadcast(msg LobbyMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	// Log invite broadcasts for debugging
	if msg.Type == "invite" {
		log.Printf("📨 Broadcasting invite from %s to %s, sending to %d clients", msg.InviteFrom, msg.InviteTo, len(h.clients))
	}

	for conn, client := range h.clients {
		if err := conn.WriteJSON(msg); err != nil {
			log.Printf("Broadcast error to %s: %v", client.Username, err)
		}
	}
}

// sendSessionList sends current session list to a specific client
func (h *LobbyHandler) sendSessionList(conn *websocket.Conn) {
	sessions := service.Sessions.GetAllSessions()
	sessionInfos := make([]SessionInfo, 0, len(sessions))
	
	for _, s := range sessions {
		sessionInfos = append(sessionInfos, SessionInfo{
			ContainerID: s.ContainerID,
			Username:    s.Username,
			Name:        s.Name,
			OS:          s.OS,
			Avatar:      s.Avatar,
			Snapshot:    s.Snapshot,
			RawSnapshot: s.RawSnapshot,
			PinCount:    s.PinCount,
		})
	}
	
	// Sort by PinCount descending
	sort.Slice(sessionInfos, func(i, j int) bool {
		return sessionInfos[i].PinCount > sessionInfos[j].PinCount
	})
	
	// Assign IDs after sorting
	for i := range sessionInfos {
		sessionInfos[i].ID = i + 1
	}
	
	msg := LobbyMessage{
		Type:     "snapshots",
		Count:    len(sessions),
		Sessions: sessionInfos,
	}
	
	conn.WriteJSON(msg)
}

// sendChatHistory sends recent chat messages to a new client
func (h *LobbyHandler) sendChatHistory(conn *websocket.Conn) {
	if h.db == nil {
		return
	}
	
	messages, err := store.GetRecentMessages(h.db, 500)
	if err != nil {
		log.Printf("Failed to get chat history: %v", err)
		return
	}
	
	if len(messages) == 0 {
		return
	}
	
	history := make([]ChatHistory, 0, len(messages))
	for _, m := range messages {
		history = append(history, ChatHistory{
			User:      m.Username,
			Content:   m.Content,
			Timestamp: m.CreatedAt,
		})
	}
	
	msg := LobbyMessage{
		Type:     "history",
		Messages: history,
	}
	
	conn.WriteJSON(msg)
}
