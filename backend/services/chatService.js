const sqlite3 = require('sqlite3').verbose();
const path = require('path');

class ChatService {
  constructor() {
    this.dbPath = path.join(__dirname, '../database/chat.db');
    this.db = null;
    // 防刷屏机制
    this.userMessageHistory = new Map(); // 用户消息历史
    this.rateLimits = {
      maxMessagesPerMinute: 10,    // 每分钟最多10条消息
      maxMessagesPerHour: 100,     // 每小时最多100条消息
      minMessageInterval: 1000,    // 最小消息间隔1秒
      maxMessageLength: 500,       // 最大消息长度500字符
      duplicateCheckCount: 5       // 检查最近5条消息是否重复
    };
  }

  /**
   * 初始化数据库
   */
  initDatabase() {
    return new Promise((resolve, reject) => {
      // 确保数据库目录存在
      const fs = require('fs');
      const dbDir = path.dirname(this.dbPath);
      if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
      }

      this.db = new sqlite3.Database(this.dbPath, (err) => {
        if (err) {
          console.error('数据库连接失败:', err);
          reject(err);
          return;
        }

        console.log('SQLite数据库连接成功');

        // 创建消息表
        this.db.run(`
          CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            message TEXT NOT NULL,
            message_type TEXT DEFAULT 'text',
            image_url TEXT,
            mentions TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        `, (err) => {
          if (err) {
            console.error('创建消息表失败:', err);
            reject(err);
            return;
          }

          // 创建点赞表
          this.db.run(`
            CREATE TABLE IF NOT EXISTS likes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              from_user TEXT NOT NULL,
              to_user TEXT NOT NULL,
              like_date TEXT NOT NULL DEFAULT (date('now')),
              timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
              created_at INTEGER DEFAULT (strftime('%s', 'now')),
              UNIQUE(from_user, to_user, like_date)
            )
          `, (err) => {
            if (err) {
              console.error('创建点赞表失败:', err);
              reject(err);
            } else {
              console.log('消息表和点赞表初始化完成');
              // 执行数据库迁移
              this.migrateDatabase().then(() => {
                resolve();
              }).catch(reject);
            }
          });
        });
      });
    });
  }

  /**
   * 数据库迁移 - 添加新字段
   */
  migrateDatabase() {
    return new Promise((resolve, reject) => {
      // 检查是否需要添加新字段
      this.db.all("PRAGMA table_info(messages)", (err, columns) => {
        if (err) {
          console.error('检查表结构失败:', err);
          reject(err);
          return;
        }

        const columnNames = columns.map(col => col.name);
        const migrations = [];

        // 检查并添加缺失的字段
        if (!columnNames.includes('message_type')) {
          migrations.push("ALTER TABLE messages ADD COLUMN message_type TEXT DEFAULT 'text'");
        }
        if (!columnNames.includes('image_url')) {
          migrations.push("ALTER TABLE messages ADD COLUMN image_url TEXT");
        }
        if (!columnNames.includes('mentions')) {
          migrations.push("ALTER TABLE messages ADD COLUMN mentions TEXT");
        }

        if (migrations.length === 0) {
          console.log('数据库表结构已是最新版本');
          resolve();
          return;
        }

        console.log(`执行 ${migrations.length} 个数据库迁移...`);

        // 执行迁移
        let completed = 0;
        migrations.forEach((migration, index) => {
          this.db.run(migration, (err) => {
            if (err) {
              console.error(`迁移失败 ${index + 1}:`, err);
              reject(err);
              return;
            }

            completed++;
            console.log(`迁移完成 ${completed}/${migrations.length}: ${migration}`);

            if (completed === migrations.length) {
              console.log('所有数据库迁移完成');
              resolve();
            }
          });
        });
      });
    });
  }

  /**
   * 检查用户是否被限制发言
   */
  checkRateLimit(username, message) {
    const now = Date.now();

    // 检查消息长度
    if (message.length > this.rateLimits.maxMessageLength) {
      return { allowed: false, reason: `消息长度不能超过${this.rateLimits.maxMessageLength}字符` };
    }

    // 检查消息是否为空或只有空白字符
    if (!message.trim()) {
      return { allowed: false, reason: '消息不能为空' };
    }

    // 获取用户历史记录
    if (!this.userMessageHistory.has(username)) {
      this.userMessageHistory.set(username, []);
    }

    const userHistory = this.userMessageHistory.get(username);

    // 清理过期记录（超过1小时的）
    const oneHourAgo = now - 60 * 60 * 1000;
    const validHistory = userHistory.filter(record => record.timestamp > oneHourAgo);

    // 检查最小消息间隔
    if (validHistory.length > 0) {
      const lastMessage = validHistory[validHistory.length - 1];
      if (now - lastMessage.timestamp < this.rateLimits.minMessageInterval) {
        return { allowed: false, reason: '发送消息过于频繁，请稍后再试' };
      }
    }

    // 检查每分钟消息数量
    const oneMinuteAgo = now - 60 * 1000;
    const messagesInLastMinute = validHistory.filter(record => record.timestamp > oneMinuteAgo);
    if (messagesInLastMinute.length >= this.rateLimits.maxMessagesPerMinute) {
      return { allowed: false, reason: `每分钟最多发送${this.rateLimits.maxMessagesPerMinute}条消息` };
    }

    // 检查每小时消息数量
    if (validHistory.length >= this.rateLimits.maxMessagesPerHour) {
      return { allowed: false, reason: `每小时最多发送${this.rateLimits.maxMessagesPerHour}条消息` };
    }

    // 检查重复消息
    const recentMessages = validHistory.slice(-this.rateLimits.duplicateCheckCount);
    const duplicateCount = recentMessages.filter(record => record.message === message).length;
    if (duplicateCount >= 2) {
      return { allowed: false, reason: '请不要重复发送相同的消息' };
    }

    // 更新用户历史记录
    validHistory.push({ message, timestamp: now });
    this.userMessageHistory.set(username, validHistory);

    return { allowed: true };
  }

  /**
   * 解析消息中的@用户
   */
  parseMentions(message) {
    const mentionRegex = /@([a-zA-Z0-9_\u4e00-\u9fa5]+)/g;
    const mentions = [];
    let match;

    while ((match = mentionRegex.exec(message)) !== null) {
      const username = match[1];
      if (!mentions.includes(username)) {
        mentions.push(username);
      }
    }

    return mentions;
  }

  /**
   * 保存聊天消息
   */
  saveMessage(username, message, messageType = 'text', imageUrl = null, mentions = null) {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      const stmt = this.db.prepare(`
        INSERT INTO messages (username, message, message_type, image_url, mentions, timestamp, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now'), strftime('%s', 'now'))
      `);

      const self = this; // 保存this引用
      stmt.run([username, message, messageType, imageUrl, mentions], function(err) {
        if (err) {
          console.error('保存消息失败:', err);
          reject(err);
        } else {
          const insertId = this.lastID;
          console.log('消息插入成功，ID:', insertId);

          // 获取刚插入的消息
          self.db.get(`
            SELECT id, username, message, message_type, image_url, mentions, timestamp, created_at
            FROM messages
            WHERE id = ?
          `, [insertId], (err, row) => {
            if (err) {
              console.error('查询插入的消息失败:', err);
              reject(err);
            } else if (!row) {
              console.error('未找到插入的消息，ID:', insertId);
              reject(new Error('未找到插入的消息'));
            } else {
              console.log('查询到插入的消息:', row);
              resolve({
                id: row.id,
                username: row.username,
                message: row.message,
                messageType: row.message_type,
                imageUrl: row.image_url,
                mentions: row.mentions ? JSON.parse(row.mentions) : null,
                timestamp: row.timestamp,
                createdAt: row.created_at * 1000 // 转换为毫秒
              });
            }
          });
        }
        stmt.finalize();
      });
    });
  }

  /**
   * 获取最近的聊天消息
   */
  getRecentMessages(limit = 10000) {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      this.db.all(`
        SELECT id, username, message, message_type, image_url, mentions, timestamp, created_at
        FROM messages
        ORDER BY created_at DESC
        LIMIT ?
      `, [limit], (err, rows) => {
        if (err) {
          console.error('获取消息失败:', err);
          reject(err);
        } else {
          const messages = rows.reverse().map(row => ({
            id: row.id,
            username: row.username,
            message: row.message,
            messageType: row.message_type,
            imageUrl: row.image_url,
            mentions: row.mentions ? JSON.parse(row.mentions) : null,
            timestamp: row.timestamp,
            createdAt: row.created_at * 1000
          }));
          resolve(messages);
        }
      });
    });
  }

  /**
   * 给用户点赞
   */
  likeUser(fromUser, toUser) {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      if (fromUser === toUser) {
        reject(new Error('不能给自己点赞'));
        return;
      }

      // 直接插入点赞记录，不检查限制
      const stmt = this.db.prepare(`
        INSERT INTO likes (from_user, to_user, like_date, timestamp, created_at)
        VALUES (?, ?, date('now'), datetime('now'), strftime('%s', 'now'))
      `);

      stmt.run([fromUser, toUser], function(err) {
        if (err) {
          console.error('保存点赞记录失败:', err);
          reject(err);
        } else {
          resolve({
            id: this.lastID,
            fromUser,
            toUser,
            timestamp: new Date().toISOString()
          });
        }
        stmt.finalize();
      });
    });
  }

  /**
   * 获取用户今日收到的点赞数
   */
  getUserLikesCount(username) {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      this.db.get(`
        SELECT COUNT(*) as count
        FROM likes
        WHERE to_user = ? AND like_date = date('now')
      `, [username], (err, row) => {
        if (err) {
          console.error('获取点赞数失败:', err);
          reject(err);
        } else {
          resolve(row.count || 0);
        }
      });
    });
  }

  /**
   * 获取所有用户的今日点赞数
   */
  getAllUsersLikesCount() {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      this.db.all(`
        SELECT to_user as username, COUNT(*) as likes
        FROM likes
        WHERE like_date = date('now')
        GROUP BY to_user
      `, [], (err, rows) => {
        if (err) {
          console.error('获取所有用户点赞数失败:', err);
          reject(err);
        } else {
          const likesMap = {};
          rows.forEach(row => {
            likesMap[row.username] = row.likes;
          });
          resolve(likesMap);
        }
      });
    });
  }

  /**
   * 清理旧消息（保留最近1000条）
   */
  cleanupOldMessages() {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('数据库未初始化'));
        return;
      }

      this.db.run(`
        DELETE FROM messages
        WHERE id NOT IN (
          SELECT id FROM messages
          ORDER BY created_at DESC
          LIMIT 1000
        )
      `, (err) => {
        if (err) {
          console.error('清理旧消息失败:', err);
          reject(err);
        } else {
          console.log('旧消息清理完成');
          resolve();
        }
      });
    });
  }

  /**
   * 关闭数据库连接
   */
  close() {
    if (this.db) {
      this.db.close((err) => {
        if (err) {
          console.error('关闭数据库失败:', err);
        } else {
          console.log('数据库连接已关闭');
        }
      });
    }
  }
}

module.exports = ChatService;
