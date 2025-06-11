#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/sysinfo.h>
#include <sys/statvfs.h>
#include <sys/statfs.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sched.h>

// 伪装配置
#define FAKE_CPU_CORES 24
#define FAKE_MEMORY_GB 64ULL
#define FAKE_STORAGE_TB 1ULL

// 内存相关伪装
typedef int (*sysinfo_t)(struct sysinfo *);
int sysinfo(struct sysinfo *info) {
    static sysinfo_t real_sysinfo = NULL;
    if (!real_sysinfo) {
        real_sysinfo = (sysinfo_t)dlsym(RTLD_NEXT, "sysinfo");
    }
    
    int result = real_sysinfo(info);
    if (result == 0) {
        // 伪装内存信息 - 64GB
        info->totalram = FAKE_MEMORY_GB * 1024ULL * 1024ULL * 1024ULL;
        info->freeram = info->totalram / 2;  // 假设50%空闲
        info->bufferram = info->totalram / 20;  // 5%用于缓冲
        info->sharedram = info->totalram / 100; // 1%共享
        
        // 伪装交换空间
        info->totalswap = info->totalram / 2;   // 32GB交换
        info->freeswap = info->totalswap;
        
        // 保持其他字段不变
    }
    return result;
}

// 存储相关伪装 - statvfs
typedef int (*statvfs_t)(const char *, struct statvfs *);
int statvfs(const char *path, struct statvfs *buf) {
    static statvfs_t real_statvfs = NULL;
    if (!real_statvfs) {
        real_statvfs = (statvfs_t)dlsym(RTLD_NEXT, "statvfs");
    }
    
    int result = real_statvfs(path, buf);
    if (result == 0) {
        // 伪装存储信息 - 1TB
        unsigned long long total_bytes = FAKE_STORAGE_TB * 1024ULL * 1024ULL * 1024ULL * 1024ULL;
        unsigned long long blocks = total_bytes / buf->f_bsize;
        
        buf->f_blocks = blocks;
        buf->f_bfree = blocks / 2;    // 50%空闲
        buf->f_bavail = blocks / 2;   // 50%可用
        
        // 保持其他字段合理
        buf->f_files = blocks / 1000;  // 合理的inode数量
        buf->f_ffree = buf->f_files / 2;
    }
    return result;
}

// 存储相关伪装 - statfs
typedef int (*statfs_t)(const char *, struct statfs *);
int statfs(const char *path, struct statfs *buf) {
    static statfs_t real_statfs = NULL;
    if (!real_statfs) {
        real_statfs = (statfs_t)dlsym(RTLD_NEXT, "statfs");
    }
    
    int result = real_statfs(path, buf);
    if (result == 0) {
        // 伪装存储信息 - 1TB
        unsigned long long total_bytes = FAKE_STORAGE_TB * 1024ULL * 1024ULL * 1024ULL * 1024ULL;
        unsigned long long blocks = total_bytes / buf->f_bsize;
        
        buf->f_blocks = blocks;
        buf->f_bfree = blocks / 2;
        buf->f_bavail = blocks / 2;
        
        buf->f_files = blocks / 1000;
        buf->f_ffree = buf->f_files / 2;
    }
    return result;
}

// CPU核心数伪装
typedef long (*sysconf_t)(int);
long sysconf(int name) {
    static sysconf_t real_sysconf = NULL;
    if (!real_sysconf) {
        real_sysconf = (sysconf_t)dlsym(RTLD_NEXT, "sysconf");
    }
    
    long result = real_sysconf(name);
    
    // 伪装CPU相关的sysconf调用
    switch (name) {
        case _SC_NPROCESSORS_ONLN:  // 在线处理器数量
        case _SC_NPROCESSORS_CONF:  // 配置的处理器数量
            return FAKE_CPU_CORES;
        case _SC_PHYS_PAGES:        // 物理页面数
            return (FAKE_MEMORY_GB * 1024ULL * 1024ULL * 1024ULL) / sysconf(_SC_PAGESIZE);
        case _SC_AVPHYS_PAGES:      // 可用物理页面数
            return sysconf(_SC_PHYS_PAGES) / 2;
        default:
            return result;
    }
}

// openat系统调用劫持 - 处理/sys/devices/system/cpu访问
typedef int (*openat_t)(int, const char *, int, ...);
int openat(int dirfd, const char *pathname, int flags, ...) {
    static openat_t real_openat = NULL;
    if (!real_openat) {
        real_openat = (openat_t)dlsym(RTLD_NEXT, "openat");
    }

    // 处理对关键CPU文件的访问
    if (pathname) {
        // 重定向关键的CPU信息文件
        if (strcmp(pathname, "online") == 0 ||
            strcmp(pathname, "present") == 0 ||
            strcmp(pathname, "possible") == 0) {
            // 检查是否在/sys/devices/system/cpu目录下
            char cwd_buf[1024];
            if (dirfd != AT_FDCWD) {
                char fd_path[64];
                sprintf(fd_path, "/proc/self/fd/%d", dirfd);
                ssize_t len = readlink(fd_path, cwd_buf, sizeof(cwd_buf) - 1);
                if (len > 0) {
                    cwd_buf[len] = '\0';
                    if (strstr(cwd_buf, "/sys/devices/system/cpu") != NULL) {
                        // 重定向到我们的伪造文件
                        char fake_path[256];
                        sprintf(fake_path, "/opt/fakesys/devices/system/cpu/%s", pathname);

                        if (flags & O_CREAT) {
                            va_list args;
                            va_start(args, flags);
                            mode_t mode = va_arg(args, int);
                            va_end(args);
                            return real_openat(AT_FDCWD, fake_path, flags, mode);
                        } else {
                            return real_openat(AT_FDCWD, fake_path, flags);
                        }
                    }
                }
            }
        }
    }

    // 处理可变参数
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, int);
        va_end(args);
        return real_openat(dirfd, pathname, flags, mode);
    } else {
        return real_openat(dirfd, pathname, flags);
    }
}

// 文件读取伪装 - 用于处理一些直接读取/proc的情况
typedef int (*open_t)(const char *, int, ...);
int open(const char *pathname, int flags, ...) {
    static open_t real_open = NULL;
    if (!real_open) {
        real_open = (open_t)dlsym(RTLD_NEXT, "open");
    }

    // 对于某些特殊的proc文件，重定向到我们的伪造文件
    if (pathname && strstr(pathname, "/proc/") == pathname) {
        // 这里可以添加特殊处理，但主要依赖OverlayFS
        // 只处理一些边缘情况
    }

    // 处理可变参数
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, int);  // mode_t 通过 int 传递
        va_end(args);
        return real_open(pathname, flags, mode);
    } else {
        return real_open(pathname, flags);
    }
}

// 增强的CPU核心数获取函数
typedef int (*sched_getaffinity_t)(pid_t, size_t, cpu_set_t *);
int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask) {
    static sched_getaffinity_t real_sched_getaffinity = NULL;
    if (!real_sched_getaffinity) {
        real_sched_getaffinity = (sched_getaffinity_t)dlsym(RTLD_NEXT, "sched_getaffinity");
    }

    int result = real_sched_getaffinity(pid, cpusetsize, mask);
    if (result == 0 && mask) {
        // 清空原有的CPU集合
        CPU_ZERO(mask);
        // 设置24个CPU
        for (int i = 0; i < FAKE_CPU_CORES && i < CPU_SETSIZE; i++) {
            CPU_SET(i, mask);
        }
    }
    return result;
}

// 获取处理器数量的替代函数
typedef int (*get_nprocs_t)(void);
int get_nprocs(void) {
    return FAKE_CPU_CORES;
}

int get_nprocs_conf(void) {
    return FAKE_CPU_CORES;
}

// 构造函数 - 库加载时执行
__attribute__((constructor))
void libfakehw_init(void) {
    // 可以在这里做一些初始化工作
    // 比如设置环境变量等
    setenv("FAKEHW_LOADED", "1", 1);
}

// 析构函数 - 库卸载时执行
__attribute__((destructor))
void libfakehw_cleanup(void) {
    // 清理工作
    unsetenv("FAKEHW_LOADED");
}
