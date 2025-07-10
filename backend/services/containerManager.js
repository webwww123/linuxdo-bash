const Docker = require('dockerode');
const validator = require('validator');

class ContainerManager {
  constructor(userService) {
    this.docker = new Docker();
    this.containers = new Map(); // username -> { containerId, createdAt, lastActivity }
    this.INACTIVITY_TIMEOUT = 20 * 60 * 1000; // 20分钟不活动自动清除
    this.userService = userService;
  }

  /**
   * 验证用户名是否符合Linux用户名规则
   */
  validateUsername(username) {
    if (!username || typeof username !== 'string') {
      return false;
    }

    // Linux用户名规则：
    // - 长度1-32字符
    // - 只能包含小写字母、数字、下划线、连字符
    // - 必须以字母开头
    // - 不能以连字符结尾
    const regex = /^[a-z][a-z0-9_-]{0,31}$/;
    return regex.test(username) && !username.endsWith('-');
  }

  /**
   * 获取或创建用户容器 - 支持一人一号逻辑和密码验证
   */
  async getOrCreateContainer(username, password) {
    console.log(`getOrCreateContainer 开始: ${username}`);
    const containerName = `linux-${username}`;

    try {
      // 1. 检查用户是否已存在于数据库
      console.log(`检查用户服务: ${this.userService ? '存在' : '不存在'}`);
      if (this.userService) {
        console.log(`查询用户: ${username}`);
        const existingUser = await this.userService.getUser(username);
        console.log(`用户查询结果: ${existingUser ? '存在' : '不存在'}`);
        if (existingUser) {
          // 验证密码
          const isPasswordValid = await this.userService.verifyPassword(username, password);
          if (!isPasswordValid) {
            throw new Error('密码错误');
          }

          console.log(`用户 ${username} 已存在，密码验证通过，检查容器状态...`);

          // 检查容器是否还在运行
          const containers = await this.docker.listContainers({ all: true });
          const existingContainer = containers.find(container =>
            container.Names.some(name => name === `/${containerName}`)
          );

          if (existingContainer) {
            // 容器存在，启动它（如果未运行）
            const container = this.docker.getContainer(existingContainer.Id);
            if (existingContainer.State !== 'running') {
              console.log(`启动现有容器 ${containerName}...`);
              await container.start();
            }

            // 更新最后登录时间
            await this.userService.updateLastLogin(username);

            // 记录容器信息到内存
            this.containers.set(username, {
              containerId: existingContainer.Id,
              createdAt: Date.now(),
              lastActivity: Date.now()
            });

            return {
              containerId: existingContainer.Id,
              isNew: false,
              message: '欢迎回来！你的容器已恢复'
            };
          } else {
            // 用户存在但容器不存在，重新创建
            console.log(`用户 ${username} 的容器已丢失，重新创建...`);
            const containerId = await this.createContainer(username);

            // 更新最后登录时间
            await this.userService.updateLastLogin(username);

            this.containers.set(username, {
              containerId,
              createdAt: Date.now(),
              lastActivity: Date.now()
            });

            return {
              containerId,
              isNew: true,
              message: '你的容器已重新创建'
            };
          }
        }
      }

      // 2. 新用户，检查内存中是否有容器记录
      if (this.containers.has(username)) {
        const containerInfo = this.containers.get(username);
        try {
          const container = this.docker.getContainer(containerInfo.containerId);
          const info = await container.inspect();

          if (info.State.Running) {
            return {
              containerId: containerInfo.containerId,
              isNew: false,
              message: '容器已就绪'
            };
          }
        } catch (error) {
          // 容器不存在，从映射中移除
          this.containers.delete(username);
        }
      }

      // 3. 创建新容器
      const containerId = await this.createContainer(username);

      // 4. 记录新用户到数据库
      if (this.userService) {
        await this.userService.createUser(username, password, containerId, containerName);
        console.log(`新用户 ${username} 已注册`);
      }

      // 记录容器信息到内存
      this.containers.set(username, {
        containerId,
        createdAt: Date.now(),
        lastActivity: Date.now()
      });

      return {
        containerId,
        isNew: true,
        message: '欢迎来到Linux Analytics！'
      };
    } catch (error) {
      console.error('获取或创建容器失败:', error);
      throw error;
    }
  }

  /**
   * 创建Docker容器
   */
  async createContainer(username) {
    const containerName = `linux-${username}`;

    try {
      // 确保镜像存在
      await this.ensureImage();

      // 确保用户临时目录存在
      await this.ensureUserTempDirectory(username);

      // 检查并清理同名容器
      try {
        const existingContainer = this.docker.getContainer(containerName);
        const info = await existingContainer.inspect();
        console.log(`发现同名容器 ${containerName}，正在清理...`);

        if (info.State.Running) {
          await existingContainer.kill();
        }
        await existingContainer.remove();
        console.log(`同名容器 ${containerName} 已清理`);
      } catch (error) {
        // 容器不存在，继续创建
        console.log(`容器 ${containerName} 不存在，继续创建`);
      }

      // 创建容器 - 使用官方 Ubuntu 22.04 镜像
      const container = await this.docker.createContainer({
        Image: 'ubuntu:22.04',
        name: containerName,
        Tty: true,
        OpenStdin: true,
        StdinOnce: false,
        Env: [
          `USER=${username}`,
          'TERM=xterm-256color',
          'ENABLE_HARDWARE_FAKE=true'  // 启用专业硬件伪装
        ],
        WorkingDir: `/home/${username}`,
        Cmd: ['/bin/bash'],
        HostConfig: {
          Memory: 512 * 1024 * 1024, // 512MB内存限制
          CpuShares: 512, // CPU限制
          NetworkMode: 'bridge',
          ReadonlyRootfs: false,
          // 平衡安全配置，允许sudo但防止容器逃逸
          SecurityOpt: [
            'no-new-privileges:false',  // 允许sudo权限提升
            'apparmor:docker-default'   // 启用AppArmor
          ],
          // 更严格的权限控制
          CapDrop: ['ALL'],  // 移除所有权限
          CapAdd: ['SETUID', 'SETGID', 'DAC_OVERRIDE', 'CHOWN', 'FOWNER'],  // 只添加sudo必需的最小权限
          // 屏蔽敏感路径
          MaskedPaths: [
            '/proc/acpi',
            '/proc/kcore',
            '/proc/keys',
            '/proc/latency_stats',
            '/proc/timer_list',
            '/proc/timer_stats',
            '/proc/sched_debug',
            '/proc/scsi',
            '/sys/firmware',
            '/sys/fs/cgroup'
          ],
          ReadonlyPaths: [
            '/proc/asound',
            '/proc/bus',
            '/proc/fs',
            '/proc/irq',
            '/proc/sys',
            '/proc/sysrq-trigger'
          ],
          // 将容器数据存储到临时区
          Binds: [
            `/tmp/containers/${username}:/home/${username}:rw`,
            `/tmp/containers/${username}-var:/var/tmp:rw`
          ],
          Tmpfs: {
            '/tmp': 'rw,noexec,nosuid,size=1g'
          }
        }
      });

      // 启动容器
      await container.start();

      // 创建用户账户
      await this.setupUser(container, username);

      return container.id;
    } catch (error) {
      console.error('创建容器失败:', error);
      throw new Error('容器创建失败');
    }
  }

  /**
   * 确保基础镜像存在
   */
  async ensureImage() {
    console.log('开始检查 Ubuntu 22.04 镜像...');
    try {
      // 直接使用官方 Ubuntu 镜像，不需要构建
      await this.docker.getImage('ubuntu:22.04').inspect();
      console.log('Ubuntu 22.04 镜像已存在');
    } catch (error) {
      // 镜像不存在，拉取官方镜像
      console.log('拉取 Ubuntu 22.04 镜像...');
      await this.docker.pull('ubuntu:22.04');
      console.log('Ubuntu 22.04 镜像拉取完成');
    }
    console.log('镜像检查完成');
  }

  /**
   * 确保用户临时目录存在
   */
  async ensureUserTempDirectory(username) {
    console.log(`开始创建用户临时目录: ${username}`);
    const fs = require('fs').promises;
    const path = require('path');

    try {
      const userTempDir = `/tmp/containers/${username}`;
      const userVarDir = `/tmp/containers/${username}-var`;

      // 创建用户临时目录
      await fs.mkdir(userTempDir, { recursive: true });
      await fs.mkdir(userVarDir, { recursive: true });

      // 设置目录权限
      await fs.chmod(userTempDir, 0o755);
      await fs.chmod(userVarDir, 0o755);

      console.log(`用户临时目录已创建: ${userTempDir}`);
    } catch (error) {
      console.error('创建用户临时目录失败:', error);
      throw error;
    }
  }

  /**
   * 构建基础镜像 - 使用现有的专业硬件伪装Dockerfile
   */
  async buildImage() {
    const path = require('path');
    const projectRoot = path.resolve(__dirname, '../..');

    console.log('使用专业硬件伪装Dockerfile构建镜像...');

    const stream = await this.docker.buildImage({
      context: projectRoot,
      src: ['.']
    }, {
      t: 'linux-ubuntu:latest',
      dockerfile: 'docker/Dockerfile.ubuntu'
    });

    return new Promise((resolve, reject) => {
      this.docker.modem.followProgress(stream, (err, res) => {
        if (err) {
          console.error('构建镜像失败:', err);
          reject(err);
        } else {
          console.log('专业硬件伪装镜像构建成功');
          resolve(res);
        }
      });
    });
  }

  /**
   * 在容器中设置用户
   */
  async setupUser(container, username) {
    const commands = [
      // 硬件伪装已在ENTRYPOINT中完成，直接创建用户
      // 创建用户
      `useradd -m -s /bin/bash ${username}`,
      // 添加到sudo组
      `usermod -aG sudo ${username}`,
      // 设置安全的sudo配置
      `echo "${username} ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/snap, /usr/bin/pip, /usr/bin/pip3, /usr/bin/npm, /usr/bin/yarn, /usr/bin/systemctl, /usr/bin/service, /usr/bin/mkdir, /usr/bin/chmod, /usr/bin/chown, /usr/bin/cp, /usr/bin/mv, /usr/bin/rm, /usr/bin/ln, /usr/bin/touch, /usr/bin/cat, /usr/bin/tee, /usr/bin/whoami" >> /etc/sudoers`,
      // 禁止危险的sudo命令
      `echo "${username} ALL=(ALL) !NOPASSWD: /usr/bin/su, /bin/su, /usr/bin/sudo, /bin/sudo, /usr/bin/passwd, /bin/passwd, /usr/sbin/visudo, /usr/bin/chroot, /bin/chroot, /usr/bin/mount, /bin/mount, /usr/bin/umount, /bin/umount" >> /etc/sudoers`,
      // 设置用户目录权限
      `chown -R ${username}:${username} /home/${username}`,
      // 禁用bash超时和设置会话保持
      `echo 'unset TMOUT' >> /home/${username}/.bashrc`,
      `echo 'export TMOUT=0' >> /home/${username}/.bashrc`,
      `echo 'export HISTCONTROL=ignoredups' >> /home/${username}/.bashrc`,
      `echo 'export HISTSIZE=1000' >> /home/${username}/.bashrc`,
      `echo 'export HISTFILESIZE=2000' >> /home/${username}/.bashrc`,
      // 设置终端保持活跃
      `echo 'set +o posix' >> /home/${username}/.bashrc`,
      // 创建欢迎文件
      `cat > /home/${username}/welcome.txt << 'EOF'
=================================
   欢迎来到Linux Analytics！
=================================

系统信息:
  - Ubuntu 22.04 LTS
  - CPU: 24核心 Intel Xeon Platinum 8375C @ 2.90GHz
  - 内存: 64GB (实际限制: 512MB)
  - 存储: 1TB (映射到临时存储)
  - 容器生命周期: 2小时

当前用户: ${username}
工作目录: /home/${username} (映射到临时存储)

可用命令: ls, cd, mkdir, vim, nano, git, python3, node, npm, htop, neofetch
安装软件: sudo apt update && sudo apt install <package>

硬件信息查看:
  lscpu          # 查看CPU信息
  free -h        # 查看内存信息
  df -h          # 查看存储信息
  htop           # 系统监控
  neofetch       # 系统信息展示

注意:
- 显示的硬件信息为演示用途，实际资源有限制
- 容器使用临时存储，重启后数据会丢失
- 建议及时备份重要文件到外部存储

开始你的Linux学习之旅吧！
=================================

使用 'cat welcome.txt' 随时查看此信息
EOF`,
      `chown ${username}:${username} /home/${username}/welcome.txt`
    ];

    for (const cmd of commands) {
      try {
        const exec = await container.exec({
          Cmd: ['bash', '-c', cmd],
          AttachStdout: true,
          AttachStderr: true
        });
        await exec.start();
      } catch (error) {
        console.error(`执行命令失败: ${cmd}`, error);
      }
    }
  }

  /**
   * 获取活跃用户列表
   */
  async getActiveUsers() {
    const users = [];
    for (const [username, info] of this.containers.entries()) {
      try {
        const container = this.docker.getContainer(info.containerId);
        const containerInfo = await container.inspect();

        if (containerInfo.State.Running) {
          users.push({
            username,
            containerId: info.containerId,
            createdAt: info.createdAt,
            uptime: Date.now() - info.createdAt
          });
        }
      } catch (error) {
        // 容器不存在，从映射中移除
        this.containers.delete(username);
      }
    }
    return users;
  }

  /**
   * 重置用户容器
   */
  async resetContainer(username) {
    try {
      console.log(`重置容器: ${username}`);

      // 1. 删除现有容器
      await this.removeContainer(username);

      // 2. 创建新容器
      const containerId = await this.createContainer(username);

      // 3. 更新容器记录
      this.containers.set(username, {
        containerId,
        createdAt: Date.now(),
        lastActivity: Date.now()
      });

      console.log(`容器重置完成: ${username} -> ${containerId}`);
      return {
        containerId,
        message: '容器已重置，所有数据已清空'
      };
    } catch (error) {
      console.error('重置容器失败:', error);
      throw error;
    }
  }

  /**
   * 更新用户活动时间
   */
  updateUserActivity(username) {
    const containerInfo = this.containers.get(username);
    if (containerInfo) {
      containerInfo.lastActivity = Date.now();
    }
  }

  /**
   * 延长容器时间（重置不活动计时器）
   */
  async extendContainer(username) {
    try {
      console.log(`重置容器不活动计时器: ${username}`);

      const containerInfo = this.containers.get(username);
      if (!containerInfo) {
        throw new Error('容器不存在');
      }

      // 重置最后活动时间
      containerInfo.lastActivity = Date.now();

      console.log(`容器不活动计时器已重置: ${username}`);
      return {
        message: '容器不活动计时器已重置，将在20分钟无活动后自动清理',
        newExpireTime: Date.now() + this.INACTIVITY_TIMEOUT
      };
    } catch (error) {
      console.error('重置容器不活动计时器失败:', error);
      throw error;
    }
  }

  /**
   * 清理不活动容器
   */
  async cleanupInactiveContainers() {
    const now = Date.now();
    const inactiveUsers = [];

    for (const [username, info] of this.containers.entries()) {
      // 检查最后活动时间，如果超过20分钟没有活动则清理
      if (now - info.lastActivity > this.INACTIVITY_TIMEOUT) {
        inactiveUsers.push({
          username,
          inactiveTime: Math.round((now - info.lastActivity) / 1000 / 60) // 转换为分钟
        });
      }
    }

    for (const { username, inactiveTime } of inactiveUsers) {
      try {
        await this.removeContainer(username);
        console.log(`清理不活动容器: ${username} (不活动时间: ${inactiveTime}分钟)`);
      } catch (error) {
        console.error(`清理容器失败: ${username}`, error);
      }
    }

    if (inactiveUsers.length > 0) {
      console.log(`本次清理了 ${inactiveUsers.length} 个不活动容器`);
    }
  }

  /**
   * 移除容器
   */
  async removeContainer(username) {
    const containerInfo = this.containers.get(username);
    if (!containerInfo) return;

    try {
      const container = this.docker.getContainer(containerInfo.containerId);
      await container.kill();
      await container.remove();

      // 清理用户临时目录
      await this.cleanupUserTempDirectory(username);
    } catch (error) {
      console.error('移除容器失败:', error);
    } finally {
      this.containers.delete(username);
    }
  }

  /**
   * 清理用户临时目录
   */
  async cleanupUserTempDirectory(username) {
    const fs = require('fs').promises;
    const path = require('path');

    try {
      const userTempDir = `/tmp/containers/${username}`;
      const userVarDir = `/tmp/containers/${username}-var`;

      // 递归删除用户临时目录
      await fs.rm(userTempDir, { recursive: true, force: true });
      await fs.rm(userVarDir, { recursive: true, force: true });

      console.log(`用户临时目录已清理: ${userTempDir}`);
    } catch (error) {
      console.error('清理用户临时目录失败:', error);
      // 不抛出错误，避免影响容器删除流程
    }
  }
}

module.exports = ContainerManager;
