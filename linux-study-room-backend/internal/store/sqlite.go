package store

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

// InitDB initializes SQLite database with schema
func InitDB(dbPath string) (*sql.DB, error) {
	// Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	// Create tables
	schema := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		linuxdo_id TEXT UNIQUE,
		username TEXT NOT NULL,
		avatar TEXT,
		trust_level INTEGER DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		last_seen DATETIME
	);

	CREATE TABLE IF NOT EXISTS containers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		docker_id TEXT,
		os_type TEXT NOT NULL,
		status TEXT DEFAULT 'stopped',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		last_active DATETIME,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);

	CREATE TABLE IF NOT EXISTS chat_messages (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER,
		username TEXT NOT NULL,
		avatar TEXT,
		content TEXT NOT NULL,
		content_type TEXT DEFAULT 'text',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);

	CREATE TABLE IF NOT EXISTS user_online_time (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		avatar TEXT,
		total_seconds INTEGER DEFAULT 0,
		last_connect DATETIME,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`

	if _, err := db.Exec(schema); err != nil {
		return nil, err
	}

	log.Printf("✅ Database initialized at %s", dbPath)
	return db, nil
}

// User represents a user in the database
type User struct {
	ID         int64
	LinuxDoID  string
	Username   string
	Avatar     string
	TrustLevel int
}

// Container represents a user's container
type Container struct {
	ID       int64
	UserID   int64
	DockerID string
	OSType   string
	Status   string
}

// CreateUser inserts a new user
func CreateUser(db *sql.DB, user *User) error {
	result, err := db.Exec(
		"INSERT INTO users (linuxdo_id, username, avatar, trust_level) VALUES (?, ?, ?, ?)",
		user.LinuxDoID, user.Username, user.Avatar, user.TrustLevel,
	)
	if err != nil {
		return err
	}
	user.ID, _ = result.LastInsertId()
	return nil
}

// GetUserByLinuxDoID finds user by LinuxDo ID
func GetUserByLinuxDoID(db *sql.DB, linuxdoID string) (*User, error) {
	user := &User{}
	err := db.QueryRow(
		"SELECT id, linuxdo_id, username, avatar, trust_level FROM users WHERE linuxdo_id = ?",
		linuxdoID,
	).Scan(&user.ID, &user.LinuxDoID, &user.Username, &user.Avatar, &user.TrustLevel)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetContainerByUserID finds container by user ID
func GetContainerByUserID(db *sql.DB, userID int64) (*Container, error) {
	container := &Container{}
	err := db.QueryRow(
		"SELECT id, user_id, docker_id, os_type, status FROM containers WHERE user_id = ?",
		userID,
	).Scan(&container.ID, &container.UserID, &container.DockerID, &container.OSType, &container.Status)
	if err != nil {
		return nil, err
	}
	return container, nil
}

// CreateContainer inserts a new container record
func CreateContainer(db *sql.DB, container *Container) error {
	result, err := db.Exec(
		"INSERT INTO containers (user_id, docker_id, os_type, status) VALUES (?, ?, ?, ?)",
		container.UserID, container.DockerID, container.OSType, container.Status,
	)
	if err != nil {
		return err
	}
	container.ID, _ = result.LastInsertId()
	return nil
}

// UpdateContainerStatus updates container status
func UpdateContainerStatus(db *sql.DB, id int64, status, dockerID string) error {
	_, err := db.Exec(
		"UPDATE containers SET status = ?, docker_id = ?, last_active = CURRENT_TIMESTAMP WHERE id = ?",
		status, dockerID, id,
	)
	return err
}


// UpdateContainerStatusByDockerID updates container status by docker_id
func UpdateContainerStatusByDockerID(db *sql.DB, dockerID, status string) error {
	_, err := db.Exec(
		"UPDATE containers SET status = ?, last_active = CURRENT_TIMESTAMP WHERE docker_id = ?",
		status, dockerID,
	)
	return err
}

// ChatMessage represents a chat message
type ChatMessage struct {
	ID          int64
	Username    string
	Avatar      string
	Content     string
	ContentType string
	CreatedAt   string
}

// SaveChatMessage saves a chat message to the database
func SaveChatMessage(db *sql.DB, username, avatar, content, contentType string) error {
	_, err := db.Exec(
		"INSERT INTO chat_messages (username, avatar, content, content_type) VALUES (?, ?, ?, ?)",
		username, avatar, content, contentType,
	)
	return err
}

// GetRecentMessages retrieves the most recent messages
func GetRecentMessages(db *sql.DB, limit int) ([]ChatMessage, error) {
	rows, err := db.Query(
		"SELECT id, username, avatar, content, content_type, created_at FROM chat_messages ORDER BY id DESC LIMIT ?",
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []ChatMessage
	for rows.Next() {
		var msg ChatMessage
		var avatar sql.NullString
		if err := rows.Scan(&msg.ID, &msg.Username, &avatar, &msg.Content, &msg.ContentType, &msg.CreatedAt); err != nil {
			continue
		}
		if avatar.Valid {
			msg.Avatar = avatar.String
		}
		messages = append(messages, msg)
	}

	// Reverse to get chronological order
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

// UserOnlineTime represents a user's online time record
type UserOnlineTime struct {
	ID           int64
	Username     string
	Avatar       string
	TotalSeconds int64
}

// RecordConnect records when a user connects
func RecordConnect(db *sql.DB, username, avatar string) error {
	_, err := db.Exec(`
		INSERT INTO user_online_time (username, avatar, last_connect, updated_at) 
		VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		ON CONFLICT(username) DO UPDATE SET 
			avatar = excluded.avatar,
			last_connect = CURRENT_TIMESTAMP,
			updated_at = CURRENT_TIMESTAMP
	`, username, avatar)
	return err
}

// RecordDisconnect calculates and adds online time when user disconnects
func RecordDisconnect(db *sql.DB, username string) error {
	_, err := db.Exec(`
		UPDATE user_online_time 
		SET total_seconds = total_seconds + CAST((julianday(CURRENT_TIMESTAMP) - julianday(last_connect)) * 86400 AS INTEGER),
			updated_at = CURRENT_TIMESTAMP
		WHERE username = ? AND last_connect IS NOT NULL
	`, username)
	return err
}

// GetOnlineLeaderboard returns top users by online time
func GetOnlineLeaderboard(db *sql.DB, limit int) ([]UserOnlineTime, error) {
	rows, err := db.Query(
		"SELECT id, username, avatar, total_seconds FROM user_online_time ORDER BY total_seconds DESC LIMIT ?",
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var leaderboard []UserOnlineTime
	for rows.Next() {
		var user UserOnlineTime
		var avatar sql.NullString
		if err := rows.Scan(&user.ID, &user.Username, &avatar, &user.TotalSeconds); err != nil {
			continue
		}
		if avatar.Valid {
			user.Avatar = avatar.String
		}
		leaderboard = append(leaderboard, user)
	}

	return leaderboard, nil
}
