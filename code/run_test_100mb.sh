#!/bin/bash
# 100MB 数据规模测试脚本

export HADOOP_HOME="/opt/module/hadoop-3.3.5"
LOCAL_TMP_DIR="/root/reduce_test_data_100mb"
INPUT_DIR="/input/reduce_test"
OUTPUT_BASE="/output/reduce_test"
REDUCE_COUNT=4

DATA_SIZE_MB=100
DATA_NAME="100MB"

SLOWSTART_VALUES=("0.0" "0.05" "0.5" "1.0")
STRATEGY_NAMES=("Immediate" "Default(5%)" "HalfMapDone" "AllMapDone")

REPORT_FILE="reduce_test_report_${DATA_NAME}.csv"

mkdir -p $LOCAL_TMP_DIR
hdfs dfs -mkdir -p $INPUT_DIR

echo "DataSize,Strategy,SlowStart,TotalSeconds,Status" > $REPORT_FILE

# 生成 100MB 数据
echo "📊 生成 $DATA_NAME 数据..."
dd if=/dev/urandom bs=1M count=75 2>/dev/null | base64 > "$LOCAL_TMP_DIR/data.txt"
hdfs dfs -put "$LOCAL_TMP_DIR/data.txt" "$INPUT_DIR/$DATA_NAME"

# 运行 4 种策略
for i in "${!SLOWSTART_VALUES[@]}"; do
    SLOWSTART=${SLOWSTART_VALUES[$i]}
    STRATEGY_NAME=${STRATEGY_NAMES[$i]}
    OUTPUT_DIR="$OUTPUT_BASE/${DATA_NAME}_${STRATEGY_NAME}"
    
    hdfs dfs -rm -r $OUTPUT_DIR 2>/dev/null
    
    echo "🚀 运行: $STRATEGY_NAME (slowstart=$SLOWSTART)"
    START_TIME=$(date +%s)
    
    hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
        wordcount \
        -D mapreduce.job.reduce.slowstart.completedmaps=$SLOWSTART \
        -D mapreduce.job.reduces=$REDUCE_COUNT \
        "$INPUT_DIR/$DATA_NAME" \
        "$OUTPUT_DIR"
    
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$((END_TIME - START_TIME))
    
    if [ $? -eq 0 ]; then
        echo "$DATA_NAME,$STRATEGY_NAME,$SLOWSTART,$TOTAL_SECONDS,SUCCEEDED" >> $REPORT_FILE
    else
        echo "$DATA_NAME,$STRATEGY_NAME,$SLOWSTART,$TOTAL_SECONDS,FAILED" >> $REPORT_FILE
    fi
done

# 清理
rm -rf $LOCAL_TMP_DIR
hdfs dfs -rm -r "$INPUT_DIR/$DATA_NAME" 2>/dev/null

echo "✅ $DATA_NAME 测试完成！结果已保存至: $REPORT_FILE"
