/*
 * memfd-based CPU affinity hook for stealth hardware spoofing
 * 零痕迹的CPU亲和性劫持库
 * 
 * 编译: gcc -shared -fPIC -o memfd_hook.so memfd_hook.c -ldl
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

// 原始函数指针
static int (*orig_sched_getaffinity)(pid_t, size_t, cpu_set_t *) = NULL;
static long (*orig_sysconf)(int) = NULL;

// 伪装的CPU数量
#define FAKE_CPU_COUNT 24

/**
 * 劫持 sched_getaffinity 系统调用
 * 这是 nproc 命令的主要数据源
 */
int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask) {
    // 延迟加载原始函数
    if (!orig_sched_getaffinity) {
        orig_sched_getaffinity = dlsym(RTLD_NEXT, "sched_getaffinity");
        if (!orig_sched_getaffinity) {
            errno = ENOSYS;
            return -1;
        }
    }
    
    // 调用原始函数
    int result = orig_sched_getaffinity(pid, cpusetsize, mask);
    
    // 如果成功，伪造CPU掩码
    if (result == 0 && mask) {
        // 清空原始掩码
        CPU_ZERO(mask);
        
        // 设置0-23位为可用
        for (int i = 0; i < FAKE_CPU_COUNT && i < CPU_SETSIZE * 8; i++) {
            CPU_SET(i, mask);
        }
    }
    
    return result;
}

/**
 * 劫持 sysconf 系统调用（备用方案）
 * 某些程序可能直接调用 sysconf(_SC_NPROCESSORS_ONLN)
 */
long sysconf(int name) {
    // 延迟加载原始函数
    if (!orig_sysconf) {
        orig_sysconf = dlsym(RTLD_NEXT, "sysconf");
        if (!orig_sysconf) {
            errno = ENOSYS;
            return -1;
        }
    }
    
    // 拦截CPU相关的查询
    switch (name) {
        case _SC_NPROCESSORS_ONLN:    // 在线CPU数量
        case _SC_NPROCESSORS_CONF:    // 配置的CPU数量
            return FAKE_CPU_COUNT;
        default:
            return orig_sysconf(name);
    }
}

/**
 * 库初始化函数（可选）
 */
__attribute__((constructor))
static void init_hook(void) {
    // 预加载原始函数指针，避免运行时查找
    orig_sched_getaffinity = dlsym(RTLD_NEXT, "sched_getaffinity");
    orig_sysconf = dlsym(RTLD_NEXT, "sysconf");
}
