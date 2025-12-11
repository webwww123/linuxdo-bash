# Requirements Document

## Introduction

本功能实现用户下线后的容器自动清理机制。当用户断开WebSocket连接（下线）后，系统将在20分钟后自动清除该用户的Docker容器，以释放服务器资源。这是一个资源管理功能，确保不活跃用户的容器不会无限期占用系统资源。

## Glossary

- **Container（容器）**: 为用户创建的Docker容器实例，提供Linux终端环境
- **Session（会话）**: 用户的活跃连接状态，通过WebSocket维护
- **Cleanup Timer（清理定时器）**: 用户下线后启动的20分钟倒计时器
- **Offline（下线）**: 用户WebSocket连接断开的状态
- **Online（上线）**: 用户WebSocket连接建立的状态

## Requirements

### Requirement 1

**User Story:** As a system administrator, I want inactive user containers to be automatically cleaned up, so that server resources are not wasted on idle containers.

#### Acceptance Criteria

1. WHEN a user disconnects from the WebSocket connection THEN the System SHALL start a 20-minute cleanup timer for that user's container
2. WHEN the 20-minute cleanup timer expires AND the user has not reconnected THEN the System SHALL stop and remove the user's Docker container
3. WHEN a user reconnects within the 20-minute window THEN the System SHALL cancel the pending cleanup timer and preserve the container
4. WHEN the System removes a container THEN the System SHALL update the container status in the database to reflect the removal
5. WHEN the System removes a container THEN the System SHALL unregister the session from the SessionManager

### Requirement 2

**User Story:** As a user, I want my container to persist for a reasonable time after disconnection, so that I can reconnect and continue my work without losing my session.

#### Acceptance Criteria

1. WHILE a cleanup timer is pending for a user THEN the System SHALL allow the user to reconnect and resume their existing container
2. WHEN a user reconnects to an existing container THEN the System SHALL restore the terminal session with the previous state
3. WHEN a user has multiple browser tabs open AND one tab disconnects THEN the System SHALL only start the cleanup timer when all connections for that user are closed

### Requirement 3

**User Story:** As a developer, I want the cleanup mechanism to be reliable and observable, so that I can monitor and debug container lifecycle issues.

#### Acceptance Criteria

1. WHEN a cleanup timer is started THEN the System SHALL log the event with user identifier and scheduled cleanup time
2. WHEN a cleanup timer is cancelled due to reconnection THEN the System SHALL log the cancellation event
3. WHEN a container is removed by the cleanup process THEN the System SHALL log the removal with container identifier
4. IF the container removal fails THEN the System SHALL log the error and retry the removal operation
