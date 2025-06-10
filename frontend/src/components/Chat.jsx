import React, { useState, useRef, useEffect } from 'react';
import { Send, MessageCircle, Smile, Image, AtSign } from 'lucide-react';
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
  const [showMentionList, setShowMentionList] = useState(false);
  const [mentionFilter, setMentionFilter] = useState('');
  const [userAvatars, setUserAvatars] = useState({});
  const [isUploading, setIsUploading] = useState(false);
  const messagesEndRef = useRef(null);
  const messagesContainerRef = useRef(null);
  const inputRef = useRef(null);
  const emojiPickerRef = useRef(null);
  const mentionListRef = useRef(null);
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
      if (mentionListRef.current && !mentionListRef.current.contains(event.target)) {
        setShowMentionList(false);
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
    setShowMentionList(false);
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

  // 监听输入变化，自动调整高度和处理@功能
  const handleInputChange = (e) => {
    const value = e.target.value;
    setInputMessage(value);
    adjustTextareaHeight(e.target);

    // 检查是否输入了@符号
    const cursorPosition = e.target.selectionStart;
    const textBeforeCursor = value.substring(0, cursorPosition);
    const atMatch = textBeforeCursor.match(/@([a-zA-Z0-9_\u4e00-\u9fa5]*)$/);

    if (atMatch) {
      setMentionFilter(atMatch[1]);
      setShowMentionList(true);
    } else {
      setShowMentionList(false);
      setMentionFilter('');
    }
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
        // 构建完整的图片URL - 指向后端服务器
        const backendUrl = 'http://localhost:3001';
        const fullImageUrl = backendUrl + result.imageUrl;
        console.log('发送图片消息:', { imageUrl: fullImageUrl });

        // 发送图片消息
        onSendMessage({
          message: '',
          messageType: 'image',
          imageUrl: fullImageUrl
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

  // 选择@用户
  const selectMention = (username) => {
    const cursorPosition = inputRef.current.selectionStart;
    const textBeforeCursor = inputMessage.substring(0, cursorPosition);
    const textAfterCursor = inputMessage.substring(cursorPosition);

    // 找到@符号的位置
    const atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex !== -1) {
      const newText = textBeforeCursor.substring(0, atIndex) + `@${username} ` + textAfterCursor;
      setInputMessage(newText);
      setShowMentionList(false);
      setMentionFilter('');

      // 设置光标位置
      setTimeout(() => {
        const newCursorPos = atIndex + username.length + 2;
        inputRef.current.setSelectionRange(newCursorPos, newCursorPos);
        inputRef.current.focus();
      }, 0);
    }
  };

  // 过滤用户列表
  const filteredUsers = activeUsers.filter(user =>
    user !== currentUsername &&
    user.toLowerCase().includes(mentionFilter.toLowerCase())
  );

  // 渲染带@高亮的消息
  const renderMessageWithMentions = (text) => {
    if (!text) return '';

    const mentionRegex = /@([a-zA-Z0-9_\u4e00-\u9fa5]+)/g;
    const parts = [];
    let lastIndex = 0;
    let match;

    while ((match = mentionRegex.exec(text)) !== null) {
      // 添加@之前的文本
      if (match.index > lastIndex) {
        parts.push(text.substring(lastIndex, match.index));
      }

      // 添加@用户（高亮显示）
      const mentionedUser = match[1];
      const isCurrentUser = mentionedUser === currentUsername;
      parts.push(
        <span
          key={match.index}
          className={`font-semibold ${
            isCurrentUser
              ? 'text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900 px-1 rounded'
              : 'text-green-600 dark:text-green-400'
          }`}
        >
          @{mentionedUser}
        </span>
      );

      lastIndex = match.index + match[0].length;
    }

    // 添加剩余文本
    if (lastIndex < text.length) {
      parts.push(text.substring(lastIndex));
    }

    return parts.length > 1 ? parts : text;
  };

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
                            src={message.imageUrl}
                            alt="聊天图片"
                            className="max-w-xs max-h-64 rounded-lg cursor-pointer hover:opacity-90 transition-opacity"
                            onClick={() => window.open(message.imageUrl, '_blank')}
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
              {/* @用户按钮 */}
              <button
                type="button"
                onClick={() => setShowMentionList(!showMentionList)}
                className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
                title="@用户"
              >
                <AtSign size={16} />
              </button>

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

        {/* @用户列表 */}
        {showMentionList && filteredUsers.length > 0 && (
          <div
            ref={mentionListRef}
            className="absolute bottom-full left-4 mb-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg py-2 z-50"
            style={{ width: '200px', maxHeight: '200px' }}
          >
            <div className="text-xs text-gray-500 dark:text-gray-400 px-3 py-1 border-b border-gray-200 dark:border-gray-600">
              选择用户
            </div>
            <div className="overflow-y-auto max-h-40">
              {filteredUsers.map((user) => (
                <button
                  key={user}
                  type="button"
                  onClick={() => selectMention(user)}
                  className="w-full px-3 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors flex items-center space-x-2"
                >
                  <div className={`w-6 h-6 ${getUserAvatarColor(user, userAvatars[user])} text-white rounded-full flex items-center justify-center text-xs font-medium`}>
                    {getUserInitial(user, userAvatars[user])}
                  </div>
                  <span className="text-sm">{user}</span>
                </button>
              ))}
            </div>
          </div>
        )}

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
