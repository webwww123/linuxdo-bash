package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

const (
	linuxdoAuthorizeURL = "https://connect.linux.do/oauth2/authorize"
	linuxdoTokenURL     = "https://connect.linux.do/oauth2/token"
	linuxdoUserURL      = "https://connect.linux.do/api/user"
)

// LinuxDoUser represents user info from LinuxDo
type LinuxDoUser struct {
	ID             int    `json:"id"`
	Username       string `json:"username"`
	Name           string `json:"name"`
	AvatarTemplate string `json:"avatar_template"`
	Active         bool   `json:"active"`
	TrustLevel     int    `json:"trust_level"`
	Silenced       bool   `json:"silenced"`
}

// AuthHandler handles OAuth2 authentication
type AuthHandler struct {
	clientID     string
	clientSecret string
	callbackURL  string
	jwtSecret    []byte
	frontendURL  string
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		clientID:     os.Getenv("LINUXDO_CLIENT_ID"),
		clientSecret: os.Getenv("LINUXDO_CLIENT_SECRET"),
		callbackURL:  os.Getenv("LINUXDO_CALLBACK_URL"),
		jwtSecret:    []byte(os.Getenv("JWT_SECRET")),
		frontendURL:  getEnvOrDefault("FRONTEND_URL", "http://localhost:5173"),
	}
}

func getEnvOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

// Login redirects to LinuxDo authorization page
func (h *AuthHandler) Login(c *gin.Context) {
	if h.clientID == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "LinuxDo OAuth not configured"})
		return
	}

	// Build authorization URL
	params := url.Values{}
	params.Set("client_id", h.clientID)
	params.Set("response_type", "code")
	params.Set("redirect_uri", h.callbackURL)
	params.Set("scope", "read")

	authURL := linuxdoAuthorizeURL + "?" + params.Encode()
	c.Redirect(http.StatusTemporaryRedirect, authURL)
}

// Callback handles OAuth2 callback
func (h *AuthHandler) Callback(c *gin.Context) {
	code := c.Query("code")
	if code == "" {
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=no_code")
		return
	}

	// Exchange code for token
	tokenData := url.Values{}
	tokenData.Set("grant_type", "authorization_code")
	tokenData.Set("code", code)
	tokenData.Set("redirect_uri", h.callbackURL)
	tokenData.Set("client_id", h.clientID)
	tokenData.Set("client_secret", h.clientSecret)

	resp, err := http.Post(linuxdoTokenURL, "application/x-www-form-urlencoded", strings.NewReader(tokenData.Encode()))
	if err != nil {
		log.Printf("Token exchange failed: %v", err)
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=token_failed")
		return
	}
	defer resp.Body.Close()

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		log.Printf("Token decode failed: %v", err)
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=token_decode_failed")
		return
	}

	if tokenResp.AccessToken == "" {
		log.Printf("No access token received")
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=no_token")
		return
	}

	// Get user info
	userReq, _ := http.NewRequest("GET", linuxdoUserURL, nil)
	userReq.Header.Set("Authorization", "Bearer "+tokenResp.AccessToken)

	client := &http.Client{Timeout: 10 * time.Second}
	userResp, err := client.Do(userReq)
	if err != nil {
		log.Printf("User info request failed: %v", err)
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=user_failed")
		return
	}
	defer userResp.Body.Close()

	var user LinuxDoUser
	if err := json.NewDecoder(userResp.Body).Decode(&user); err != nil {
		log.Printf("User info decode failed: %v", err)
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=user_decode_failed")
		return
	}

	log.Printf("✅ LinuxDo user logged in: %s (ID: %d, TL: %d)", user.Username, user.ID, user.TrustLevel)

	// Generate JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":          user.ID,
		"username":    user.Username,
		"name":        user.Name,
		"avatar":      user.AvatarTemplate,
		"trust_level": user.TrustLevel,
		"exp":         time.Now().Add(7 * 24 * time.Hour).Unix(),
	})

	tokenString, err := token.SignedString(h.jwtSecret)
	if err != nil {
		log.Printf("JWT sign failed: %v", err)
		c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?error=jwt_failed")
		return
	}

	// Redirect to frontend with token
	c.Redirect(http.StatusTemporaryRedirect, h.frontendURL+"?token="+tokenString)
}

// Me returns current user info from JWT token
func (h *AuthHandler) Me(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No token provided"})
		return
	}

	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return h.jwtSecret, nil
	})

	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid claims"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":          claims["id"],
		"username":    claims["username"],
		"name":        claims["name"],
		"avatar":      claims["avatar"],
		"trust_level": claims["trust_level"],
	})
}
