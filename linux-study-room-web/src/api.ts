// API service for Linux Study Room backend
const API_BASE = 'https://64b1f537d0ed56f536980d2b789fc1c5fb663308-18080.dstack-pha-prod7.phala.network';
const WS_BASE = 'wss://64b1f537d0ed56f536980d2b789fc1c5fb663308-18080.dstack-pha-prod7.phala.network';

// Auth API
export const authApi = {
    // Get login URL
    getLoginUrl() {
        return `${API_BASE}/api/auth/linuxdo`;
    },

    // Get current user info from token
    async me(token: string) {
        const res = await fetch(`${API_BASE}/api/auth/me`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (!res.ok) throw new Error('Unauthorized');
        return res.json();
    }
};

// Container API
export const containerApi = {
    async check(username: string) {
        const res = await fetch(`${API_BASE}/api/container/check`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        });
        return res.json();
    },

    async launch(osType: 'alpine' | 'debian', username?: string) {
        const res = await fetch(`${API_BASE}/api/container/launch`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ os_type: osType, username: username || '' })
        });
        return res.json();
    },

    async restart(containerId: string) {
        const res = await fetch(`${API_BASE}/api/container/${containerId}/restart`, {
            method: 'POST'
        });
        return res.json();
    },

    async reset(containerId: string) {
        const res = await fetch(`${API_BASE}/api/container/${containerId}/reset`, {
            method: 'POST'
        });
        return res.json();
    },

    async status(containerId: string) {
        const res = await fetch(`${API_BASE}/api/container/${containerId}/status`);
        return res.json();
    }
};

// Leaderboard API
export const leaderboardApi = {
    async getLeaderboard() {
        const res = await fetch(`${API_BASE}/api/leaderboard`);
        return res.json();
    }
};

// Terminal WebSocket
export function createTerminalSocket(containerId: string, username: string, os: string, handlers: {
    onOpen?: () => void;
    onOutput: (data: string) => void;
    onStatus: (status: string) => void;
    onError: (error: Event) => void;
    onClose?: () => void;
}, name?: string) {
    const ws = new WebSocket(`${WS_BASE}/ws/terminal?container_id=${containerId}&username=${encodeURIComponent(username)}&os=${encodeURIComponent(os)}&name=${encodeURIComponent(name || username)}`);
    let isOpen = false;

    ws.onopen = () => {
        isOpen = true;
        handlers.onOpen?.();
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            if (msg.type === 'output') {
                handlers.onOutput(msg.data);
            } else if (msg.type === 'status') {
                handlers.onStatus(msg.data);
            }
        } catch {
            // Raw data, treat as output
            handlers.onOutput(event.data);
        }
    };

    ws.onerror = handlers.onError;
    ws.onclose = () => {
        isOpen = false;
        handlers.onClose?.();
    };

    return {
        send: (data: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'input', data }));
            }
        },
        resize: (cols: number, rows: number) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'resize', cols, rows }));
            }
        },
        close: () => ws.close(),
        isConnected: () => isOpen && ws.readyState === WebSocket.OPEN
    };
}

// Lobby WebSocket
export function createLobbySocket(username: string, os: string, handlers: {
    onOpen?: () => void;
    onUsers: (count: number, sessions: any[]) => void;
    onChat: (user: string, content: string, ts: number) => void;
    onLike?: (user: string, targetContainerId: string, targetUsername: string) => void;
    onPin?: (user: string, targetContainerId: string, targetUsername: string) => void;
    onUnpin?: (user: string, targetContainerId: string) => void;
    onHistory?: (messages: { user: string, content: string, ts: string }[]) => void;
    // Invite control callbacks
    onInvite?: (from: string, fromContainerId: string) => void;
    onInviteAccepted?: (helper: string, containerId: string) => void;
    onInviteRejected?: (helper: string) => void;
    onControlRevoked?: (owner: string) => void;
    onHelperLeft?: (helper: string) => void;
    onError: (error: Event) => void;
}) {
    const ws = new WebSocket(`${WS_BASE}/ws/lobby?username=${encodeURIComponent(username)}&os=${os}`);
    let isOpen = false;

    ws.onopen = () => {
        isOpen = true;
        handlers.onOpen?.();
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            // Handle both 'users' and 'snapshots' message types
            if (msg.type === 'users' || msg.type === 'snapshots') {
                handlers.onUsers(msg.count, msg.sessions);
            } else if (msg.type === 'chat') {
                handlers.onChat(msg.user, msg.content, msg.ts);
            } else if (msg.type === 'like') {
                handlers.onLike?.(msg.user, msg.targetContainerId, msg.targetUsername);
            } else if (msg.type === 'pin') {
                handlers.onPin?.(msg.user, msg.targetContainerId, msg.targetUsername);
            } else if (msg.type === 'unpin') {
                handlers.onUnpin?.(msg.user, msg.targetContainerId);
            } else if (msg.type === 'history') {
                handlers.onHistory?.(msg.messages || []);
            } else if (msg.type === 'invite') {
                // Only handle if we are the invitee
                console.log('📨 Invite received:', msg, 'My username:', username);
                if (msg.inviteTo === username) {
                    console.log('✅ This invite is for me, calling handler');
                    handlers.onInvite?.(msg.inviteFrom, msg.targetContainerId);
                }
            } else if (msg.type === 'invite_accept') {
                handlers.onInviteAccepted?.(msg.user, msg.targetContainerId);
            } else if (msg.type === 'invite_reject') {
                handlers.onInviteRejected?.(msg.user);
            } else if (msg.type === 'control_revoke') {
                // If we are the helper being revoked
                if (msg.targetUsername === username) {
                    handlers.onControlRevoked?.(msg.user);
                }
            } else if (msg.type === 'helper_leave') {
                handlers.onHelperLeft?.(msg.user);
            }
        } catch {
            // Ignore parse errors
        }
    };

    ws.onerror = handlers.onError;

    return {
        sendChat: (content: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'chat', content }));
            }
        },
        sendLike: (targetContainerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'like', targetContainerId }));
            }
        },
        sendPin: (targetContainerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'pin', targetContainerId }));
            }
        },
        sendUnpin: (targetContainerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'unpin', targetContainerId }));
            }
        },
        // Invite control methods
        sendInvite: (targetUsername: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'invite', inviteTo: targetUsername }));
            }
        },
        sendInviteAccept: (inviterContainerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'invite_accept', targetContainerId: inviterContainerId }));
            }
        },
        sendInviteReject: (inviterContainerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'invite_reject', targetContainerId: inviterContainerId }));
            }
        },
        sendControlRevoke: (helperUsername: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'control_revoke', targetUsername: helperUsername }));
            }
        },
        sendHelperLeave: (containerId: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'helper_leave', targetContainerId: containerId }));
            }
        },
        close: () => ws.close(),
        isConnected: () => isOpen && ws.readyState === WebSocket.OPEN
    };
}

// Health check
export async function healthCheck() {
    try {
        const res = await fetch(`${API_BASE}/health`);
        return res.ok;
    } catch {
        return false;
    }
}

// Helper Terminal WebSocket (for helpers to control someone else's terminal)
export function createHelperTerminalSocket(containerId: string, helperUsername: string, handlers: {
    onOpen?: () => void;
    onOutput: (data: string) => void;
    onStatus: (status: string) => void;
    onError: (error: Event) => void;
    onClose?: () => void;
}) {
    const ws = new WebSocket(`${WS_BASE}/ws/terminal/helper?container_id=${containerId}&username=${encodeURIComponent(helperUsername)}`);
    let isOpen = false;

    ws.onopen = () => {
        isOpen = true;
        handlers.onOpen?.();
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            if (msg.type === 'output') {
                handlers.onOutput(msg.data);
            } else if (msg.type === 'status') {
                handlers.onStatus(msg.data);
            }
        } catch {
            handlers.onOutput(event.data);
        }
    };

    ws.onerror = handlers.onError;
    ws.onclose = () => {
        isOpen = false;
        handlers.onClose?.();
    };

    return {
        send: (data: string) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'input', data }));
            }
        },
        resize: (cols: number, rows: number) => {
            if (isOpen && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'resize', cols, rows }));
            }
        },
        close: () => ws.close(),
        isConnected: () => isOpen && ws.readyState === WebSocket.OPEN
    };
}
