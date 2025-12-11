# Implementation Plan

- [x] 1. Create CleanupManager service


  - [x] 1.1 Create cleanup manager struct and constructor


    - Create `internal/service/cleanup.go` file
    - Define `CleanupManager` struct with timers map, connection count map, mutex
    - Implement `NewCleanupManager` constructor
    - _Requirements: 1.1, 2.3_
  - [x] 1.2 Implement connection tracking methods

    - Implement `OnConnect` method to increment connection count and cancel pending timer
    - Implement `OnDisconnect` method to decrement count and start timer when count reaches zero
    - Implement `GetConnectionCount` and `HasPendingCleanup` helper methods
    - _Requirements: 1.1, 1.3, 2.1, 2.3_
  - [x] 1.3 Write property test for connection counting


    - **Property 5: Multi-Connection Handling**
    - **Validates: Requirements 2.3**
  - [x] 1.4 Implement cleanup execution logic

    - Implement private `executeCleanup` method
    - Stop container using DockerService
    - Remove container using DockerService
    - Update database status to "removed"
    - Unregister session from SessionManager
    - Add retry logic for failures
    - _Requirements: 1.2, 1.4, 1.5, 3.4_

  - [x] 1.5 Write property test for timer start on disconnect

    - **Property 1: Timer Start on Disconnect**
    - **Validates: Requirements 1.1**
  - [x] 1.6 Write property test for cleanup execution


    - **Property 2: Container Cleanup on Timer Expiry**

    - **Validates: Requirements 1.2**

  - [x] 1.7 Write property test for timer cancellation

    - **Property 3: Timer Cancellation on Reconnect**
    - **Validates: Requirements 1.3**

- [x] 2. Integrate CleanupManager with TerminalHandler



  - [x] 2.1 Update TerminalHandler struct

    - Add `cleanupMgr` field to `TerminalHandler` struct
    - Update `NewTerminalHandler` to accept CleanupManager parameter
    - _Requirements: 1.1_
  - [x] 2.2 Add connection lifecycle hooks


    - Call `cleanupMgr.OnConnect` when WebSocket connection is established
    - Call `cleanupMgr.OnDisconnect` when WebSocket connection closes
    - _Requirements: 1.1, 1.3_
  - [x] 2.3 Write property test for cleanup side effects


    - **Property 4: Cleanup Side Effects Consistency**
    - **Validates: Requirements 1.4, 1.5**

- [x] 3. Update application initialization


  - [x] 3.1 Update main.go to initialize CleanupManager


    - Create CleanupManager instance in main.go
    - Pass CleanupManager to TerminalHandler
    - _Requirements: 1.1_

- [x] 4. Add database helper for status update


  - [x] 4.1 Add UpdateContainerStatusByDockerID function


    - Add function to update container status by docker_id
    - _Requirements: 1.4_


- [x] 5. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Write property test for retry logic


  - [x] 6.1 Write property test for retry on failure


    - **Property 6: Retry on Cleanup Failure**
    - **Validates: Requirements 3.4**

- [x] 7. Final Checkpoint - Ensure all tests pass



  - Ensure all tests pass, ask the user if questions arise.
