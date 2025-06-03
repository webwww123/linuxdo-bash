// Linux OAuth2 配置
module.exports = {
  linux: {
    // 使用测试用的Client ID（从Linux社区文档获取）
    clientID: process.env.LINUX_CLIENT_ID || 'hi3geJYfTotoiR5S62u3rh4W5tSeC5UG',
    clientSecret: process.env.LINUX_CLIENT_SECRET || 'your_client_secret_here',

    // Linux OAuth2 端点
    authorizationURL: 'https://connect.linux.do/oauth2/authorize',
    tokenURL: 'https://connect.linux.do/oauth2/token',
    userInfoURL: 'https://connect.linux.do/api/user',

    // 回调地址
    callbackURL: process.env.CALLBACK_URL || 'http://localhost:3001/auth/linux/callback',

    // OAuth2 scope
    scope: ['read']
  }
};
