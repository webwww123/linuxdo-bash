// 测试多用户广播功能的简化版本

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { io: ioClient } = require('socket.io-client');

const app = express();
const server = http.createServer(app);

// 主服务器 Socket.IO
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  }
});

// WebSSH 客户端连接到主服务器
const mainServerSocket = ioClient('http://localhost:8080');

console.log('🚀 启动测试服务器...');

// 主服务器 Socket.IO 处理
io.on('connection', (socket) => {
  console.log('✅ 用户连接:', socket.id);

  // 处理来自WebSSH服务器的终端输出广播
  socket.on('broadcast-terminal-output', (data) => {
    console.log('📡 收到广播请求 - 用户:', data.username, '数据长度:', data.data.length);
    // 广播给所有其他用户（除了发送者）
    socket.broadcast.emit('user-terminal-output', data);
    console.log('📢 已广播给其他用户');
  });

  socket.on('disconnect', () => {
    console.log('❌ 用户断开:', socket.id);
  });
});

// WebSSH 客户端连接处理
mainServerSocket.on('connect', () => {
  console.log('✅ WebSSH 客户端已连接到主服务器');
  
  // 模拟发送广播
  setTimeout(() => {
    console.log('📤 发送测试广播...');
    mainServerSocket.emit('broadcast-terminal-output', {
      username: 'test-user',
      data: 'Hello from WebSSH!'
    });
  }, 2000);
});

mainServerSocket.on('disconnect', () => {
  console.log('❌ WebSSH 客户端与主服务器断开连接');
});

mainServerSocket.on('connect_error', (err) => {
  console.log('❌ WebSSH 客户端连接失败:', err.message);
});

// 启动服务器
const PORT = 8080;
server.listen(PORT, () => {
  console.log(`🌐 测试服务器运行在 http://localhost:${PORT}`);
  console.log('📋 测试步骤:');
  console.log('1. 打开浏览器访问 http://localhost:8080');
  console.log('2. 打开开发者工具查看 Socket.IO 连接');
  console.log('3. 观察控制台输出的广播消息');
});

// 简单的测试页面
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>多用户广播测试</title>
        <script src="/socket.io/socket.io.js"></script>
    </head>
    <body>
        <h1>多用户广播测试</h1>
        <div id="messages"></div>
        <script>
            const socket = io();
            const messages = document.getElementById('messages');
            
            socket.on('connect', () => {
                console.log('✅ 连接成功:', socket.id);
                messages.innerHTML += '<p>✅ 连接成功: ' + socket.id + '</p>';
            });
            
            socket.on('user-terminal-output', (data) => {
                console.log('📡 收到广播:', data);
                messages.innerHTML += '<p>📡 收到广播 - 用户: ' + data.username + ', 数据: ' + data.data + '</p>';
            });
            
            socket.on('disconnect', () => {
                console.log('❌ 连接断开');
                messages.innerHTML += '<p>❌ 连接断开</p>';
            });
        </script>
    </body>
    </html>
  `);
});
