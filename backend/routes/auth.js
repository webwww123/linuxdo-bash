const express = require('express');
const passport = require('passport');
const router = express.Router();

// Linux OAuth登录
router.get('/linux', passport.authenticate('linux'));

// Linux OAuth回调
router.get('/linux/callback',
  passport.authenticate('linux', { failureRedirect: '/login?error=auth_failed' }),
  (req, res) => {
    // 登录成功，重定向到前端
    const user = req.user;
    
    // 将用户信息存储到session
    req.session.user = {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatar: user.photos[0]?.value || null
    };
    
    // 重定向到前端，带上用户信息
    const redirectUrl = `http://localhost:3000?username=${encodeURIComponent(user.username)}&login=success`;
    res.redirect(redirectUrl);
  }
);

// 登出
router.post('/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: '登出失败' });
    }
    res.json({ success: true, message: '已成功登出' });
  });
});

// 获取当前用户信息
router.get('/user', (req, res) => {
  if (req.session.user) {
    res.json({ user: req.session.user, authenticated: true });
  } else {
    res.json({ authenticated: false });
  }
});

module.exports = router;
