const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.GRAFANA_PORT || 8080;

// 中间件
app.use(express.static(path.join(__dirname, 'public')));

// 主页面 - 伪装的Grafana界面
app.get('/', (req, res) => {
  const htmlPath = path.join(__dirname, 'grafana-mock.html');
  res.sendFile(htmlPath);
});

// API端点 - 模拟Grafana API
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '9.5.2',
    commit: 'a1b2c3d4',
    database: 'ok',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/datasources', (req, res) => {
  res.json([
    {
      id: 1,
      name: 'Prometheus',
      type: 'prometheus',
      url: 'http://localhost:9090',
      access: 'proxy',
      isDefault: true
    },
    {
      id: 2,
      name: 'InfluxDB',
      type: 'influxdb',
      url: 'http://localhost:8086',
      access: 'proxy',
      database: 'metrics'
    }
  ]);
});

app.get('/api/dashboards/search', (req, res) => {
  res.json([
    {
      id: 1,
      title: 'ML Container Analytics',
      tags: ['ml', 'containers', 'monitoring'],
      type: 'dash-db',
      uri: 'db/ml-container-analytics'
    },
    {
      id: 2,
      title: 'System Performance',
      tags: ['system', 'performance'],
      type: 'dash-db',
      uri: 'db/system-performance'
    },
    {
      id: 3,
      title: 'Resource Utilization',
      tags: ['resources', 'utilization'],
      type: 'dash-db',
      uri: 'db/resource-utilization'
    }
  ]);
});

app.get('/api/alerts', (req, res) => {
  res.json([
    {
      id: 1,
      name: 'High CPU Usage',
      state: 'ok',
      newStateDate: new Date().toISOString(),
      evalDate: new Date().toISOString(),
      executionError: '',
      url: '/d/alerts/high-cpu'
    },
    {
      id: 2,
      name: 'Memory Usage Warning',
      state: 'alerting',
      newStateDate: new Date(Date.now() - 300000).toISOString(),
      evalDate: new Date().toISOString(),
      executionError: '',
      url: '/d/alerts/memory-warning'
    }
  ]);
});

app.get('/api/annotations', (req, res) => {
  res.json([
    {
      id: 1,
      time: Date.now() - 3600000,
      timeEnd: Date.now() - 3500000,
      text: 'Container deployment started',
      tags: ['deployment', 'container']
    },
    {
      id: 2,
      time: Date.now() - 1800000,
      timeEnd: Date.now() - 1700000,
      text: 'System maintenance completed',
      tags: ['maintenance', 'system']
    }
  ]);
});

// 模拟查询API
app.post('/api/ds/query', (req, res) => {
  // 模拟时序数据
  const now = Date.now();
  const dataPoints = [];
  
  for (let i = 0; i < 100; i++) {
    dataPoints.push([
      Math.random() * 100, // 随机值
      now - (i * 60000) // 时间戳（每分钟一个点）
    ]);
  }
  
  res.json({
    results: {
      A: {
        frames: [{
          schema: {
            fields: [
              { name: 'Time', type: 'time' },
              { name: 'Value', type: 'number' }
            ]
          },
          data: {
            values: [
              dataPoints.map(p => p[1]),
              dataPoints.map(p => p[0])
            ]
          }
        }]
      }
    }
  });
});

// 登录页面（伪装）
app.get('/login', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Grafana Analytics - Sign In</title>
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #0f1419; 
                color: #d9d9d9; 
                display: flex; 
                justify-content: center; 
                align-items: center; 
                height: 100vh; 
                margin: 0; 
            }
            .login-form { 
                background: #1f2937; 
                padding: 40px; 
                border-radius: 8px; 
                border: 1px solid #374151;
                width: 400px;
            }
            .logo { 
                text-align: center; 
                margin-bottom: 30px; 
                font-size: 24px; 
                font-weight: 600; 
            }
            input { 
                width: 100%; 
                padding: 12px; 
                margin: 10px 0; 
                background: #374151; 
                border: 1px solid #4b5563; 
                border-radius: 4px; 
                color: #f3f4f6;
                box-sizing: border-box;
            }
            button { 
                width: 100%; 
                padding: 12px; 
                background: #f97316; 
                border: none; 
                border-radius: 4px; 
                color: white; 
                font-weight: 600;
                cursor: pointer;
                margin-top: 20px;
            }
            button:hover { background: #ea580c; }
        </style>
    </head>
    <body>
        <div class="login-form">
            <div class="logo">🔧 Grafana Analytics</div>
            <form onsubmit="window.location.href='/'; return false;">
                <input type="text" placeholder="Username" required>
                <input type="password" placeholder="Password" required>
                <button type="submit">Sign In</button>
            </form>
        </div>
    </body>
    </html>
  `);
});

// 404处理
app.use((req, res) => {
  res.status(404).json({
    message: 'Grafana API endpoint not found',
    status: 404,
    timestamp: new Date().toISOString()
  });
});

// 错误处理
app.use((err, req, res, next) => {
  console.error('Grafana server error:', err);
  res.status(500).json({
    message: 'Internal server error',
    status: 500,
    timestamp: new Date().toISOString()
  });
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`🔧 Grafana Analytics服务器运行在端口 ${PORT}`);
  console.log(`📊 访问地址: http://localhost:${PORT}`);
});

module.exports = app;
