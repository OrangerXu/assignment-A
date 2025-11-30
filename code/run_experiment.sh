#!/bin/bash

# MapReduce Reduce任务启动策略研究 - 实验执行脚本
# 功能：运行terasort测试，修改slowstart参数，记录性能指标

set -e

HADOOP_HOME=${HADOOP_HOME:-/usr/local/hadoop}
HDFS_BASE_DIR="/user/zong"
RESULTS_DIR="./results"
LOG_DIR="${RESULTS_DIR}/logs"

# 定义测试参数
DATA_SIZES=("10M" "100M")
# SlowStart值: 0.0=Immediate, 0.01=Early, 0.05=Default, 0.5=HalfMapDone, 1.0=AllMapDone
SLOWSTART_VALUES=(0.0 0.01 0.05 0.5 1.0)  # mapreduce.job.reduce.slowstart.completedmaps
NUM_REDUCES=5

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 创建结果目录
mkdir -p ${RESULTS_DIR}
mkdir -p ${LOG_DIR}

# 结果文件
RESULTS_CSV="${RESULTS_DIR}/experiment_results.csv"
METRICS_FILE="${RESULTS_CSV}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MapReduce Reduce启动策略实验${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查Hadoop是否可用
if ! command -v hadoop &> /dev/null; then
    echo -e "${RED}错误: 未找到hadoop命令${NC}"
    exit 1
fi

# 初始化结果CSV文件
if [ ! -f ${RESULTS_CSV} ]; then
    echo "数据规模,SlowStart值,SlowStart描述,作业执行时间(秒),CPU平均利用率(%),内存平均使用量(GB),峰值内存(GB),开始时间,结束时间" > ${RESULTS_CSV}
fi

# 函数：获取系统CPU利用率
get_cpu_usage() {
    # 获取1秒内的CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo ${cpu_usage}
}

# 函数：获取系统内存使用量
get_memory_usage() {
    # 获取内存使用量（GB）
    memory_used=$(free -g | awk '/^Mem:/{print $3}')
    echo ${memory_used}
}

# 函数：获取峰值内存
get_peak_memory() {
    # 获取系统总内存和已使用内存
    memory_total=$(free -g | awk '/^Mem:/{print $2}')
    memory_used=$(free -g | awk '/^Mem:/{print $3}')
    echo ${memory_used}
}

# 函数：监控系统资源（后台运行）
monitor_resources() {
    local log_file=$1
    local pid_file=$2
    local interval=2  # 每2秒采样一次
    
    > ${log_file}  # 清空日志文件
    
    # 持续监控直到收到停止信号
    while [ -f ${pid_file} ]; do
        timestamp=$(date +%s)
        cpu=$(get_cpu_usage)
        mem=$(get_memory_usage)
        echo "${timestamp},${cpu},${mem}" >> ${log_file}
        sleep ${interval}
    done
}

# 函数：计算平均值
calculate_average() {
    local file=$1
    local column=$2
    awk -F',' -v col=${column} 'NR>1 {sum+=$col; count++} END {if(count>0) print sum/count; else print 0}' ${file}
}

# 函数：计算最大值
calculate_max() {
    local file=$1
    local column=$2
    awk -F',' -v col=${column} 'NR>1 {if($col>max || NR==2) max=$col} END {print max}' ${file}
}

# 函数：检查实验是否已运行
is_experiment_done() {
    local size=$1
    local slowstart=$2
    local csv_file=$3
    
    # 如果CSV文件不存在或为空，返回false
    if [ ! -f "${csv_file}" ] || [ ! -s "${csv_file}" ]; then
        return 1
    fi
    
    # 检查CSV文件中是否存在该数据规模和slowstart值的组合
    # 跳过标题行和空行，检查第一列（数据规模）和第二列（SlowStart值）
    if grep -q "^${size},${slowstart}," "${csv_file}" 2>/dev/null; then
        return 0  # 已运行
    else
        return 1  # 未运行
    fi
}

# 主实验循环
for size in "${DATA_SIZES[@]}"; do
    INPUT_DIR="${HDFS_BASE_DIR}/teragen-input-${size}"
    OUTPUT_BASE="${HDFS_BASE_DIR}/terasort-output"
    
    # 检查输入数据是否存在
    if ! hadoop fs -test -d ${INPUT_DIR} 2>/dev/null; then
        echo -e "${YELLOW}警告: 输入数据 ${INPUT_DIR} 不存在，跳过${NC}"
        continue
    fi
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}测试数据规模: ${size}${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    for slowstart in "${SLOWSTART_VALUES[@]}"; do
        OUTPUT_DIR="${OUTPUT_BASE}-${size}-slowstart${slowstart}"
        
        echo -e "${BLUE}----------------------------------------${NC}"
        echo -e "${BLUE}SlowStart值: ${slowstart}${NC}"
        echo -e "${BLUE}输入: ${INPUT_DIR}${NC}"
        echo -e "${BLUE}输出: ${OUTPUT_DIR}${NC}"
        
        # 检查实验是否已运行
        if is_experiment_done "${size}" "${slowstart}" "${RESULTS_CSV}"; then
            echo -e "${YELLOW}⚠ 实验已运行，跳过: ${size} / SlowStart=${slowstart}${NC}"
            # 从CSV中提取已运行实验的结果并显示
            existing_result=$(grep "^${size},${slowstart}," "${RESULTS_CSV}" | head -1)
            if [ -n "${existing_result}" ]; then
                # 使用awk解析CSV，处理可能包含逗号的时间字段
                duration=$(echo "${existing_result}" | awk -F',' '{print $4}')
                avg_cpu=$(echo "${existing_result}" | awk -F',' '{print $5}')
                avg_mem=$(echo "${existing_result}" | awk -F',' '{print $6}')
                peak_mem=$(echo "${existing_result}" | awk -F',' '{print $7}')
                start_time=$(echo "${existing_result}" | awk -F',' '{print $8}')
                end_time=$(echo "${existing_result}" | awk -F',' '{print $9}')
                echo -e "${GREEN}  已运行结果: 耗时=${duration}秒, CPU=${avg_cpu}%, 内存=${avg_mem}GB, 峰值内存=${peak_mem}GB${NC}"
                echo -e "${GREEN}  运行时间: ${start_time} ~ ${end_time}${NC}"
            fi
            echo ""
            continue
        fi
        
        # 清理之前的输出
        hadoop fs -rm -r -f ${OUTPUT_DIR} 2>/dev/null || true
        
        # 记录开始时间
        START_TIME=$(date +%s)
        START_TIME_STR=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 创建资源监控日志文件
        RESOURCE_LOG="${LOG_DIR}/resources-${size}-slowstart${slowstart}.log"
        MONITOR_PID_FILE="${LOG_DIR}/monitor-${size}-slowstart${slowstart}.pid"
        
        # 创建PID文件
        touch ${MONITOR_PID_FILE}
        
        # 启动资源监控（后台运行）
        monitor_resources ${RESOURCE_LOG} ${MONITOR_PID_FILE} &
        MONITOR_PID=$!
        
        # 运行terasort
        echo -e "${YELLOW}开始运行terasort...${NC}"
        
        TERASORT_LOG="${LOG_DIR}/terasort-${size}-slowstart${slowstart}.log"
        
        hadoop jar ${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
            terasort \
            -D mapreduce.job.reduces=${NUM_REDUCES} \
            -D mapreduce.job.reduce.slowstart.completedmaps=${slowstart} \
            ${INPUT_DIR} \
            ${OUTPUT_DIR} \
            2>&1 | tee ${TERASORT_LOG}
        
        # 停止资源监控
        rm -f ${MONITOR_PID_FILE}
        sleep 2  # 等待监控进程完成最后一次采样
        kill ${MONITOR_PID} 2>/dev/null || true
        wait ${MONITOR_PID} 2>/dev/null || true
        
        # 记录结束时间
        END_TIME=$(date +%s)
        END_TIME_STR=$(date '+%Y-%m-%d %H:%M:%S')
        DURATION=$((END_TIME - START_TIME))
        
        # 计算资源使用指标
        AVG_CPU=$(calculate_average ${RESOURCE_LOG} 2)
        AVG_MEM=$(calculate_average ${RESOURCE_LOG} 3)
        PEAK_MEM=$(calculate_max ${RESOURCE_LOG} 3)
        
        # 获取SlowStart描述
        if [[ "${slowstart}" == "0.0" ]]; then
            SLOWSTART_DESC="Immediate"
        elif [[ "${slowstart}" == "0.01" ]]; then
            SLOWSTART_DESC="Early"
        elif [[ "${slowstart}" == "0.05" ]]; then
            SLOWSTART_DESC="Default"
        elif [[ "${slowstart}" == "0.5" ]]; then
            SLOWSTART_DESC="HalfMapDone"
        elif [[ "${slowstart}" == "1.0" ]]; then
            SLOWSTART_DESC="AllMapDone"
        else
            SLOWSTART_DESC="Custom"
        fi
        
        # 记录结果到CSV
        echo "${size},${slowstart},${SLOWSTART_DESC},${DURATION},${AVG_CPU},${AVG_MEM},${PEAK_MEM},${START_TIME_STR},${END_TIME_STR}" >> ${RESULTS_CSV}
        
        echo -e "${GREEN}✓ 完成 - 耗时: ${DURATION}秒, 平均CPU: ${AVG_CPU}%, 平均内存: ${AVG_MEM}GB${NC}"
        echo ""
        
        # 短暂休息，避免系统过载
        sleep 5
    done
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}所有实验完成！${NC}"
echo -e "${BLUE}结果文件: ${RESULTS_CSV}${NC}"
echo -e "${BLUE}日志目录: ${LOG_DIR}${NC}"
echo -e "${BLUE}========================================${NC}"

