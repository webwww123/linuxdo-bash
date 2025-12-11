package service

import (
	"log"
	"regexp"
	"sync"
)

// ANSI escape sequence regex - comprehensive pattern for terminal control codes
var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[()][AB012]|\x1b[=>]|\x1b\[[\?]?[0-9;]*[hlm]|\r`)

// SessionManager manages active user sessions and their terminal snapshots
type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]*Session
}

// Session represents an active user session
type Session struct {
	Username      string
	Name          string   // Display name (nickname)
	ContainerID   string
	OS            string
	Avatar        string
	Snapshot      string   // Cleaned text for fallback display
	RawSnapshot   string   // Raw terminal output with ANSI codes for xterm.js
	PinCount      int      // Number of users who pinned this session
	PinnedBy      []string // List of usernames who pinned this session
	Helpers       []string // List of usernames who can control this session
	PendingInvite string   // Username of pending invite recipient
}

// Global session manager instance
var Sessions = &SessionManager{
	sessions: make(map[string]*Session),
}

// Register adds or updates a session
func (sm *SessionManager) Register(containerID string, session *Session) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.sessions[containerID] = session
	log.Printf("📝 Session registered: %s (%s) - total: %d", session.Username, containerID[:12], len(sm.sessions))
}

// Unregister removes a session
func (sm *SessionManager) Unregister(containerID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[containerID]; ok {
		log.Printf("🗑️ Session unregistered: %s (%s) - remaining: %d", s.Username, containerID[:12], len(sm.sessions)-1)
	}
	delete(sm.sessions, containerID)
}

// StripANSI removes ANSI escape sequences and control characters from text
func StripANSI(s string) string {
	var result []byte
	i := 0
	
	for i < len(s) {
		c := s[i]
		
		// ESC character - start of escape sequence
		if c == 0x1b {
			i++
			if i >= len(s) {
				break
			}
			
			nextChar := s[i]
			
			// CSI sequence: ESC [
			if nextChar == '[' {
				i++
				// Skip until we hit a letter (end of CSI)
				for i < len(s) {
					if (s[i] >= 'a' && s[i] <= 'z') || (s[i] >= 'A' && s[i] <= 'Z') {
						i++
						break
					}
					i++
				}
				continue
			}
			
			// OSC sequence: ESC ]
			if nextChar == ']' {
				i++
				// Skip until BEL (0x07) or ST (ESC \)
				for i < len(s) {
					if s[i] == 0x07 {
						i++
						break
					}
					if s[i] == 0x1b && i+1 < len(s) && s[i+1] == '\\' {
						i += 2
						break
					}
					i++
				}
				continue
			}
			
			// Character set switching: ESC ( X or ESC ) X (3 bytes total)
			if nextChar == '(' || nextChar == ')' {
				i += 2  // Skip ESC, (, and the character set designator
				continue
			}
			
			// Other escape sequences (single char after ESC)
			i++
			continue
		}
		
		// Skip control characters (0-31) except newline (10)
		if c < 32 && c != '\n' {
			i++
			continue
		}
		
		// Skip DEL and high bytes
		if c >= 127 {
			i++
			continue
		}
		
		// Keep printable ASCII and newline
		result = append(result, c)
		i++
	}
	
	return string(result)
}

// UpdateSnapshot updates the terminal snapshot for a container
func (sm *SessionManager) UpdateSnapshot(containerID, rawSnapshot, cleanedSnapshot string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[containerID]; ok {
		s.RawSnapshot = rawSnapshot
		s.Snapshot = cleanedSnapshot
	}
}

// GetAllSessions returns all active sessions
func (sm *SessionManager) GetAllSessions() []*Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	result := make([]*Session, 0, len(sm.sessions))
	for _, s := range sm.sessions {
		result = append(result, s)
	}
	return result
}

// GetSession returns a specific session
func (sm *SessionManager) GetSession(containerID string) *Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.sessions[containerID]
}

// PinSession adds a pin from a user to a session
func (sm *SessionManager) PinSession(containerID, username string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	// Check if already pinned by this user
	for _, u := range s.PinnedBy {
		if u == username {
			return false // Already pinned
		}
	}
	s.PinnedBy = append(s.PinnedBy, username)
	s.PinCount = len(s.PinnedBy)
	return true
}

// UnpinSession removes a pin from a user to a session
func (sm *SessionManager) UnpinSession(containerID, username string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	// Find and remove the user from PinnedBy
	for i, u := range s.PinnedBy {
		if u == username {
			s.PinnedBy = append(s.PinnedBy[:i], s.PinnedBy[i+1:]...)
			s.PinCount = len(s.PinnedBy)
			return true
		}
	}
	return false // Not pinned
}

// AddHelper adds a helper to a session
func (sm *SessionManager) AddHelper(containerID, helperUsername string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	// Check if already a helper
	for _, h := range s.Helpers {
		if h == helperUsername {
			return false
		}
	}
	s.Helpers = append(s.Helpers, helperUsername)
	s.PendingInvite = "" // Clear pending invite
	return true
}

// RemoveHelper removes a helper from a session
func (sm *SessionManager) RemoveHelper(containerID, helperUsername string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	for i, h := range s.Helpers {
		if h == helperUsername {
			s.Helpers = append(s.Helpers[:i], s.Helpers[i+1:]...)
			return true
		}
	}
	return false
}

// IsHelper checks if a user is a helper for a session
func (sm *SessionManager) IsHelper(containerID, username string) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	for _, h := range s.Helpers {
		if h == username {
			return true
		}
	}
	return false
}

// SetPendingInvite sets a pending invite for a session
func (sm *SessionManager) SetPendingInvite(containerID, inviteeUsername string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.sessions[containerID]
	if !ok {
		return false
	}
	s.PendingInvite = inviteeUsername
	return true
}

// ClearPendingInvite clears the pending invite
func (sm *SessionManager) ClearPendingInvite(containerID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[containerID]; ok {
		s.PendingInvite = ""
	}
}

// GetSessionByUsername finds a session by username
func (sm *SessionManager) GetSessionByUsername(username string) *Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	for _, s := range sm.sessions {
		if s.Username == username {
			return s
		}
	}
	return nil
}

// GetContainerByHelper finds the container ID that a helper is helping
func (sm *SessionManager) GetContainerByHelper(helperUsername string) string {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	for _, s := range sm.sessions {
		for _, h := range s.Helpers {
			if h == helperUsername {
				return s.ContainerID
			}
		}
	}
	return ""
}

// ClearAllHelpers removes all helpers from a session
func (sm *SessionManager) ClearAllHelpers(containerID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	if s, ok := sm.sessions[containerID]; ok {
		s.Helpers = nil
	}
}
