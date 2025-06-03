const pty = require('node-pty');
const Docker = require('dockerode');

class TerminalService {
  constructor() {
    this.docker = new Docker();
    this.terminals = new Map();
  }

  /**
   * 创建终端会话 - 使用node-pty直接连接到容器
   */
  async createTerminal(username, containerId) {
    try {
      console.log(`创建终端会话: ${username}, 容器: ${containerId}`);

      // 使用容器名称而不是ID，因为我们知道容器名称格式
      const containerName = `linux-${username}`;

      // 使用node-pty创建一个伪终端，直接执行docker exec
      const terminal = pty.spawn('docker', [
        'exec', '-it', containerName, '/bin/bash'
      ], {
        name: 'xterm-color',
        cols: 80,
        rows: 24,
        cwd: process.env.HOME,
        env: {
          ...process.env,
          TMOUT: '0', // 禁用bash超时
          HISTCONTROL: 'ignoredups',
          HISTSIZE: '1000'
        }
      });

      const terminalSession = {
        pid: terminal.pid,
        terminal: terminal,
        lastActivity: Date.now(),
        keepAliveInterval: null,
        write: (data) => {
          terminal.write(data);
          terminalSession.lastActivity = Date.now();
        },
        onData: (callback) => {
          terminal.on('data', (data) => {
            terminalSession.lastActivity = Date.now();
            callback(data);
          });
        },
        onExit: (callback) => {
          terminal.on('exit', callback);
        },
        resize: (cols, rows) => {
          terminal.resize(cols, rows);
        },
        kill: () => {
          if (terminalSession.keepAliveInterval) {
            clearInterval(terminalSession.keepAliveInterval);
          }
          terminal.kill();
        }
      };

      // 设置心跳机制，每30秒发送一个空字符来保持连接
      terminalSession.keepAliveInterval = setInterval(() => {
        const now = Date.now();
        const timeSinceLastActivity = now - terminalSession.lastActivity;

        // 如果超过5分钟没有活动，发送心跳
        if (timeSinceLastActivity > 5 * 60 * 1000) {
          try {
            // 发送一个不可见的字符来保持连接
            terminal.write('');
          } catch (error) {
            console.error('心跳发送失败:', error);
          }
        }
      }, 30 * 1000); // 每30秒检查一次

      this.terminals.set(terminal.pid, terminalSession);

      // 清理终端显示
      setTimeout(() => {
        terminal.write('clear\n');
      }, 500);

      console.log(`终端会话创建成功: ${terminal.pid}`);
      return terminalSession;
    } catch (error) {
      console.error('创建终端失败:', error);
      throw new Error('终端创建失败: ' + error.message);
    }
  }

  /**
   * 获取终端会话
   */
  getTerminal(terminalId) {
    return this.terminals.get(terminalId);
  }

  /**
   * 写入数据到终端
   */
  writeToTerminal(terminalId, data) {
    const terminal = this.terminals.get(terminalId);
    if (terminal) {
      console.log(`写入终端 ${terminalId}:`, data);
      terminal.write(data);
    }
  }

  /**
   * 调整终端大小
   */
  resizeTerminal(terminalId, cols, rows) {
    const terminal = this.terminals.get(terminalId);
    if (terminal) {
      console.log(`调整终端大小 ${terminalId}: ${cols}x${rows}`);
      terminal.resize(cols, rows);
    }
  }

  /**
   * 关闭终端会话
   */
  closeTerminal(terminalId) {
    const terminal = this.terminals.get(terminalId);
    if (terminal) {
      console.log(`关闭终端会话: ${terminalId}`);
      terminal.kill();
      this.terminals.delete(terminalId);
    }
  }

  /**
   * 清理所有终端会话
   */
  cleanup() {
    console.log('清理所有终端会话');
    for (const [terminalId, terminal] of this.terminals) {
      terminal.kill();
    }
    this.terminals.clear();
  }
}

module.exports = TerminalService;
