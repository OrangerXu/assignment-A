#!/bin/bash

# MapReduce Reduce任务启动策略研究 - 数据生成脚本
# 功能：生成不同规模的数据集用于测试

set -e

HADOOP_HOME=${HADOOP_HOME:-/usr/local/hadoop}
HDFS_BASE_DIR="/user/zong"

# 定义不同规模的数据集
DATA_SIZES=("10M" "100M")

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MapReduce 数据生成脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查Hadoop是否可用
if ! command -v hadoop &> /dev/null; then
    echo "错误: 未找到hadoop命令，请确保HADOOP_HOME已正确设置"
    exit 1
fi

# 创建HDFS目录
echo -e "${GREEN}创建HDFS目录...${NC}"
hadoop fs -mkdir -p ${HDFS_BASE_DIR}

# 为每个数据规模生成数据
for size in "${DATA_SIZES[@]}"; do
    INPUT_DIR="${HDFS_BASE_DIR}/teragen-input-${size}"
    OUTPUT_DIR="${HDFS_BASE_DIR}/teragen-output-${size}"
    
    # 计算行数 (100MB ≈ 1,000,000行, 10MB ≈ 100,000行)
    if [[ "${size}" == "10M" ]]; then
        ROWS=100000
        SIZE_DISPLAY="10MB"
    elif [[ "${size}" == "100M" ]]; then
        ROWS=1000000
        SIZE_DISPLAY="100MB"
    else
        echo "错误: 不支持的数据规模 ${size}"
        continue
    fi
    
    echo -e "${GREEN}生成 ${SIZE_DISPLAY} 数据集 (${ROWS} 行)...${NC}"
    
    # 检查是否已存在
    if hadoop fs -test -d ${INPUT_DIR} 2>/dev/null; then
        echo "  数据集 ${INPUT_DIR} 已存在，跳过生成"
        continue
    fi
    
    # 使用teragen生成数据
    echo "  开始生成数据..."
    START_TIME=$(date +%s)
    
    hadoop jar ${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
        teragen \
        -D mapreduce.job.maps=10 \
        ${ROWS} \
        ${INPUT_DIR}
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo -e "${GREEN}  ✓ ${SIZE_DISPLAY} 数据集生成完成，耗时: ${DURATION} 秒${NC}"
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}所有数据集生成完成！${NC}"
echo -e "${BLUE}========================================${NC}"

# 显示生成的数据集
echo -e "${BLUE}生成的数据集列表:${NC}"
hadoop fs -ls ${HDFS_BASE_DIR} | grep teragen-input

