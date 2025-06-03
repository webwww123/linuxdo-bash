const OAuth2Strategy = require('passport-oauth2');
const axios = require('axios');
const oauthConfig = require('../config/oauth');

class LinuxStrategy extends OAuth2Strategy {
  constructor(options, verify) {
    super({
      authorizationURL: options.authorizationURL,
      tokenURL: options.tokenURL,
      clientID: options.clientID,
      clientSecret: options.clientSecret,
      callbackURL: options.callbackURL,
      scope: options.scope
    }, verify);

    this.name = 'linux';
    this._userInfoURL = options.userInfoURL;
  }

  async userProfile(accessToken, done) {
    try {
      const response = await axios.get(this._userInfoURL, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'User-Agent': 'Linux-Analytics/1.0'
        }
      });

      const profile = {
        provider: 'linux',
        id: response.data.id,
        username: response.data.username,
        displayName: response.data.name || response.data.username,
        emails: response.data.email ? [{ value: response.data.email }] : [],
        photos: response.data.avatar_url ? [{ value: response.data.avatar_url }] : [],
        _raw: response.data,
        _json: response.data
      };

      done(null, profile);
    } catch (error) {
      console.error('获取Linux用户信息失败:', error.response?.data || error.message);
      done(error);
    }
  }
}

module.exports = LinuxStrategy;
