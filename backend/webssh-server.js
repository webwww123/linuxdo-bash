const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { io: ioClient } = require('socket.io-client');
const pty = require('node-pty');
const path = require('path');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  path: '/webssh/socket.io',   // 自定义路径，避免与主API冲突
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// 中间件
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// 存储终端会话
const terminals = {};
const userTerminals = {}; // 存储用户名到终端的映射

// 连接到主API服务器，用于广播终端输出
const mainServerSocket = ioClient('http://backend:3001');

mainServerSocket.on('connect', () => {
  console.log('WebSSH服务器已连接到主API服务器');
});

mainServerSocket.on('disconnect', () => {
  console.log('WebSSH服务器与主API服务器断开连接');
});

// 提供简单的webssh页面 - 支持根路径和/ssh路径
const sshHandler = (req, res) => {
  const { username } = req.query;

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>WebSSH Terminal</title>
        <script src="/socket.io/socket.io.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/xterm@4.19.0/lib/xterm.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.5.0/lib/xterm-addon-fit.min.js"></script>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@4.19.0/css/xterm.css" />
        <style>
            html, body {
                margin: 0;
                padding: 0;
                background: #000;
                font-family: monospace;
                width: 100%;
                height: 100%;
                overflow: hidden;
                box-sizing: border-box;
            }
            #terminal {
                width: 100%;
                height: 100%;
                min-width: 100%;
                min-height: 100%;
                box-sizing: border-box;
                overflow: hidden;
            }
        </style>
    </head>
    <body>
        <div id="terminal"></div>
        <script>
            const socket = io({
                path: '/webssh/socket.io',
                transports: ['websocket', 'polling']
            });
            const terminal = new Terminal({
                fontSize: 14,
                fontFamily: 'monospace',
                theme: {
                    background: '#000000',
                    foreground: '#ffffff'
                },
                cursorBlink: true,
                convertEol: true,
                scrollback: 1000,
                tabStopWidth: 4
            });

            // 添加FitAddon
            const fitAddon = new FitAddon.FitAddon();
            terminal.loadAddon(fitAddon);

            terminal.open(document.getElementById('terminal'));

            // 添加复制粘贴功能
            // 右键菜单复制粘贴
            document.addEventListener('contextmenu', (e) => {
                e.preventDefault();

                // 检查是否有选中的文本
                const selection = terminal.getSelection();
                if (selection) {
                    // 有选中文本，复制到剪贴板
                    navigator.clipboard.writeText(selection).then(() => {
                        console.log('文本已复制到剪贴板');
                    }).catch(err => {
                        console.error('复制失败:', err);
                    });
                } else {
                    // 没有选中文本，尝试粘贴
                    navigator.clipboard.readText().then(text => {
                        if (text) {
                            terminal.paste(text);
                            console.log('文本已粘贴');
                        }
                    }).catch(err => {
                        console.error('粘贴失败:', err);
                    });
                }
            });

            // 键盘快捷键
            document.addEventListener('keydown', (e) => {
                // Ctrl+C 复制
                if (e.ctrlKey && e.key === 'c' && terminal.hasSelection()) {
                    e.preventDefault();
                    const selection = terminal.getSelection();
                    navigator.clipboard.writeText(selection).then(() => {
                        console.log('Ctrl+C 复制成功');
                    }).catch(err => {
                        console.error('Ctrl+C 复制失败:', err);
                    });
                    return;
                }

                // Ctrl+V 粘贴
                if (e.ctrlKey && e.key === 'v') {
                    e.preventDefault();
                    navigator.clipboard.readText().then(text => {
                        if (text) {
                            terminal.paste(text);
                            console.log('Ctrl+V 粘贴成功');
                        }
                    }).catch(err => {
                        console.error('Ctrl+V 粘贴失败:', err);
                    });
                    return;
                }

                // Ctrl+Shift+C 强制复制
                if (e.ctrlKey && e.shiftKey && e.key === 'C') {
                    e.preventDefault();
                    const selection = terminal.getSelection();
                    if (selection) {
                        navigator.clipboard.writeText(selection).then(() => {
                            console.log('Ctrl+Shift+C 复制成功');
                        }).catch(err => {
                            console.error('Ctrl+Shift+C 复制失败:', err);
                        });
                    }
                    return;
                }

                // Ctrl+Shift+V 强制粘贴
                if (e.ctrlKey && e.shiftKey && e.key === 'V') {
                    e.preventDefault();
                    navigator.clipboard.readText().then(text => {
                        if (text) {
                            terminal.paste(text);
                            console.log('Ctrl+Shift+V 粘贴成功');
                        }
                    }).catch(err => {
                        console.error('Ctrl+Shift+V 粘贴失败:', err);
                    });
                    return;
                }
            });

            // 连接到容器
            socket.emit('create-terminal', { username: '${username}' });

            // 处理终端输出
            socket.on('terminal-output', (data) => {
                terminal.write(data);
            });

            // 处理用户输入
            terminal.onData((data) => {
                socket.emit('terminal-input', data);
            });

            // 处理终端大小调整
            terminal.onResize((size) => {
                socket.emit('terminal-resize', size);
            });

            // 初始化大小
            setTimeout(() => {
                fitAddon.fit();
            }, 100);

            // 监听窗口大小变化
            window.addEventListener('resize', () => {
                setTimeout(() => {
                    fitAddon.fit();
                }, 50);
            });

            // 监听来自父窗口的resize消息
            window.addEventListener('message', (event) => {
                if (event.data && event.data.type === 'resize') {
                    setTimeout(() => {
                        fitAddon.fit();
                    }, 50);
                }
            });

            // 定期检查并调整大小（确保终端始终适配容器）
            setInterval(() => {
                const terminalElement = document.getElementById('terminal');
                if (terminalElement) {
                    const rect = terminalElement.getBoundingClientRect();
                    const currentCols = terminal.cols;
                    const currentRows = terminal.rows;

                    // 计算应该的列数和行数
                    const charWidth = 9; // 大约的字符宽度
                    const charHeight = 17; // 大约的字符高度
                    const expectedCols = Math.floor(rect.width / charWidth);
                    const expectedRows = Math.floor(rect.height / charHeight);

                    // 如果大小差异较大，重新fit
                    if (Math.abs(expectedCols - currentCols) > 2 || Math.abs(expectedRows - currentRows) > 2) {
                        fitAddon.fit();
                    }
                }
            }, 1000);
        </script>
    </body>
    </html>
  `);
};

// 注册路由处理器
app.get('/', sshHandler);
app.get('/ssh', sshHandler);

// Socket.IO 连接处理
io.on('connection', (socket) => {
  console.log('WebSSH client connected');

  socket.on('create-terminal', ({ username }) => {
    console.log('[WebSSH] Creating terminal for user:', username);

    try {
      // 直接连接到容器
      const containerName = `linux-${username}`;

      const terminal = pty.spawn('docker', [
        'exec', '-i', '-e', 'TERM=xterm-256color', '-e', 'PS1=\\u@\\h:\\w\\$ ',
        '-e', 'BASH_ENV=/etc/bash.bashrc',
        containerName, '/bin/bash', '-li'
      ], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd: process.env.HOME,
        env: {
          ...process.env,
          TERM: 'xterm-256color',
          COLORTERM: 'truecolor'
        }
      });

      terminals[socket.id] = terminal;
      userTerminals[username] = { terminal, socketId: socket.id };
      socket.username = username; // 保存用户名到socket

      // 发送终端输出到客户端
      terminal.on('data', (data) => {
        console.log('[WebSSH] Terminal output:', JSON.stringify(data.slice(0, 100)));
        // 发送给当前用户
        socket.emit('terminal-output', data);

        // 广播给其他用户观看（通过主API服务器）
        if (mainServerSocket.connected) {
          console.log('[WebSSH] Broadcasting terminal output for user:', username, 'data length:', data.length);
          mainServerSocket.emit('broadcast-terminal-output', {
            username: username,
            data: data
          });
        } else {
          console.log('[WebSSH] Main server socket not connected, cannot broadcast');
        }
      });

      // 处理终端退出
      terminal.on('exit', () => {
        socket.emit('terminal-exit');
        delete terminals[socket.id];
        delete userTerminals[username];
      });

      // 发送初始命令来触发bash提示符和设置环境
      setTimeout(() => {
        // 强制设置交互环境
        terminal.write('set +h\n'); // 禁用hash
        terminal.write('export PS1="\\u@\\h:\\w\\$ "\n'); // 设置提示符
        terminal.write('export TERM=xterm-256color\n'); // 设置终端类型
      }, 500);

      setTimeout(() => {
        terminal.write('clear\n'); // 清屏
      }, 1000);

      setTimeout(() => {
        terminal.write('\n'); // 发送回车符触发提示符
      }, 1500);

    } catch (error) {
      console.error('Failed to create terminal:', error);
      socket.emit('terminal-error', error.message);
    }
  });

  socket.on('terminal-input', (data) => {
    console.log('[WebSSH] Terminal input:', JSON.stringify(data));
    const terminal = terminals[socket.id];
    if (terminal) {
      terminal.write(data);
    } else {
      console.log('[WebSSH] No terminal found for socket:', socket.id);
    }
  });

  socket.on('terminal-resize', ({ cols, rows }) => {
    const terminal = terminals[socket.id];
    if (terminal) {
      terminal.resize(cols, rows);
    }
  });

  socket.on('disconnect', () => {
    console.log('WebSSH client disconnected');
    const terminal = terminals[socket.id];
    if (terminal) {
      terminal.kill();
      delete terminals[socket.id];
    }

    // 清理用户终端映射
    if (socket.username) {
      delete userTerminals[socket.username];
    }
  });
});

const PORT = 3002;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`WebSSH server listening on 0.0.0.0:${PORT}`);
});

// 添加错误处理
server.on('error', (err) => {
  console.error('WebSSH server error:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use`);
  }
});
