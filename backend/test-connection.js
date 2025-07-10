// 测试 WebSSH 到主服务器的 Socket.IO 连接

const { io: ioClient } = require('socket.io-client');

console.log('🔗 尝试连接到主服务器...');

const socket = ioClient('http://localhost:8080', {
  timeout: 5000,
  forceNew: true
});

socket.on('connect', () => {
  console.log('✅ 成功连接到主服务器!');
  console.log('🆔 Socket ID:', socket.id);
  
  // 测试发送广播
  console.log('📤 发送测试广播...');
  socket.emit('broadcast-terminal-output', {
    username: 'test-user',
    data: 'Hello from WebSSH test!'
  });
  
  setTimeout(() => {
    console.log('✅ 测试完成，断开连接');
    socket.disconnect();
    process.exit(0);
  }, 2000);
});

socket.on('connect_error', (error) => {
  console.log('❌ 连接失败:', error.message);
  console.log('🔍 错误详情:', error);
  process.exit(1);
});

socket.on('disconnect', (reason) => {
  console.log('🔌 连接断开:', reason);
});

// 超时处理
setTimeout(() => {
  console.log('⏰ 连接超时');
  process.exit(1);
}, 10000);
