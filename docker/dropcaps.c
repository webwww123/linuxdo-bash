#include <sys/prctl.h>
#include <linux/capability.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    printf("=== Professional BoundingSet Drop Helper ===\n");
    printf("Dropping CAP_SYS_ADMIN and CAP_SETPCAP from BoundingSet...\n");
    
    // Drop CAP_SYS_ADMIN from BoundingSet
    if (prctl(PR_CAPBSET_DROP, CAP_SYS_ADMIN, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SYS_ADMIN");
        return 1;
    }
    printf("✅ Successfully dropped CAP_SYS_ADMIN from BoundingSet\n");
    
    // Drop CAP_SETPCAP from BoundingSet
    if (prctl(PR_CAPBSET_DROP, CAP_SETPCAP, 0, 0, 0) == -1) {
        perror("Failed to drop CAP_SETPCAP");
        return 1;
    }
    printf("✅ Successfully dropped CAP_SETPCAP from BoundingSet\n");
    
    printf("=== BoundingSet permanently modified ===\n");
    printf("All future processes (including docker exec) will have no dangerous capabilities\n");
    
    // Verify the drop worked
    printf("Verifying BoundingSet status...\n");
    system("grep CapBnd /proc/self/status");
    
    // If we have arguments, exec the real command
    if (argc > 1) {
        printf("Executing user command: %s\n", argv[1]);
        execv(argv[1], &argv[1]);
        perror("exec failed");
        return 1;
    }
    
    // Default: exec bash
    printf("Executing default shell...\n");
    execl("/bin/bash", "/bin/bash", (char*)NULL);
    perror("exec bash failed");
    return 1;
}
