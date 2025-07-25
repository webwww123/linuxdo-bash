import React, { useState, useRef, useEffect } from 'react';
import { Send, MessageCircle, Smile, Image } from 'lucide-react';
import { getUserAvatarColor, getUserInitial, getUserAvatar } from '../utils/avatarColors';

// 常用表情列表
const EMOJI_LIST = [
  '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
  '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
  '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
  '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
  '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
  '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
  '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
  '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥',
  '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧',
  '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
  '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑',
  '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻',
  '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸',
  '😹', '😻', '😼', '😽', '🙀', '😿', '😾', '👋',
  '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️',
  '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕',
  '👇', '☝️', '👍', '👎', '👊', '✊', '🤛', '🤜',
  '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
  '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
  '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈',
  '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐',
  '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️'
];

const Chat = ({ socket, messages, currentUsername, onSendMessage, activeUsers = [] }) => {
  const [inputMessage, setInputMessage] = useState('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [userAvatars, setUserAvatars] = useState({});
  const [isUploading, setIsUploading] = useState(false);
  const messagesEndRef = useRef(null);
  const messagesContainerRef = useRef(null);
  const inputRef = useRef(null);
  const emojiPickerRef = useRef(null);
  const fileInputRef = useRef(null);

  // 用于跟踪是否是初次加载
  const [isInitialLoad, setIsInitialLoad] = useState(true);

  // 自动滚动到底部 - 只在聊天容器内滚动，且只在有新消息时滚动
  useEffect(() => {
    if (messagesContainerRef.current && messages.length > 0) {
      const container = messagesContainerRef.current;

      // 如果是初次加载，强制滚动到底部
      if (isInitialLoad) {
        requestAnimationFrame(() => {
          container.scrollTop = container.scrollHeight;
          setIsInitialLoad(false);
        });
        return;
      }

      // 检查用户是否已经滚动到接近底部
      const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 100;

      // 只有当用户在底部附近时才自动滚动
      if (isNearBottom) {
        // 使用 requestAnimationFrame 确保 DOM 更新完成后再滚动
        requestAnimationFrame(() => {
          container.scrollTop = container.scrollHeight;
        });
      }
    }
  }, [messages, isInitialLoad]);

  // 加载用户头像设置
  useEffect(() => {
    const loadUserAvatars = () => {
      const avatars = {};
      const usernames = new Set();

      // 从消息中收集所有用户名
      messages.forEach(message => {
        if (message.username) {
          usernames.add(message.username);
        }
      });

      // 加载每个用户的头像设置
      usernames.forEach(username => {
        const avatar = getUserAvatar(username);
        if (avatar) {
          avatars[username] = avatar;
        }
      });

      setUserAvatars(avatars);
    };

    loadUserAvatars();
  }, [messages]);

  // 点击外部关闭表情选择器和@列表
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (emojiPickerRef.current && !emojiPickerRef.current.contains(event.target)) {
        setShowEmojiPicker(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!inputMessage.trim()) return;

    onSendMessage({
      message: inputMessage.trim(),
      messageType: 'text'
    });
    setInputMessage('');
    setShowEmojiPicker(false);
  };

  const handleKeyDown = (e) => {
    // Shift+Enter 换行
    if (e.key === 'Enter' && e.shiftKey) {
      e.preventDefault();
      const cursorPosition = e.target.selectionStart;
      const textBefore = inputMessage.substring(0, cursorPosition);
      const textAfter = inputMessage.substring(cursorPosition);
      setInputMessage(textBefore + '\n' + textAfter);

      // 设置光标位置到换行后的位置
      setTimeout(() => {
        e.target.selectionStart = e.target.selectionEnd = cursorPosition + 1;
        adjustTextareaHeight(e.target);
      }, 0);
      return;
    }

    // Enter 发送消息
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
      return;
    }
  };

  // 自动调整textarea高度
  const adjustTextareaHeight = (textarea) => {
    textarea.style.height = 'auto';
    const scrollHeight = textarea.scrollHeight;
    const maxHeight = 120; // 最大高度120px
    textarea.style.height = Math.min(scrollHeight, maxHeight) + 'px';
  };

  // 监听输入变化，自动调整高度
  const handleInputChange = (e) => {
    const value = e.target.value;
    setInputMessage(value);
    adjustTextareaHeight(e.target);
  };

  const handleEmojiSelect = (emoji) => {
    setInputMessage(prev => prev + emoji);
    setShowEmojiPicker(false);
    inputRef.current?.focus();
  };

  const toggleEmojiPicker = () => {
    setShowEmojiPicker(!showEmojiPicker);
  };

  // 处理图片粘贴
  const handlePaste = async (e) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.type.startsWith('image/')) {
        e.preventDefault();
        const file = item.getAsFile();
        if (file) {
          await uploadImage(file);
        }
        break;
      }
    }
  };

  // 处理图片文件选择
  const handleImageSelect = (e) => {
    const file = e.target.files[0];
    if (file) {
      uploadImage(file);
    }
    // 清空input值，允许重复选择同一文件
    e.target.value = '';
  };

  // 上传图片
  const uploadImage = async (file) => {
    if (!file.type.startsWith('image/')) {
      alert('只能上传图片文件');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      alert('图片大小不能超过5MB');
      return;
    }

    setIsUploading(true);
    const formData = new FormData();
    formData.append('image', file);

    try {
      const response = await fetch('/api/upload-image', {
        method: 'POST',
        body: formData
      });

      const result = await response.json();
      console.log('图片上传结果:', result);
      if (result.success) {
        // 使用相对路径，通过Nginx代理访问
        const imageUrl = result.imageUrl; // 已经是 /uploads/filename 格式
        console.log('发送图片消息:', { imageUrl });

        // 发送图片消息
        onSendMessage({
          message: '',
          messageType: 'image',
          imageUrl: imageUrl
        });
      } else {
        alert('图片上传失败: ' + result.error);
      }
    } catch (error) {
      console.error('图片上传失败:', error);
      alert('图片上传失败');
    } finally {
      setIsUploading(false);
    }
  };



  // 渲染带@高亮的消息
  const renderMessageWithMentions = (text) => {
    if (!text) return text;

    // 使用dangerouslySetInnerHTML来渲染HTML，这样点击事件更可靠
    const mentionRegex = /@([a-zA-Z0-9_\u4e00-\u9fa5]+)/g;
    let processedText = text;

    processedText = processedText.replace(mentionRegex, (match, username) => {
      const isCurrentUser = username === currentUsername;
      const colorClass = isCurrentUser
        ? 'color: #2563eb; background-color: #dbeafe; padding: 2px 4px; border-radius: 4px;'
        : 'color: #16a34a;';

      return `<span
        style="font-weight: 600; cursor: pointer; ${colorClass}"
        onclick="window.handleMentionClick('${username}')"
        onmouseover="this.style.textDecoration='underline'"
        onmouseout="this.style.textDecoration='none'"
        title="点击@${username}"
      >@${username}</span>`;
    });

    return <span dangerouslySetInnerHTML={{ __html: processedText }} />;
  };

  // 全局函数，处理@用户点击
  React.useEffect(() => {
    window.handleMentionClick = (username) => {
      console.log('点击了@用户:', username);
      setInputMessage(prev => prev + (prev.endsWith(' ') || prev === '' ? '' : ' ') + `@${username} `);
      if (inputRef.current) {
        inputRef.current.focus();
        setTimeout(() => {
          const newLength = inputMessage.length + (inputMessage.endsWith(' ') || inputMessage === '' ? 0 : 1) + username.length + 2;
          inputRef.current.setSelectionRange(newLength, newLength);
        }, 0);
      }
    };

    return () => {
      delete window.handleMentionClick;
    };
  }, [inputMessage]);

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatDate = (timestamp) => {
    const date = new Date(timestamp);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === today.toDateString()) {
      return '今天';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return '昨天';
    } else {
      return date.toLocaleDateString('zh-CN', {
        month: 'short',
        day: 'numeric'
      });
    }
  };

  // 按日期分组消息
  const groupedMessages = messages.reduce((groups, message) => {
    const date = formatDate(message.createdAt || message.timestamp);
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(message);
    return groups;
  }, {});

  return (
    <div className="chat-container">
      {/* 聊天头部 */}
      <div className="chat-header">
        <div className="flex items-center space-x-2">
          <MessageCircle size={20} />
          <span>聊天室</span>
        </div>
      </div>

      {/* 消息列表 */}
      <div ref={messagesContainerRef} className="chat-messages">
        {Object.keys(groupedMessages).length === 0 ? (
          <div className="text-center text-gray-500 dark:text-gray-400 py-8">
            <MessageCircle size={32} className="mx-auto mb-2 opacity-50" />
            <p>还没有消息</p>
            <p className="text-sm">开始聊天吧！</p>
          </div>
        ) : (
          Object.entries(groupedMessages).map(([date, dateMessages]) => (
            <div key={date}>
              {/* 日期分隔符 */}
              <div className="flex items-center justify-center my-4">
                <div className="bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 text-xs px-3 py-1 rounded-full">
                  {date}
                </div>
              </div>

              {/* 该日期的消息 */}
              {dateMessages.map((message, index) => {
                const isOwn = message.username === currentUsername;
                const showAvatar = index === 0 ||
                  dateMessages[index - 1].username !== message.username;

                return (
                  <div
                    key={message.id || index}
                    className={`chat-message ${isOwn ? 'own' : 'other'} fade-in`}
                  >
                    {/* 显示所有消息的用户名和头像（当用户变化时） */}
                    {showAvatar && (
                      <div className={`flex items-center space-x-2 mb-1 ${isOwn ? 'justify-end' : 'justify-start'}`}>
                        {!isOwn && (
                          <div className={`w-6 h-6 ${getUserAvatarColor(message.username, userAvatars[message.username])} text-white rounded-full flex items-center justify-center text-xs font-medium`}>
                            {getUserInitial(message.username, userAvatars[message.username])}
                          </div>
                        )}
                        <span className="text-xs font-medium text-gray-600 dark:text-gray-300">
                          {message.username}
                        </span>
                        {isOwn && (
                          <div className={`w-6 h-6 ${getUserAvatarColor(message.username, userAvatars[message.username])} text-white rounded-full flex items-center justify-center text-xs font-medium`}>
                            {getUserInitial(message.username, userAvatars[message.username])}
                          </div>
                        )}
                      </div>
                    )}

                    <div className={`message-bubble ${isOwn ? 'own' : 'other'}`}>
                      {message.messageType === 'image' ? (
                        <div className="space-y-2">
                          <img
                            src={(() => {
                              // 处理图片URL：如果是完整URL，转换为相对路径
                              let imageUrl = message.imageUrl;
                              if (imageUrl && imageUrl.startsWith('http://localhost:3001/')) {
                                imageUrl = imageUrl.replace('http://localhost:3001', '');
                              }
                              return imageUrl;
                            })()}
                            alt="聊天图片"
                            className="max-w-xs max-h-64 rounded-lg cursor-pointer hover:opacity-90 transition-opacity"
                            onClick={() => {
                              let imageUrl = message.imageUrl;
                              if (imageUrl && imageUrl.startsWith('http://localhost:3001/')) {
                                imageUrl = imageUrl.replace('http://localhost:3001', '');
                              }
                              window.open(imageUrl, '_blank');
                            }}
                            onError={(e) => {
                              console.error('图片加载失败:', message.imageUrl);
                              e.target.style.display = 'none';
                              e.target.nextSibling.style.display = 'block';
                            }}
                            onLoad={() => console.log('图片加载成功:', message.imageUrl)}
                          />
                          <div style={{display: 'none'}} className="text-red-500 text-sm">
                            图片加载失败: {message.imageUrl}
                          </div>
                          {message.message && (
                            <pre className="whitespace-pre-wrap font-sans text-sm m-0">
                              {renderMessageWithMentions(message.message)}
                            </pre>
                          )}
                        </div>
                      ) : (
                        <pre className="whitespace-pre-wrap font-sans text-sm m-0">
                          {renderMessageWithMentions(message.message)}
                        </pre>
                      )}
                    </div>

                    <div className="message-meta">
                      {formatTime(message.createdAt || message.timestamp)}
                    </div>
                  </div>
                );
              })}
            </div>
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* 输入框 */}
      <div className="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 relative">
        <form onSubmit={handleSubmit} className="flex space-x-2">
          <div className="flex-1 relative">
            <textarea
              ref={inputRef}
              value={inputMessage}
              onChange={handleInputChange}
              onKeyDown={handleKeyDown}
              onPaste={handlePaste}
              placeholder="输入消息... (支持粘贴图片，输入@提及用户)"
              className="w-full px-3 py-2 pr-20 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-lg focus:outline-none focus:ring-2 focus:ring-linux-500 focus:border-transparent text-sm resize-none"
              maxLength={500}
              rows={1}
              style={{
                minHeight: '38px',
                maxHeight: '120px',
                overflowY: inputMessage.includes('\n') ? 'auto' : 'hidden'
              }}
            />

            {/* 功能按钮组 */}
            <div className="absolute right-2 top-1/2 transform -translate-y-1/2 flex space-x-1">
              {/* 图片上传按钮 */}
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploading}
                className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors disabled:opacity-50"
                title="上传图片"
              >
                <Image size={16} />
              </button>

              {/* 表情按钮 */}
              <button
                type="button"
                onClick={toggleEmojiPicker}
                className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
                title="表情"
              >
                <Smile size={16} />
              </button>
            </div>

            {/* 隐藏的文件输入 */}
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handleImageSelect}
              className="hidden"
            />
          </div>

          <button
            type="submit"
            disabled={!inputMessage.trim() || isUploading}
            className={`px-3 py-2 rounded-lg text-white transition-colors ${
              inputMessage.trim() && !isUploading
                ? 'bg-linux-500 hover:bg-linux-600'
                : 'bg-gray-300 cursor-not-allowed'
            }`}
          >
            {isUploading ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
            ) : (
              <Send size={16} />
            )}
          </button>
        </form>



        {/* 表情选择器 */}
        {showEmojiPicker && (
          <div
            ref={emojiPickerRef}
            className="absolute bottom-full right-4 mb-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg p-3 z-50"
            style={{ width: '280px', maxHeight: '200px' }}
          >
            <div className="grid grid-cols-8 gap-1 overflow-y-auto max-h-40">
              {EMOJI_LIST.map((emoji, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => handleEmojiSelect(emoji)}
                  className="w-8 h-8 flex items-center justify-center text-lg hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* 字符计数和提示 */}
        <div className="flex justify-between items-center mt-2 text-xs text-gray-500 dark:text-gray-400">
          <span>Enter 发送 • Shift+Enter 换行</span>
          <span>{inputMessage.length}/500</span>
        </div>
      </div>
    </div>
  );
};

export default Chat;
