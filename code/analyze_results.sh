#!/bin/bash

# MapReduce Reduce任务启动策略研究 - 结果分析脚本
# 功能：分析实验结果，生成对比报告

set -e

RESULTS_DIR="./results"
RESULTS_CSV="${RESULTS_DIR}/experiment_results.csv"
ANALYSIS_REPORT="${RESULTS_DIR}/analysis_report.txt"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}实验结果分析${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查结果文件是否存在
if [ ! -f ${RESULTS_CSV} ]; then
    echo -e "${YELLOW}错误: 结果文件 ${RESULTS_CSV} 不存在${NC}"
    echo "请先运行 run_experiment.sh 生成实验结果"
    exit 1
fi

# 创建分析报告
{
    echo "=========================================="
    echo "MapReduce Reduce任务启动策略研究 - 分析报告"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    echo "一、实验配置"
    echo "----------------------------------------"
    echo "数据规模: 10MB, 100MB"
    echo "SlowStart值: 0.0 (Immediate), 0.05 (Default), 0.5 (HalfMapDone), 1.0 (AllMapDone)"
    echo "Reduce任务数: 5"
    echo ""
    
    echo "二、详细结果"
    echo "----------------------------------------"
    echo ""
    
    # 按数据规模分组分析
    for size in "10M" "100M"; do
        echo "数据规模: ${size}"
        echo "----------------------------------------"
        echo "SlowStart值 | 描述 | 执行时间(秒) | 平均CPU(%) | 平均内存(GB) | 峰值内存(GB)"
        echo "----------------------------------------"
        
        grep "^${size}," ${RESULTS_CSV} | while IFS=',' read -r data_size slowstart slowstart_desc duration avg_cpu avg_mem peak_mem start_time end_time; do
            printf "%-11s | %-12s | %-12s | %-10s | %-12s | %-12s\n" \
                "${slowstart}" "${slowstart_desc}" "${duration}" "${avg_cpu}" "${avg_mem}" "${peak_mem}"
        done
        echo ""
    done
    
    echo "三、性能对比分析"
    echo "----------------------------------------"
    echo ""
    
    # 找出每个数据规模下的最佳SlowStart值（以执行时间最短为准）
    for size in "10M" "100M"; do
        echo "数据规模 ${size}:"
        
        # 找出最短执行时间 (执行时间在第4列)
        best_line=$(grep "^${size}," ${RESULTS_CSV} | sort -t',' -k4 -n | head -1)
        if [ -n "${best_line}" ]; then
            best_slowstart=$(echo ${best_line} | cut -d',' -f2)
            best_slowstart_desc=$(echo ${best_line} | cut -d',' -f3)
            best_duration=$(echo ${best_line} | cut -d',' -f4)
            best_cpu=$(echo ${best_line} | cut -d',' -f5)
            best_mem=$(echo ${best_line} | cut -d',' -f6)
            
            echo "  最佳SlowStart值: ${best_slowstart} (${best_slowstart_desc}) - 执行时间: ${best_duration}秒"
            echo "  对应CPU利用率: ${best_cpu}%"
            echo "  对应内存使用: ${best_mem}GB"
        fi
        
        # 找出最长执行时间 (执行时间在第4列)
        worst_line=$(grep "^${size}," ${RESULTS_CSV} | sort -t',' -k4 -rn | head -1)
        if [ -n "${worst_line}" ]; then
            worst_slowstart=$(echo ${worst_line} | cut -d',' -f2)
            worst_slowstart_desc=$(echo ${worst_line} | cut -d',' -f3)
            worst_duration=$(echo ${worst_line} | cut -d',' -f4)
            
            echo "  最差SlowStart值: ${worst_slowstart} (${worst_slowstart_desc}) - 执行时间: ${worst_duration}秒"
            
            if [ -n "${best_duration}" ] && [ "${best_duration}" != "0" ] && [ "${worst_duration}" != "0" ]; then
                improvement=$(awk "BEGIN {printf \"%.2f\", (${worst_duration} - ${best_duration}) * 100 / ${worst_duration}}")
                echo "  性能提升: ${improvement}%"
            fi
        fi
        echo ""
    done
    
    echo "四、结论"
    echo "----------------------------------------"
    echo "1. 不同SlowStart值对作业执行时间的影响"
    echo "2. SlowStart值与资源利用率的关系"
    echo "3. 不同数据规模下的最优SlowStart值建议"
    echo ""
    
} > ${ANALYSIS_REPORT}

# 显示报告
cat ${ANALYSIS_REPORT}

echo ""
echo -e "${GREEN}分析报告已保存到: ${ANALYSIS_REPORT}${NC}"

# 生成简单的统计摘要
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}统计摘要${NC}"
echo -e "${BLUE}========================================${NC}"

echo "总实验次数: $(tail -n +2 ${RESULTS_CSV} | wc -l)"
echo "平均执行时间: $(tail -n +2 ${RESULTS_CSV} | awk -F',' '{sum+=$4; count++} END {if(count>0) printf "%.2f秒\n", sum/count; else print "N/A"}')"
echo "平均CPU利用率: $(tail -n +2 ${RESULTS_CSV} | awk -F',' '{sum+=$5; count++} END {if(count>0) printf "%.2f%%\n", sum/count; else print "N/A"}')"
echo "平均内存使用: $(tail -n +2 ${RESULTS_CSV} | awk -F',' '{sum+=$6; count++} END {if(count>0) printf "%.2fGB\n", sum/count; else print "N/A"}')"

