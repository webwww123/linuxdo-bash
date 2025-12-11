package handler

import (
	"database/sql"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/linuxstudyroom/backend/internal/store"
)

// LeaderboardHandler handles leaderboard API requests
type LeaderboardHandler struct {
	db *sql.DB
}

// NewLeaderboardHandler creates a new leaderboard handler
func NewLeaderboardHandler(db *sql.DB) *LeaderboardHandler {
	return &LeaderboardHandler{db: db}
}

// LeaderboardEntry represents a single entry in the leaderboard
type LeaderboardEntry struct {
	Rank         int    `json:"rank"`
	Username     string `json:"username"`
	Avatar       string `json:"avatar"`
	TotalSeconds int64  `json:"totalSeconds"`
	FormattedTime string `json:"formattedTime"`
}

// formatDuration formats seconds into a human-readable string
func formatDuration(seconds int64) string {
	hours := seconds / 3600
	minutes := (seconds % 3600) / 60
	
	if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}

// GetLeaderboard returns the top 10 users by online time
func (h *LeaderboardHandler) GetLeaderboard(c *gin.Context) {
	users, err := store.GetOnlineLeaderboard(h.db, 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get leaderboard"})
		return
	}

	entries := make([]LeaderboardEntry, 0, len(users))
	for i, u := range users {
		entries = append(entries, LeaderboardEntry{
			Rank:          i + 1,
			Username:      u.Username,
			Avatar:        u.Avatar,
			TotalSeconds:  u.TotalSeconds,
			FormattedTime: formatDuration(u.TotalSeconds),
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"title":       "Linux 之王",
		"description": "在线时长排行榜",
		"entries":     entries,
	})
}
