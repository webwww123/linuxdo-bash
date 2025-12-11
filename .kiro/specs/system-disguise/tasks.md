# Implementation Plan

- [x] 1. 创建 DisguiseConfig 和生成器基础结构

  - [x] 1.1 创建 `disguise.go` 文件，定义 DisguiseConfig 结构体和默认配置


    - 定义 CPUCores, CPUModel, CPUMHz, MemoryGB, DiskGB, GPUModel, GPUMemoryMB 字段
    - 实现 DefaultDisguiseConfig() 返回豪车配置
    - _Requirements: 3.3_
  - [x] 1.2 实现 GenerateCPUInfo 函数


    - 生成符合 /proc/cpuinfo 格式的内容
    - 根据配置的核心数生成对应数量的 processor 条目
    - _Requirements: 1.1, 3.1_

  - [x] 1.3 编写 CPU Info 生成的属性测试

    - **Property 1: CPU Info Generation Correctness**
    - **Validates: Requirements 1.1, 3.1**

  - [x] 1.4 实现 GenerateMemInfo 函数

    - 生成符合 /proc/meminfo 格式的内容
    - 正确计算 MemTotal (GB * 1024 * 1024 kB)
    - _Requirements: 1.2, 3.2_

  - [x] 1.5 编写 Memory Info 生成的属性测试

    - **Property 2: Memory Info Generation Correctness**
    - **Validates: Requirements 1.2, 3.2**
  - [x] 1.6 实现 GenerateNvidiaSmi 函数


    - 生成假的 nvidia-smi 脚本内容
    - 包含配置的 GPU 型号和显存大小
    - _Requirements: 1.6_
  - [x] 1.7 编写 GPU Info 生成的属性测试


    - **Property 5: GPU Info Generation Correctness**
    - **Validates: Requirements 1.6**

- [x] 2. 实现文件管理和挂载配置

  - [x] 2.1 实现 CreateDisguiseFiles 函数


    - 在 /tmp/lsr-disguise/user-{userID}/ 创建目录
    - 写入 cpuinfo, meminfo, nvidia-smi 文件
    - nvidia-smi 需要设置可执行权限
    - _Requirements: 2.1_
  - [x] 2.2 实现 CleanupDisguiseFiles 函数


    - 删除用户的伪装文件目录
    - _Requirements: 2.4_

  - [x] 2.3 编写文件清理的属性测试

    - **Property 4: Cleanup Removes All Files**
    - **Validates: Requirements 2.4**
  - [x] 2.4 实现 GetBindMounts 函数

    - 返回 Docker mount.Mount 配置数组
    - 挂载 cpuinfo 到 /proc/cpuinfo (只读)
    - 挂载 meminfo 到 /proc/meminfo (只读)
    - 挂载 nvidia-smi 到 /usr/bin/nvidia-smi (只读)
    - _Requirements: 2.2, 2.3_
  - [x] 2.5 编写 Bind Mount 配置的属性测试



    - **Property 3: Bind Mount Configuration Correctness**
    - **Validates: Requirements 2.2, 2.3**

- [x] 3. 集成到 DockerService

  - [x] 3.1 修改 CreateContainer 方法


    - 在创建容器前调用 CreateDisguiseFiles
    - 将 GetBindMounts 返回的挂载配置添加到 HostConfig
    - _Requirements: 2.2, 2.3_

  - [x] 3.2 修改 RemoveContainer 方法

    - 在删除容器后调用 CleanupDisguiseFiles
    - _Requirements: 2.4_

- [x] 4. Checkpoint - 确保所有测试通过



  - Ensure all tests pass, ask the user if questions arise.
