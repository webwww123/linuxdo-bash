package main

import (
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/linuxstudyroom/backend/internal/handler"
	"github.com/linuxstudyroom/backend/internal/service"
	"github.com/linuxstudyroom/backend/internal/store"
)

func main() {
	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Initialize SQLite
	db, err := store.InitDB(getEnv("DB_PATH", "./data/study_room.db"))
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// Initialize Docker service
	dockerSvc, err := service.NewDockerService()
	if err != nil {
		log.Fatalf("Failed to connect to Docker: %v", err)
	}

	// Initialize Cleanup Manager (handles container cleanup after user disconnects)
	// TODO: 暂时禁用，后续可能启用
	// cleanupMgr := service.NewCleanupManager(dockerSvc, db)
	// log.Println("✅ Cleanup manager initialized (20 min timeout)")

	// Clean up stale containers from previous sessions
	// cleanupMgr.CleanupStaleContainers()

	// Initialize Gin
	r := gin.Default()

	// CORS configuration - Allow all origins for open source deployment
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: false,
	}))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "linux-study-room"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Container management
		containerHandler := handler.NewContainerHandler(dockerSvc, db)
		api.POST("/container/check", containerHandler.Check)
		api.POST("/container/launch", containerHandler.Launch)
		api.POST("/container/:id/restart", containerHandler.Restart)
		api.POST("/container/:id/reset", containerHandler.Reset)
		api.GET("/container/:id/status", containerHandler.Status)

		// Leaderboard
		leaderboardHandler := handler.NewLeaderboardHandler(db)
		api.GET("/leaderboard", leaderboardHandler.GetLeaderboard)

		// OAuth2 Authentication
		authHandler := handler.NewAuthHandler()
		api.GET("/auth/linuxdo", authHandler.Login)
		api.GET("/auth/linuxdo/callback", authHandler.Callback)
		api.GET("/auth/me", authHandler.Me)
	}

	// WebSocket routes
	ws := r.Group("/ws")
	{
		// TODO: 暂时禁用cleanupMgr，传nil
		terminalHandler := handler.NewTerminalHandler(dockerSvc, nil, db)
		ws.GET("/terminal", terminalHandler.Handle)
		ws.GET("/terminal/helper", terminalHandler.HandleHelper) // Helper terminal

		lobbyHandler := handler.NewLobbyHandler(db)
		ws.GET("/lobby", lobbyHandler.Handle)
	}

	// Start server
	port := getEnv("PORT", "8080")
	log.Printf("🚀 Linux Study Room Backend starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
