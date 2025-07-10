#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <stdarg.h>

// 伪造的硬件信息
static const char* fake_cpuinfo = 
"processor\t: 0\n"
"vendor_id\t: GenuineIntel\n"
"cpu family\t: 6\n"
"model\t\t: 165\n"
"model name\t: Intel(R) Core(TM) i9-13900K CPU @ 3.00GHz\n"
"stepping\t: 2\n"
"microcode\t: 0x129\n"
"cpu MHz\t\t: 3000.000\n"
"cache size\t: 36864 KB\n"
"physical id\t: 0\n"
"siblings\t: 24\n"
"core id\t\t: 0\n"
"cpu cores\t: 24\n"
"apicid\t\t: 0\n"
"initial apicid\t: 0\n"
"fpu\t\t: yes\n"
"fpu_exception\t: yes\n"
"cpuid level\t: 27\n"
"wp\t\t: yes\n"
"flags\t\t: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single intel_ppin ssbd mba ibrs ibpb stibp ibrs_enhanced tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid cqm mpx rdt_a avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb intel_pt avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local split_lock_detect wbnoinvd dtherm ida arat pln pts avx512vbmi umip pku ospke avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg tme avx512_vpopcntdq la57 rdpid fsrm md_clear pconfig flush_l1d arch_capabilities\n"
"vmx flags\t: vnmi preemption_timer posted_intr invvpid ept_x_only ept_ad ept_1gb flexpriority apicv tsc_offset vtpr mtf vapic ept vpid unrestricted_guest vapic_reg vid ple shadow_vmcs ept_mode_based_exec tsc_scaling usr_wait_pause\n"
"bugs\t\t: spectre_v1 spectre_v2 spec_store_bypass swapgs eibrs_pbrsb\n"
"bogomips\t: 6000.00\n"
"clflush size\t: 64\n"
"cache_alignment\t: 64\n"
"address sizes\t: 39 bits physical, 48 bits virtual\n"
"power management:\n\n";

static const char* fake_meminfo =
"MemTotal:       65536000 kB\n"
"MemFree:        32768000 kB\n"
"MemAvailable:   58720000 kB\n"
"Buffers:         2048000 kB\n"
"Cached:         16384000 kB\n"
"SwapCached:            0 kB\n"
"Active:         20480000 kB\n"
"Inactive:        8192000 kB\n"
"Active(anon):   12288000 kB\n"
"Inactive(anon):  1024000 kB\n"
"Active(file):    8192000 kB\n"
"Inactive(file):  7168000 kB\n"
"Unevictable:           0 kB\n"
"Mlocked:               0 kB\n"
"SwapTotal:      16777216 kB\n"
"SwapFree:       16777216 kB\n"
"Dirty:               128 kB\n"
"Writeback:             0 kB\n"
"AnonPages:      12582912 kB\n"
"Mapped:          2097152 kB\n"
"Shmem:           1048576 kB\n"
"KReclaimable:    4194304 kB\n"
"Slab:            2097152 kB\n"
"SReclaimable:    4194304 kB\n"
"SUnreclaim:       524288 kB\n"
"KernelStack:       32768 kB\n"
"PageTables:       262144 kB\n"
"NFS_Unstable:          0 kB\n"
"Bounce:                0 kB\n"
"WritebackTmp:          0 kB\n"
"CommitLimit:    49545216 kB\n"
"Committed_AS:   20971520 kB\n"
"VmallocTotal:   34359738367 kB\n"
"VmallocUsed:      131072 kB\n"
"VmallocChunk:          0 kB\n"
"Percpu:            65536 kB\n"
"HardwareCorrupted:     0 kB\n"
"AnonHugePages:   8388608 kB\n"
"ShmemHugePages:        0 kB\n"
"ShmemPmdMapped:        0 kB\n"
"FileHugePages:         0 kB\n"
"FilePmdMapped:         0 kB\n"
"CmaTotal:              0 kB\n"
"CmaFree:               0 kB\n"
"HugePages_Total:       0\n"
"HugePages_Free:        0\n"
"HugePages_Rsvd:        0\n"
"HugePages_Surp:        0\n"
"Hugepagesize:       2048 kB\n"
"Hugetlb:               0 kB\n"
"DirectMap4k:     4194304 kB\n"
"DirectMap2M:    62914560 kB\n"
"DirectMap1G:           0 kB\n";

// 伪造的 /proc/stat 信息（htop 使用）
static const char* fake_stat =
"cpu  1000000 2000000 3000000 4000000 5000000 6000000 7000000 0 0 0\n"
"cpu0 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu1 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu2 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu3 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu4 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu5 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu6 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu7 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu8 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu9 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu10 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu11 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu12 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu13 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu14 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu15 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu16 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu17 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu18 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu19 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu20 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu21 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu22 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"cpu23 41666 83333 125000 166666 208333 250000 291666 0 0 0\n"
"intr 1000000000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n"
"ctxt 2000000000\n"
"btime 1640995200\n"
"processes 500000\n"
"procs_running 2\n"
"procs_blocked 0\n"
"softirq 100000000 0 0 0 0 0 0 0 0 0 0\n";

// 函数指针类型定义
typedef int (*orig_open_f_type)(const char *pathname, int flags, ...);
typedef int (*orig_openat_f_type)(int dirfd, const char *pathname, int flags, ...);
typedef ssize_t (*orig_read_f_type)(int fd, void *buf, size_t count);
typedef FILE* (*orig_fopen_f_type)(const char *pathname, const char *mode);
typedef size_t (*orig_fread_f_type)(void *ptr, size_t size, size_t nmemb, FILE *stream);

// 拦截 open 函数
int open(const char *pathname, int flags, ...) {
    // 检查是否访问硬件信息文件
    if (pathname) {
        if (strcmp(pathname, "/proc/cpuinfo") == 0 || strcmp(pathname, "/proc/meminfo") == 0 || strcmp(pathname, "/proc/stat") == 0) {
            // 创建临时文件来存储伪造信息
            char template[] = "/tmp/fake_hw_XXXXXX";
            int fake_fd = mkstemp(template);
            if (fake_fd != -1) {
                const char* fake_content;
                if (strcmp(pathname, "/proc/cpuinfo") == 0) {
                    fake_content = fake_cpuinfo;
                } else if (strcmp(pathname, "/proc/meminfo") == 0) {
                    fake_content = fake_meminfo;
                } else if (strcmp(pathname, "/proc/stat") == 0) {
                    fake_content = fake_stat;
                }
                write(fake_fd, fake_content, strlen(fake_content));
                lseek(fake_fd, 0, SEEK_SET);
                unlink(template); // 删除文件名，但保持文件描述符有效
                return fake_fd;
            }
        }
        // 拦截 /sys/devices/system/cpu/ 相关文件
        else if (strstr(pathname, "/sys/devices/system/cpu/") != NULL) {
            // 对于 CPU 相关的 sys 文件，返回伪造信息
            if (strstr(pathname, "/sys/devices/system/cpu/online") != NULL) {
                char template[] = "/tmp/fake_cpu_online_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5); // 24 核心 (0-23)
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
            else if (strstr(pathname, "/sys/devices/system/cpu/present") != NULL) {
                char template[] = "/tmp/fake_cpu_present_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5); // 24 核心 (0-23)
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
            else if (strstr(pathname, "/sys/devices/system/cpu/possible") != NULL) {
                char template[] = "/tmp/fake_cpu_possible_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5); // 24 核心 (0-23)
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
        }
    }
    
    // 调用原始 open 函数
    orig_open_f_type orig_open = (orig_open_f_type)dlsym(RTLD_NEXT, "open");
    
    // 处理可变参数
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig_open(pathname, flags, mode);
    } else {
        return orig_open(pathname, flags);
    }
}

// 拦截 openat 函数 (现代程序更多使用这个)
int openat(int dirfd, const char *pathname, int flags, ...) {
    // 检查是否访问硬件信息文件
    if (pathname) {
        if (strcmp(pathname, "/proc/cpuinfo") == 0 || strcmp(pathname, "/proc/meminfo") == 0 || strcmp(pathname, "/proc/stat") == 0) {
            // 创建临时文件来存储伪造信息
            char template[] = "/tmp/fake_hw_XXXXXX";
            int fake_fd = mkstemp(template);
            if (fake_fd != -1) {
                const char* fake_content;
                if (strcmp(pathname, "/proc/cpuinfo") == 0) {
                    fake_content = fake_cpuinfo;
                } else if (strcmp(pathname, "/proc/meminfo") == 0) {
                    fake_content = fake_meminfo;
                } else if (strcmp(pathname, "/proc/stat") == 0) {
                    fake_content = fake_stat;
                }
                write(fake_fd, fake_content, strlen(fake_content));
                lseek(fake_fd, 0, SEEK_SET);
                unlink(template);
                return fake_fd;
            }
        }
        // 拦截 /sys/devices/system/cpu/ 相关文件
        else if (strstr(pathname, "/sys/devices/system/cpu/") != NULL) {
            if (strstr(pathname, "/sys/devices/system/cpu/online") != NULL) {
                char template[] = "/tmp/fake_cpu_online_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5);
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
            else if (strstr(pathname, "/sys/devices/system/cpu/present") != NULL) {
                char template[] = "/tmp/fake_cpu_present_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5);
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
            else if (strstr(pathname, "/sys/devices/system/cpu/possible") != NULL) {
                char template[] = "/tmp/fake_cpu_possible_XXXXXX";
                int fake_fd = mkstemp(template);
                if (fake_fd != -1) {
                    write(fake_fd, "0-23\n", 5);
                    lseek(fake_fd, 0, SEEK_SET);
                    unlink(template);
                    return fake_fd;
                }
            }
        }
    }

    // 调用原始 openat 函数
    orig_openat_f_type orig_openat = (orig_openat_f_type)dlsym(RTLD_NEXT, "openat");

    // 处理可变参数
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig_openat(dirfd, pathname, flags, mode);
    } else {
        return orig_openat(dirfd, pathname, flags);
    }
}

// 拦截 fopen 函数
FILE* fopen(const char *pathname, const char *mode) {
    // 检查是否访问硬件信息文件
    if (pathname && (strcmp(pathname, "/proc/cpuinfo") == 0 || strcmp(pathname, "/proc/meminfo") == 0 || strcmp(pathname, "/proc/stat") == 0)) {
        // 创建临时文件
        char template[] = "/tmp/fake_hw_XXXXXX";
        int fake_fd = mkstemp(template);
        if (fake_fd != -1) {
            const char* fake_content;
            if (strcmp(pathname, "/proc/cpuinfo") == 0) {
                fake_content = fake_cpuinfo;
            } else if (strcmp(pathname, "/proc/meminfo") == 0) {
                fake_content = fake_meminfo;
            } else if (strcmp(pathname, "/proc/stat") == 0) {
                fake_content = fake_stat;
            }
            write(fake_fd, fake_content, strlen(fake_content));
            lseek(fake_fd, 0, SEEK_SET);
            unlink(template);
            return fdopen(fake_fd, mode);
        }
    }
    
    // 调用原始 fopen 函数
    orig_fopen_f_type orig_fopen = (orig_fopen_f_type)dlsym(RTLD_NEXT, "fopen");
    return orig_fopen(pathname, mode);
}
