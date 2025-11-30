#!/bin/bash

# MapReduce Reduce任务启动策略研究 - 主实验脚本
# 功能：协调整个实验流程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${SCRIPT_DIR}

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MapReduce Reduce任务启动策略研究${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查脚本是否存在
if [ ! -f "${SCRIPT_DIR}/generate_data.sh" ]; then
    echo -e "${RED}错误: 未找到 generate_data.sh${NC}"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/run_experiment.sh" ]; then
    echo -e "${RED}错误: 未找到 run_experiment.sh${NC}"
    exit 1
fi

# 步骤1: 生成数据
echo -e "${YELLOW}步骤 1/3: 生成测试数据${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
read -p "是否生成新数据? (y/n, 默认n): " generate_new
if [ "${generate_new}" = "y" ] || [ "${generate_new}" = "Y" ]; then
    bash ${SCRIPT_DIR}/generate_data.sh
else
    echo -e "${GREEN}跳过数据生成${NC}"
fi
echo ""

# 步骤2: 运行实验
echo -e "${YELLOW}步骤 2/3: 运行实验${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
read -p "是否开始运行实验? (y/n, 默认y): " run_exp
if [ "${run_exp}" != "n" ] && [ "${run_exp}" != "N" ]; then
    bash ${SCRIPT_DIR}/run_experiment.sh
else
    echo -e "${GREEN}跳过实验执行${NC}"
fi
echo ""

# 步骤3: 分析结果
echo -e "${YELLOW}步骤 3/3: 分析实验结果${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
read -p "是否分析实验结果? (y/n, 默认y): " analyze
if [ "${analyze}" != "n" ] && [ "${analyze}" != "N" ]; then
    bash ${SCRIPT_DIR}/analyze_results.sh
else
    echo -e "${GREEN}跳过结果分析${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}实验流程完成！${NC}"
echo -e "${BLUE}========================================${NC}"









