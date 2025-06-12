import React, { useEffect, useRef, useState } from 'react';
import { Terminal as XTerm } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Maximize2, Minimize2, RotateCcw, Copy, Clipboard } from 'lucide-react';

const Terminal = ({ socket, username, onFullscreenChange }) => {
  const terminalRef = useRef(null);
  const xtermRef = useRef(null);
  const fitAddonRef = useRef(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showCopyTip, setShowCopyTip] = useState(false);
  const [showPasteTip, setShowPasteTip] = useState(false);

  useEffect(() => {
    if (!socket || !terminalRef.current) return;

    // 创建终端实例 - 使用最简单的配置
    const xterm = new XTerm({
      fontSize: 14,
      fontFamily: 'monospace',
      cursorBlink: true,
      theme: {
        background: '#000000',
        foreground: '#ffffff'
      }
    });

    // 添加插件
    const fitAddon = new FitAddon();
    const webLinksAddon = new WebLinksAddon();

    xterm.loadAddon(fitAddon);
    xterm.loadAddon(webLinksAddon);

    // 打开终端
    try {
      xterm.open(terminalRef.current);
      console.log('Terminal opened successfully');

      // 立即写入连接状态
      xterm.write('\x1b[36m正在连接到容器...\x1b[0m\r\n');
      xterm.write('\x1b[33m请稍候，正在准备您的Linux环境\x1b[0m\r\n');
      xterm.write('\r\n');

      // 延迟调用fit
      setTimeout(() => {
        try {
          fitAddon.fit();
          console.log('Terminal fitted, size:', xterm.cols, 'x', xterm.rows);
        } catch (error) {
          console.warn('Initial fit failed:', error);
        }
      }, 200);
    } catch (error) {
      console.error('Terminal open failed:', error);
      return;
    }

    // 保存引用
    xtermRef.current = xterm;
    fitAddonRef.current = fitAddon;

    // 监听终端输入
    xterm.onData((data) => {
      socket.emit('terminal-input', data);
    });

    // 监听终端输出
    socket.on('terminal-output', (data) => {
      console.log('收到终端输出:', data);

      try {
        // 第一次收到数据时清除初始文本
        if (!xterm.hasReceivedData) {
          xterm.clear();
          xterm.hasReceivedData = true;
        }

        // 直接写入数据
        xterm.write(data);
      } catch (error) {
        console.error('写入终端失败:', error);
      }
    });

    // 监听终端退出
    socket.on('terminal-exit', () => {
      xterm.write('\r\n\r\n[终端会话已结束]\r\n');
    });

    // 监听窗口大小变化
    const handleResize = () => {
      if (fitAddon && xterm) {
        try {
          fitAddon.fit();
          socket.emit('terminal-resize', {
            cols: xterm.cols,
            rows: xterm.rows
          });
        } catch (error) {
          console.warn('Terminal resize failed:', error);
        }
      }
    };

    window.addEventListener('resize', handleResize);

    // 添加键盘快捷键支持
    const handleKeyDown = (e) => {
      // Ctrl+C 复制 (只有当有选中文本时)
      if (e.ctrlKey && e.key === 'c') {
        e.preventDefault();
        handleCopy();
        return;
      }

      // Ctrl+V 粘贴
      if (e.ctrlKey && e.key === 'v') {
        e.preventDefault();
        handlePaste();
        return;
      }

      // Ctrl+Shift+C 强制复制
      if (e.ctrlKey && e.shiftKey && e.key === 'C') {
        e.preventDefault();
        handleCopy();
        return;
      }

      // Ctrl+Shift+V 强制粘贴
      if (e.ctrlKey && e.shiftKey && e.key === 'V') {
        e.preventDefault();
        handlePaste();
        return;
      }
    };

    document.addEventListener('keydown', handleKeyDown);

    // 初始化大小 - 延迟更长时间确保DOM完全渲染
    const resizeTimer = setTimeout(() => {
      handleResize();
    }, 300);

    // 再次确保大小正确
    const secondResizeTimer = setTimeout(() => {
      handleResize();
    }, 1000);

    return () => {
      window.removeEventListener('resize', handleResize);
      document.removeEventListener('keydown', handleKeyDown);
      clearTimeout(resizeTimer);
      clearTimeout(secondResizeTimer);
      socket.off('terminal-output');
      socket.off('terminal-exit');
      if (xterm) {
        xterm.dispose();
      }
    };
  }, [socket]);

  // 监听窗口大小变化，通知iframe调整大小
  useEffect(() => {
    const handleWindowResize = () => {
      const iframe = document.querySelector('.terminal-container iframe');
      if (iframe) {
        try {
          // 延迟触发，确保布局稳定
          setTimeout(() => {
            try {
              // 只使用postMessage，避免跨域问题
              iframe.contentWindow?.postMessage({
                type: 'resize',
                width: iframe.clientWidth,
                height: iframe.clientHeight
              }, '*');
            } catch (error) {
              console.warn('Failed to notify iframe of window resize:', error);
            }
          }, 100);
        } catch (error) {
          console.warn('Failed to notify iframe of window resize:', error);
        }
      }
    };

    window.addEventListener('resize', handleWindowResize);
    return () => window.removeEventListener('resize', handleWindowResize);
  }, []);

  const handleFullscreen = () => {
    const newFullscreenState = !isFullscreen;
    setIsFullscreen(newFullscreenState);

    // 通知父组件全屏状态变化
    if (onFullscreenChange) {
      onFullscreenChange(newFullscreenState);
    }

    // 延迟调整大小，确保CSS动画完成，并通知iframe内的终端调整大小
    setTimeout(() => {
      // 通知iframe内的WebSSH终端调整大小
      const iframe = document.querySelector('.terminal-container iframe');
      if (iframe && iframe.contentWindow) {
        try {
          // 发送resize事件给iframe
          iframe.contentWindow.postMessage({
            type: 'resize',
            fullscreen: newFullscreenState
          }, '*');

          // 使用postMessage通知iframe
          try {
            iframe.contentWindow?.postMessage({
              type: 'resize',
              width: iframe.clientWidth,
              height: iframe.clientHeight
            }, '*');
          } catch (error) {
            console.warn('Failed to notify iframe resize:', error);
          }
        } catch (error) {
          console.warn('Failed to notify iframe resize:', error);
        }
      }

      // 原有的xterm调整逻辑（如果有的话）
      if (fitAddonRef.current && xtermRef.current) {
        try {
          fitAddonRef.current.fit();
          socket.emit('terminal-resize', {
            cols: xtermRef.current.cols,
            rows: xtermRef.current.rows
          });
        } catch (error) {
          console.warn('Fullscreen resize failed:', error);
        }
      }
    }, 300); // 增加延迟时间确保CSS完全应用
  };

  const handleClear = () => {
    if (xtermRef.current) {
      xtermRef.current.clear();
    }
  };

  const handleReset = () => {
    if (xtermRef.current) {
      xtermRef.current.reset();
    }
  };

  const handleCopy = async () => {
    setShowCopyTip(true);
    setTimeout(() => setShowCopyTip(false), 3000);
  };

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        setShowPasteTip(true);
        setTimeout(() => setShowPasteTip(false), 3000);

        // 尝试通过模拟键盘输入来粘贴
        const iframe = document.querySelector('iframe[title="WebSSH Terminal"]');
        if (iframe) {
          iframe.focus();
          // 模拟Ctrl+Shift+V
          const event = new KeyboardEvent('keydown', {
            key: 'V',
            code: 'KeyV',
            ctrlKey: true,
            shiftKey: true,
            bubbles: true
          });
          try {
            // 使用postMessage发送粘贴事件
            iframe.contentWindow?.postMessage({
              type: 'paste',
              data: text
            }, '*');
          } catch (error) {
            console.warn('Failed to send paste event:', error);
          }
        }
      }
    } catch (error) {
      console.error('粘贴失败:', error);
    }
  };

  return (
    <div className={`terminal-container ${isFullscreen ? 'fixed inset-0 z-50' : ''}`}>
      {/* 终端头部 */}
      <div className="terminal-header">
        <div className="flex items-center space-x-2">
          <div className="terminal-controls">
            <div className="terminal-control close"></div>
            <div className="terminal-control minimize"></div>
            <div className="terminal-control maximize"></div>
          </div>
          <span className="text-gray-300 text-sm font-medium ml-4">
            {username}@linux-container
          </span>
        </div>

        <div className="flex items-center space-x-4">
          {/* 复制粘贴提示 */}
          <div className="hidden lg:flex items-center space-x-3 text-xs text-gray-400">
            <div className="flex items-center space-x-1">
              <button
                onClick={handleCopy}
                className="p-1 text-gray-400 hover:text-white transition-colors"
                title="复制选中文本"
              >
                <Copy size={14} />
              </button>
              <span>Ctrl+Shift+C</span>
            </div>
            <div className="flex items-center space-x-1">
              <button
                onClick={handlePaste}
                className="p-1 text-gray-400 hover:text-white transition-colors"
                title="粘贴"
              >
                <Clipboard size={14} />
              </button>
              <span>Ctrl+Shift+V</span>
            </div>
          </div>

          {/* 移动端只显示图标 */}
          <div className="lg:hidden flex items-center space-x-2">
            <button
              onClick={handleCopy}
              className="p-1 text-gray-400 hover:text-white transition-colors"
              title="复制选中文本 (Ctrl+Shift+C)"
            >
              <Copy size={16} />
            </button>
            <button
              onClick={handlePaste}
              className="p-1 text-gray-400 hover:text-white transition-colors"
              title="粘贴 (Ctrl+Shift+V)"
            >
              <Clipboard size={16} />
            </button>
          </div>

          {/* 其他按钮 */}
          <div className="flex items-center space-x-2">
            <button
              onClick={handleClear}
              className="p-1 text-gray-400 hover:text-white transition-colors"
              title="清屏"
            >
              <RotateCcw size={16} />
            </button>
            <button
              onClick={handleFullscreen}
              className="p-1 text-gray-400 hover:text-white transition-colors"
              title={isFullscreen ? "退出全屏" : "全屏"}
            >
              {isFullscreen ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
            </button>
          </div>
        </div>
      </div>

      {/* 终端内容 */}
      <div
        className={`overflow-hidden ${
          isFullscreen
            ? 'h-[calc(100vh-48px)]'
            : 'h-96 lg:h-[500px]'
        }`}
        style={{
          minHeight: isFullscreen ? '100vh' : '300px',
          width: '100%',
          position: 'relative',
          backgroundColor: '#000000',
          color: '#ffffff'
        }}
      >
        {/* 使用iframe嵌入webssh - 这个方案已经验证可以工作 */}
        <iframe
          ref={(iframe) => {
            if (iframe) {
              // 当iframe加载完成后，设置resize监听
              iframe.onload = () => {
                // 延迟触发resize确保终端正确初始化
                setTimeout(() => {
                  try {
                    // 只使用postMessage，避免跨域问题
                    iframe.contentWindow?.postMessage({
                      type: 'resize',
                      width: iframe.clientWidth,
                      height: iframe.clientHeight
                    }, '*');
                  } catch (error) {
                    console.warn('Failed to trigger initial iframe resize:', error);
                  }
                }, 500);
              };
            }
          }}
          src={`/webssh/ssh?username=${username}`}
          style={{
            width: '100%',
            height: '100%',
            border: 'none',
            backgroundColor: '#000000'
          }}
          title="WebSSH Terminal"
        />

        {/* 复制粘贴提示 */}
        {showCopyTip && (
          <div className="absolute top-4 right-4 bg-blue-500 text-white px-3 py-2 rounded-lg shadow-lg z-10">
            💡 请在终端中选中文本后使用 Ctrl+Shift+C 复制
          </div>
        )}

        {showPasteTip && (
          <div className="absolute top-4 right-4 bg-green-500 text-white px-3 py-2 rounded-lg shadow-lg z-10">
            ✅ 请在终端中使用 Ctrl+Shift+V 粘贴
          </div>
        )}
      </div>

      {/* 状态栏 */}
      <div className="bg-gray-800 px-4 py-2 text-xs text-gray-400 flex justify-between items-center">
        <div className="flex items-center space-x-4">
          <span>容器: {username}</span>
          <span className="flex items-center">
            <div className="w-2 h-2 bg-green-500 rounded-full mr-1"></div>
            已连接
          </span>
        </div>
        <div className="flex items-center space-x-4">
          <span>UTF-8</span>
          <span>Bash</span>
        </div>
      </div>
    </div>
  );
};

export default Terminal;
