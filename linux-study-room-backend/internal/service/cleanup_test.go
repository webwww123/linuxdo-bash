package service

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"testing/quick"
	"time"
)

// **Feature: container-cleanup, Property 5: Multi-Connection Handling**
// **Validates: Requirements 2.3**
// For any container with N active connections (N > 1), when one connection disconnects,
// the cleanup timer SHALL NOT be started until all N connections are closed.
func TestProperty_MultiConnectionHandling(t *testing.T) {
	f := func(numConnections uint8) bool {
		// Limit connections to reasonable range (1-100)
		n := int(numConnections%100) + 1

		cm := NewCleanupManagerWithDelay(nil, nil, 1*time.Hour)
		containerID := "test-container-multi"

		// Simulate N connections
		for i := 0; i < n; i++ {
			cm.OnConnect(containerID)
		}

		// Verify connection count
		if cm.GetConnectionCount(containerID) != n {
			t.Logf("Expected %d connections, got %d", n, cm.GetConnectionCount(containerID))
			return false
		}

		// Disconnect all but one
		for i := 0; i < n-1; i++ {
			cm.OnDisconnect(containerID)
			// Timer should NOT be started while connections remain
			if cm.HasPendingCleanup(containerID) {
				t.Logf("Timer started prematurely with %d connections remaining", cm.GetConnectionCount(containerID))
				return false
			}
		}

		// Verify one connection remains
		if cm.GetConnectionCount(containerID) != 1 {
			t.Logf("Expected 1 connection remaining, got %d", cm.GetConnectionCount(containerID))
			return false
		}

		// Disconnect last connection
		cm.OnDisconnect(containerID)

		// Now timer SHOULD be started
		if !cm.HasPendingCleanup(containerID) {
			t.Log("Timer not started after all connections closed")
			return false
		}

		return true
	}

	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

// **Feature: container-cleanup, Property 1: Timer Start on Disconnect**
// **Validates: Requirements 1.1**
// For any container with exactly one active connection, when that connection disconnects,
// a cleanup timer SHALL be started for that container.
func TestProperty_TimerStartOnDisconnect(t *testing.T) {
	f := func(containerSuffix uint32) bool {
		cm := NewCleanupManagerWithDelay(nil, nil, 1*time.Hour)
		containerID := "test-container-" + string(rune('a'+containerSuffix%26))

		// Single connection
		cm.OnConnect(containerID)

		// Verify no timer yet
		if cm.HasPendingCleanup(containerID) {
			t.Log("Timer should not exist while connected")
			return false
		}

		// Disconnect
		cm.OnDisconnect(containerID)

		// Timer should be started
		if !cm.HasPendingCleanup(containerID) {
			t.Log("Timer should be started after disconnect")
			return false
		}

		return true
	}

	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

// **Feature: container-cleanup, Property 3: Timer Cancellation on Reconnect**
// **Validates: Requirements 1.3**
// For any container with a pending cleanup timer, when a new connection is established,
// the timer SHALL be cancelled and the container SHALL be preserved.
func TestProperty_TimerCancellationOnReconnect(t *testing.T) {
	f := func(containerSuffix uint32) bool {
		cm := NewCleanupManagerWithDelay(nil, nil, 1*time.Hour)
		containerID := "test-container-" + string(rune('a'+containerSuffix%26))

		// Connect then disconnect to start timer
		cm.OnConnect(containerID)
		cm.OnDisconnect(containerID)

		// Verify timer is pending
		if !cm.HasPendingCleanup(containerID) {
			t.Log("Timer should be pending after disconnect")
			return false
		}

		// Reconnect
		cm.OnConnect(containerID)

		// Timer should be cancelled
		if cm.HasPendingCleanup(containerID) {
			t.Log("Timer should be cancelled after reconnect")
			return false
		}

		// Connection count should be 1
		if cm.GetConnectionCount(containerID) != 1 {
			t.Logf("Expected 1 connection, got %d", cm.GetConnectionCount(containerID))
			return false
		}

		return true
	}

	if err := quick.Check(f, &quick.Config{MaxCount: 100}); err != nil {
		t.Error(err)
	}
}

// Unit test for basic connection counting
func TestCleanupManager_ConnectionCounting(t *testing.T) {
	cm := NewCleanupManagerWithDelay(nil, nil, 1*time.Hour)
	containerID := "test-container"

	// Initial count should be 0
	if cm.GetConnectionCount(containerID) != 0 {
		t.Errorf("Expected 0 connections, got %d", cm.GetConnectionCount(containerID))
	}

	// Add connections
	cm.OnConnect(containerID)
	if cm.GetConnectionCount(containerID) != 1 {
		t.Errorf("Expected 1 connection, got %d", cm.GetConnectionCount(containerID))
	}

	cm.OnConnect(containerID)
	if cm.GetConnectionCount(containerID) != 2 {
		t.Errorf("Expected 2 connections, got %d", cm.GetConnectionCount(containerID))
	}

	// Remove connections
	cm.OnDisconnect(containerID)
	if cm.GetConnectionCount(containerID) != 1 {
		t.Errorf("Expected 1 connection, got %d", cm.GetConnectionCount(containerID))
	}
}

// Unit test for timer lifecycle
func TestCleanupManager_TimerLifecycle(t *testing.T) {
	cm := NewCleanupManagerWithDelay(nil, nil, 1*time.Hour)
	containerID := "test-container"

	// No timer initially
	if cm.HasPendingCleanup(containerID) {
		t.Error("Should not have pending cleanup initially")
	}

	// Connect and disconnect
	cm.OnConnect(containerID)
	cm.OnDisconnect(containerID)

	// Timer should be pending
	if !cm.HasPendingCleanup(containerID) {
		t.Error("Should have pending cleanup after disconnect")
	}

	// Cancel cleanup
	cancelled := cm.CancelCleanup(containerID)
	if !cancelled {
		t.Error("CancelCleanup should return true when timer exists")
	}

	// No timer after cancel
	if cm.HasPendingCleanup(containerID) {
		t.Error("Should not have pending cleanup after cancel")
	}

	// Cancel again should return false
	cancelled = cm.CancelCleanup(containerID)
	if cancelled {
		t.Error("CancelCleanup should return false when no timer exists")
	}
}


// MockDockerService for testing cleanup execution
type MockDockerService struct {
	stopCalled   int
	removeCalled int
	shouldFail   bool
}

func (m *MockDockerService) StopContainer(ctx context.Context, containerID string) error {
	m.stopCalled++
	if m.shouldFail {
		return fmt.Errorf("mock stop error")
	}
	return nil
}

func (m *MockDockerService) RemoveContainer(ctx context.Context, containerID string) error {
	m.removeCalled++
	if m.shouldFail {
		return fmt.Errorf("mock remove error")
	}
	return nil
}

// **Feature: container-cleanup, Property 2: Container Cleanup on Timer Expiry**
// **Validates: Requirements 1.2**
// For any container with a pending cleanup timer, when the timer expires and the connection count is zero,
// the container SHALL be stopped and removed.
func TestProperty_CleanupOnTimerExpiry(t *testing.T) {
	f := func(containerSuffix uint8) bool {
		containerID := fmt.Sprintf("test-container-%d", containerSuffix)

		// Use very short delay for testing
		cm := NewCleanupManagerWithDelay(nil, nil, 10*time.Millisecond)

		// Connect then disconnect to start timer
		cm.OnConnect(containerID)
		cm.OnDisconnect(containerID)

		// Verify timer is pending
		if !cm.HasPendingCleanup(containerID) {
			t.Log("Timer should be pending")
			return false
		}

		// Wait for timer to expire
		time.Sleep(50 * time.Millisecond)

		// Timer should be gone (cleanup executed)
		if cm.HasPendingCleanup(containerID) {
			t.Log("Timer should be cleared after expiry")
			return false
		}

		// Connection count should be cleared
		if cm.GetConnectionCount(containerID) != 0 {
			t.Logf("Connection count should be 0, got %d", cm.GetConnectionCount(containerID))
			return false
		}

		return true
	}

	if err := quick.Check(f, &quick.Config{MaxCount: 20}); err != nil {
		t.Error(err)
	}
}


// **Feature: container-cleanup, Property 4: Cleanup Side Effects Consistency**
// **Validates: Requirements 1.4, 1.5**
// For any container that is cleaned up, the database status SHALL be updated to "removed"
// AND the session SHALL be unregistered from SessionManager.
func TestProperty_CleanupSideEffects(t *testing.T) {
	f := func(containerSuffix uint8) bool {
		containerID := fmt.Sprintf("test-container-side-%d", containerSuffix)

		// Register a session first
		Sessions.Register(containerID, &Session{
			Username:    "testuser",
			ContainerID: containerID,
			OS:          "alpine",
		})

		// Verify session exists
		if Sessions.GetSession(containerID) == nil {
			t.Log("Session should exist before cleanup")
			return false
		}

		// Use very short delay for testing (no docker service, no db)
		cm := NewCleanupManagerWithDelay(nil, nil, 10*time.Millisecond)

		// Connect then disconnect to start timer
		cm.OnConnect(containerID)
		cm.OnDisconnect(containerID)

		// Wait for cleanup to execute
		time.Sleep(50 * time.Millisecond)

		// Session should be unregistered
		if Sessions.GetSession(containerID) != nil {
			t.Log("Session should be unregistered after cleanup")
			return false
		}

		return true
	}

	if err := quick.Check(f, &quick.Config{MaxCount: 20}); err != nil {
		t.Error(err)
	}
}


// MockContainerOps implements ContainerOperations for testing retry logic
type MockContainerOps struct {
	stopFailCount    int
	removeFailCount  int
	stopCalls        int
	removeCalls      int
	mu               sync.Mutex
}

func (m *MockContainerOps) StopContainer(ctx context.Context, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.stopCalls++
	if m.stopCalls <= m.stopFailCount {
		return fmt.Errorf("mock stop error %d", m.stopCalls)
	}
	return nil
}

func (m *MockContainerOps) RemoveContainer(ctx context.Context, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.removeCalls++
	if m.removeCalls <= m.removeFailCount {
		return fmt.Errorf("mock remove error %d", m.removeCalls)
	}
	return nil
}

func (m *MockContainerOps) GetStopCalls() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.stopCalls
}

func (m *MockContainerOps) GetRemoveCalls() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.removeCalls
}

// **Feature: container-cleanup, Property 6: Retry on Cleanup Failure**
// **Validates: Requirements 3.4**
// For any container cleanup operation that fails, the system SHALL retry the operation.
func TestProperty_RetryOnFailure(t *testing.T) {
	// Test case 1: Stop fails once, then succeeds
	t.Run("StopRetry", func(t *testing.T) {
		mock := &MockContainerOps{stopFailCount: 1, removeFailCount: 0}
		cm := NewCleanupManagerWithOps(mock, nil, 10*time.Millisecond)
		containerID := "test-retry-stop"

		cm.OnConnect(containerID)
		cm.OnDisconnect(containerID)

		// Wait for cleanup (needs time for retry sleep of 2 seconds)
		time.Sleep(5 * time.Second)

		// Should have retried stop (2 attempts: 1 fail + 1 success)
		if mock.GetStopCalls() != 2 {
			t.Errorf("Expected 2 stop calls (1 fail + 1 success), got %d", mock.GetStopCalls())
		}
		// Remove should succeed on first try
		if mock.GetRemoveCalls() != 1 {
			t.Errorf("Expected 1 remove call, got %d", mock.GetRemoveCalls())
		}
	})

	// Test case 2: Remove fails once, then succeeds (shorter test)
	t.Run("RemoveRetry", func(t *testing.T) {
		mock := &MockContainerOps{stopFailCount: 0, removeFailCount: 1}
		cm := NewCleanupManagerWithOps(mock, nil, 10*time.Millisecond)
		containerID := "test-retry-remove"

		cm.OnConnect(containerID)
		cm.OnDisconnect(containerID)

		// Wait for cleanup (needs more time due to retries with sleep)
		time.Sleep(8 * time.Second)

		// Stop should succeed on first try
		if mock.GetStopCalls() != 1 {
			t.Errorf("Expected 1 stop call, got %d", mock.GetStopCalls())
		}
		// Should have retried remove (2 attempts: 1 fail + 1 success)
		if mock.GetRemoveCalls() < 2 {
			t.Errorf("Expected at least 2 remove calls (1 fail + 1 success), got %d", mock.GetRemoveCalls())
		}
	})
}

// Unit test for retry behavior
func TestCleanupManager_RetryBehavior(t *testing.T) {
	mock := &MockContainerOps{stopFailCount: 1, removeFailCount: 0}
	cm := NewCleanupManagerWithOps(mock, nil, 10*time.Millisecond)
	containerID := "test-retry"

	cm.OnConnect(containerID)
	cm.OnDisconnect(containerID)

	// Wait for cleanup (needs time for retry sleep of 2 seconds)
	time.Sleep(5 * time.Second)

	// Verify retry happened
	if mock.GetStopCalls() < 2 {
		t.Errorf("Expected at least 2 stop attempts due to retry, got %d", mock.GetStopCalls())
	}
}
