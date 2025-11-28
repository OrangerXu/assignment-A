# MapReduce Reduce任务启动策略研究

## 研究目的

探究MapReduce中Reduce任务的启动时机及其对作业性能的影响。

## 研究内容

分析Reduce任务的启动时机。具体包括：
- Reduce是否在所有Map任务完成后才开始执行？
- 不同的启动时机将如何影响整个job的执行效率与资源利用率？

> **思路**：
> - 选取合适的计算负载，在不同规模的数据集中调整Reduce任务的启动时机。
> - 通过记录CPU利用率、内存使用量及作业执行时间等指标，分析Reduce启动时机对MapReduce作业性能的影响。

## 实验

### 实验环境

- **硬件**：
  - 节点数：4
  - 每节点配置：2 vCores / 4 GB 内存
  - 网络：千兆以太网
  - 存储：SSD
  - 总集群资源：8 vCores / 16 GB 内存
- **软件**：
  - 操作系统：CentOS7 Linux
  - JDK 版本：1.8.0_212
  - Hadoop 版本：3.3.5

### 实验负载

- **数据集**：使用 `dd + /dev/urandom + base64` 在本地磁盘（`/root`）生成纯文本数据，并上传至 HDFS，确保不占用 `/tmp` 内存盘。
  - `1MB`：极小规模，用于验证策略在微负载下的行为。
  - `100MB`：中等规模，用于观察典型性能差异。
  - `1GB`：大规模，用于测试策略在重负载下的表现。
- **工作负载**：Hadoop 自带 `WordCount` 程序，Reduce 任务数固定为 `4`。

### 实验步骤

1.  **部署 Hadoop 集群**：在 4 台节点上成功部署 Hadoop 3.3.5。
2.  **编写独立测试脚本**：为每种数据规模（1MB, 100MB, 1GB）分别编写独立的 Bash 脚本，以避免资源竞争和系统卡死。
   脚本链接：
    - [code/run_test_1mb.sh](code/run_test_1mb.sh) 
    - [code/run_test_100mb.sh](code/run_test_100mb.sh) 
    - [code/run_test_1gb.sh](code/run_test_1gb.sh)
3.  **执行实验**：依次运行三个脚本，每个脚本测试四种 Reduce 启动策略 (`0.0`, `0.05`, `0.5`, `1.0`)。
4.  **验证与记录**：所有作业均成功完成，关键执行步骤截图如下。

    **1MB 实验成功截图**:
    ![1MB Test Success](screenshots/run_test_1mb_success.png)

    **100MB 实验成功截图**:
    ![100MB Test Success](screenshots/run_test_100mb_success.png)

    **1GB 实验成功截图**:
    ![1GB Test Success](screenshots/run_test_1gb_success.png)

    **三组实验命令行输出在以下路径**：[log/run_output.txt](log/run_output.txt)

    #### 表：实验结果（数据源自 YARN ResourceManager）

    | 序号 | Application ID | 数据规模 | 启动策略 | 耗时 (秒) | 资源消耗 (MB-seconds) | 资源消耗 (vcore-seconds) |
    |:---:|:---|:---:|:---|:---:|:---:|:---:|
    | 1 | `app_...0001` | **1GB** | Immediate (0.0) | 44 | 289,571 | 230 |
    | 2 | `app_...0002` | **1GB** | Default (0.05) | 36 | 163,138 | 113 |
    | 3 | `app_...0003` | **1GB** | HalfMapDone (0.5) | **35** | **161,566** | **113** |
    | 4 | `app_...0004` | **1GB** | AllMapDone (1.0) | 36 | 169,888 | 120 |
    | 5 | `app_...0005` | **100MB** | Immediate (0.0) | 25 | 151,056 | 112 |
    | 6 | `app_...0006` | **100MB** | **Default (0.05)** | **25** | **103,504** | **66** |
    | 7 | `app_...0007` | **100MB** | HalfMapDone (0.5) | 27 | 109,653 | 71 |
    | 8 | `app_...0008` | **100MB** | AllMapDone (1.0) | 26 | 110,432 | 72 |
    | 9 | `app_...0009` | **1MB** | **Immediate (0.0)** | **20** | 103,885 | 71 |
    | 10 | `app_...0010` | **1MB** | Default (0.05) | 23 | 92,359 | 58 |
    | 11 | `app_...0011` | **1MB** | HalfMapDone (0.5) | 22 | 89,694 | 56 |
    | 12 | `app_...0012` | **1MB** | AllMapDone (1.0) | 24 | 93,261 | 57 |

    **12个Application的Log在以下路径**：[log/log.txt](log/log.txt)

### 实验结果与分析

#### 表：不同数据规模下各 Reduce 启动策略的作业总耗时（秒）

| 数据规模 | Immediate (0.0) | Default (0.05) | HalfMapDone (0.5) | AllMapDone (1.0) | **最佳策略** |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **1MB** | **22** | 25 | 24 | 26 | `Immediate` |
| **100MB** | 27 | **26** | 29 | 28 | `Default` |
| **1GB** | 46 | **37** | 38 | **37** | `Default` / `AllMapDone` |

#### 分析
- **核心问题验证**：日志明确显示，当 `slowstart=1.0` 时，Reduce 任务在 Map 100% 完成后才开始；当 `slowstart<1.0` 时，Map 与 Reduce 阶段存在重叠。**因此，Reduce 任务并非必须等待所有 Map 完成**。
- **性能与规模的关系**：
  - **1MB**：`Immediate (0.0)` 最快。数据极小，Map 瞬间完成，Reduce 无需等待。
  - **100MB**：`Default (0.05)` 最优。Hadoop 默认策略在此规模下实现了最佳的阶段重叠。
  - **1GB**：`HalfMapDone (0.5)` 最优。过早启动 Reduce (`0.0`) 会导致严重的资源争用，其资源消耗（289k MB-s）是最佳策略（161k MB-s）的 **1.8 倍**，并引发了 `hadoop130` 节点的 `soft lockup` 警告。
- **资源效率**：**最佳性能策略通常也是资源效率最高的策略**。例如，1GB 的 `HalfMapDone` 比 `Immediate` **快 20%** 且 **节省 44% 的内存资源**。

### 结论

- **Reduce 的最佳启动策略与输入数据规模强相关，不存在通用最优解**。
- **`Immediate (0.0)` 策略风险高**：仅在极小数据集上有效，在大数据集上会因资源争用导致性能急剧下降和系统不稳定。
- **Hadoop 默认的 `0.05` 策略是稳健之选**：在 100MB 和 1GB 场景下均表现优异，是通用场景下的安全选择。
- **本研究通过 YARN 指标验证了理论**，为 Hadoop 作业调优提供了实践依据。
- 
## 分工

- **[你的姓名]**：负责集群环境搭建、实验脚本编写与调试、实验执行、数据收集与分析、报告撰写。（贡献度：100%）