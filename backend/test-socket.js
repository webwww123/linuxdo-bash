// 测试 Socket.IO 连接
const { io } = require('socket.io-client');

console.log('测试连接到 http://localhost:8080');
const socket = io('http://localhost:8080');

socket.on('connect', () => {
  console.log('✅ 连接成功!');
  process.exit(0);
});

socket.on('connect_error', (err) => {
  console.log('❌ 连接失败:', err.message);
  process.exit(1);
});

setTimeout(() => {
  console.log('⏰ 超时');
  process.exit(1);
}, 5000);
