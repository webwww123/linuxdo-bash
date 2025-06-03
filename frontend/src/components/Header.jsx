import React, { useState, useEffect, useRef } from 'react';
import { Terminal, LogOut, Github, Heart, Bell, X } from 'lucide-react';
import ThemeToggle from './ThemeToggle';

const Header = ({ username, onLogout, onlineCount = 0 }) => {
  const [showNotifications, setShowNotifications] = useState(false);
  const notificationRef = useRef(null);

  // 硬编码的通知内容，可以随时修改
  const notifications = [
    {
      id: 1,
      title: "欢迎使用Linux Analytics！",
      content: "支持多用户机器学习协作，每人一个独立的容器环境。",
      time: "2024-01-15",
      type: "info"
    },
    {
      id: 2,
      title: "新功能上线",
      content: "现在支持终端复制粘贴功能，使用Ctrl+Shift+C/V进行操作。",
      time: "2024-01-14",
      type: "feature"
    },
    {
      id: 3,
      title: "聊天室更新",
      content: "聊天室现在支持Shift+Enter换行，可以发送多行消息了！",
      time: "2024-01-13",
      type: "update"
    }
  ];

  const toggleNotifications = () => {
    setShowNotifications(!showNotifications);
  };

  // 点击外部关闭通知弹窗
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (notificationRef.current && !notificationRef.current.contains(event.target)) {
        setShowNotifications(false);
      }
    };

    if (showNotifications) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showNotifications]);

  return (
    <header className="bg-white dark:bg-gray-900 shadow-sm border-b border-gray-200 dark:border-gray-700">
      <div className="container mx-auto px-4">
        <div className="flex items-center h-16">
          {/* 左侧：Logo和标题 */}
          <div className="flex items-center space-x-3">
            <div className="flex items-center justify-center w-10 h-10 bg-linuxdo-500 text-white rounded-lg">
              <Terminal size={24} />
            </div>
            <div>
              <h1 className="text-xl font-bold text-gray-900 dark:text-white">
                Linux Analytics
              </h1>
              <p className="text-sm text-gray-500 dark:text-gray-400 hidden sm:block">
                机器学习容器管理平台
              </p>
            </div>
          </div>

          {/* 中间：通知按钮 */}
          <div className="hidden lg:flex flex-1 justify-center mx-8 relative">
            <button
              onClick={toggleNotifications}
              className="bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700 text-white px-4 py-2 rounded-lg shadow-lg hover:shadow-xl transition-all duration-200 transform hover:scale-105 flex items-center space-x-2 relative"
            >
              <Bell size={16} className="animate-pulse" />
              <span className="text-sm font-medium">点我查看通知</span>
              {/* 高亮小红点 */}
              <div className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full animate-ping"></div>
              <div className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full"></div>
            </button>

            {/* 通知弹窗 */}
            {showNotifications && (
              <div ref={notificationRef} className="absolute top-full mt-2 w-96 bg-white dark:bg-gray-800 rounded-lg shadow-2xl border border-gray-200 dark:border-gray-700 z-50">
                <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-white">系统通知</h3>
                  <button
                    onClick={toggleNotifications}
                    className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  >
                    <X size={20} />
                  </button>
                </div>
                <div className="max-h-80 overflow-y-auto">
                  {notifications.map((notification) => (
                    <div key={notification.id} className="p-4 border-b border-gray-100 dark:border-gray-700 last:border-b-0">
                      <div className="flex items-start space-x-3">
                        <div className={`w-2 h-2 rounded-full mt-2 ${
                          notification.type === 'info' ? 'bg-blue-500' :
                          notification.type === 'feature' ? 'bg-green-500' :
                          'bg-purple-500'
                        }`}></div>
                        <div className="flex-1">
                          <h4 className="text-sm font-medium text-gray-900 dark:text-white mb-1">
                            {notification.title}
                          </h4>
                          <p className="text-sm text-gray-600 dark:text-gray-300 mb-2">
                            {notification.content}
                          </p>
                          <span className="text-xs text-gray-400">{notification.time}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* 右侧：用户信息和操作 */}
          <div className="flex items-center space-x-4">
            {username && (
              <>
                <div className="hidden sm:flex items-center space-x-3">
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                      {username}
                    </span>
                  </div>
                  <div className="flex items-center space-x-1 text-xs text-gray-500 dark:text-gray-400">
                    <span>在线:</span>
                    <span className="font-medium text-linuxdo-600 dark:text-linuxdo-400">
                      {onlineCount}
                    </span>
                  </div>
                </div>
                <button
                  onClick={onLogout}
                  className="flex items-center space-x-2 px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
                >
                  <LogOut size={16} />
                  <span className="hidden sm:inline">退出</span>
                </button>
              </>
            )}

            {/* 主题切换按钮 */}
            <ThemeToggle />

            {/* GitHub链接 */}
            <a
              href="https://github.com/ml-analytics"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-2 px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
            >
              <Github size={16} />
              <span className="hidden sm:inline">GitHub</span>
            </a>
          </div>
        </div>
      </div>

      {/* 状态栏 */}
      {username && (
        <div className="bg-linuxdo-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700">
          <div className="container mx-auto px-4 py-2">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center space-x-4">
                <span className="text-gray-600 dark:text-gray-400">
                  容器状态: <span className="text-green-600 dark:text-green-400 font-medium">运行中</span>
                </span>
                <span className="text-gray-600 dark:text-gray-400">
                  用户: <span className="font-medium">{username}</span>
                </span>
              </div>
              <div className="flex items-center space-x-2 text-gray-500 dark:text-gray-400">
                <Heart size={14} />
                <span>Made with ❤️ by ML Analytics Team</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </header>
  );
};

export default Header;
