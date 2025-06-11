#include <stdio.h>
#include <sys/sysinfo.h>
#include <unistd.h>

int main() {
    struct sysinfo info;
    
    printf("=== 系统信息测试 ===\n");
    
    // 测试 sysinfo 系统调用
    if (sysinfo(&info) == 0) {
        printf("总内存: %lu MB\n", info.totalram / (1024 * 1024));
        printf("空闲内存: %lu MB\n", info.freeram / (1024 * 1024));
        printf("总交换: %lu MB\n", info.totalswap / (1024 * 1024));
    }
    
    // 测试 sysconf
    printf("CPU核心数 (sysconf): %ld\n", sysconf(_SC_NPROCESSORS_ONLN));
    printf("物理页面数: %ld\n", sysconf(_SC_PHYS_PAGES));
    
    // 测试 get_nprocs
    printf("CPU核心数 (get_nprocs): %d\n", get_nprocs());
    
    return 0;
}
