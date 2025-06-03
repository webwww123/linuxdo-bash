import React from 'react';
import { Container, Loader } from 'lucide-react';

const ProgressModal = ({ progress, message, username }) => {
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-8 max-w-md w-full">
        <div className="text-center">
          {/* 图标 */}
          <div className="inline-flex items-center justify-center w-16 h-16 bg-linux-100 dark:bg-linux-900/20 text-linux-600 dark:text-linux-400 rounded-full mb-6">
            <Container size={32} />
          </div>

          {/* 标题 */}
          <h2 className="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-2">
            正在为 {username} 创建容器
          </h2>

          <p className="text-gray-600 dark:text-gray-300 mb-8">
            请稍等，我们正在为你准备独立的Linux环境...
          </p>

          {/* 进度条 */}
          <div className="mb-6">
            <div className="progress-bar mb-3">
              <div
                className="progress-fill"
                style={{ width: `${progress}%` }}
              ></div>
            </div>
            <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400">
              <span>0%</span>
              <span className="font-medium">{progress}%</span>
              <span>100%</span>
            </div>
          </div>

          {/* 当前状态 */}
          <div className="flex items-center justify-center space-x-2 text-linux-600 dark:text-linux-400">
            <Loader size={16} className="animate-spin" />
            <span className="text-sm font-medium">{message}</span>
          </div>

          {/* 进度步骤 */}
          <div className="mt-8 text-left">
            <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-3">创建步骤：</h3>
            <div className="space-y-2">
              {[
                { step: '拉取Ubuntu镜像', threshold: 20 },
                { step: '创建容器', threshold: 40 },
                { step: '配置环境', threshold: 60 },
                { step: '启动服务', threshold: 80 },
                { step: '容器就绪', threshold: 100 }
              ].map((item, index) => (
                <div key={index} className="flex items-center space-x-3">
                  <div className={`w-2 h-2 rounded-full ${
                    progress >= item.threshold
                      ? 'bg-green-500'
                      : progress >= item.threshold - 20
                        ? 'bg-linux-500 animate-pulse'
                        : 'bg-gray-300 dark:bg-gray-600'
                  }`}></div>
                  <span className={`text-sm ${
                    progress >= item.threshold
                      ? 'text-green-600 dark:text-green-400 font-medium'
                      : progress >= item.threshold - 20
                        ? 'text-linux-600 dark:text-linux-400'
                        : 'text-gray-500 dark:text-gray-400'
                  }`}>
                    {item.step}
                  </span>
                  {progress >= item.threshold && (
                    <span className="text-green-500 text-xs">✓</span>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* 提示信息 */}
          <div className="mt-8 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <div className="text-sm text-blue-800 dark:text-blue-300">
              <p className="font-medium mb-1">💡 小贴士</p>
              <p>容器创建完成后，你将获得：</p>
              <ul className="list-disc list-inside mt-2 space-y-1 text-xs">
                <li>完整的Ubuntu 22.04环境</li>
                <li>sudo权限，可安装任何软件</li>
                <li>2小时的使用时间</li>
                <li>与其他用户完全隔离</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ProgressModal;
