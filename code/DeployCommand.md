# Hadoop集群搭建命令行汇总
## 一、系统配置与网络设置
### 1. 进入root权限
```bash
su
```

### 2. 编辑网卡配置文件
```bash
vim /etc/sysconfig/network-scripts/ifcfg-ens33
```

### 3. 重载网络配置
```bash
/etc/init.d/network restart
```

### 4. 检查网络配置
```bash
ifconfig
```

### 5. 测试网络连通性
```bash
ping wl621.com
```

### 6. 编辑本地DNS解析文件
```bash
vim /etc/hosts
```

### 7. 备份原yum源文件
```bash
sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
```

### 8. 下载阿里yum源文件
```bash
sudo wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-Base.repo
```

### 9. 清除yum缓存
```bash
yum clean all
```

### 10. 重新生成yum缓存
```bash
yum makecache
```

### 11. 安装epel扩展包
```bash
yum install epel-release
```

### 12. 卸载自带Java
```bash
rpm -qa | grep -i java | xargs -ni rpm -e --nodeps
```

## 二、Java安装相关
### 1. 创建软件和模块目录
```bash
mkdir -p /opt/software /opt/module
```

### 2. 解压JDK到安装目录
```bash
tar -zxf jdk-8u212-linux-x64.tar.gz -C ../module
```

### 3. 编辑环境变量配置文件
```bash
vim /etc/profile
```

### 4. 重载环境变量配置
```bash
source /etc/profile
```

### 5. 创建Java软链接
```bash
ln -s /opt/module/jdk1.8.0_212/bin/java /usr/bin/java
```

### 6. 验证Java安装
```bash
java -version
```

## 三、Hadoop安装相关
### 1. 下载Hadoop到software文件夹
```bash
wget -P /opt/software https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-3.3.5.tar.gz
```

### 2. 进入software目录
```bash
cd software
```

### 3. 解压Hadoop到安装目录
```bash
tar -zxf hadoop-3.3.5.tar.gz -C ../module
```

### 4. 编辑环境变量配置文件
```bash
vim /etc/profile
```

### 5. 重载环境变量配置
```bash
source /etc/profile
```

### 6. 验证Hadoop安装
```bash
hadoop
```

## 四、SSH免密配置
### 1. 进入密钥存放目录
```bash
cd /root/.ssh
```

### 2. 生成DSA密钥对
```bash
ssh-keygen -t dsa
```

### 3. 分发公钥到目标节点（示例）
```bash
ssh-copy-id -i ./id_dsa.pub root@hadoop129
ssh-copy-id -i ./id_dsa.pub root@hadoop130
ssh-copy-id -i ./id_dsa.pub root@hadoop131
ssh-copy-id -i ./id_dsa.pub root@hadoop132
```

### 4. 测试免密登录（示例）
```bash
ssh root@hadoop129
```

### 5. 退出登录
```bash
exit
```

## 五、Hadoop配置相关
### 1. 编辑Hadoop运行环境配置
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/hadoop-env.sh
```

### 2. 编辑核心配置文件
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/core-site.xml
```

### 3. 编辑HDFS配置文件
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/hdfs-site.xml
```

### 4. 编辑YARN配置文件
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/yarn-site.xml
```

### 5. 编辑MapReduce配置文件
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/mapred-site.xml
```

### 6. 编辑workers文件
```bash
vim /opt/module/hadoop-3.3.5/etc/hadoop/workers
```

### 7. 同步配置文件到其他节点（示例）
```bash
scp ./* root@hadoop130:/opt/module/hadoop-3.3.5/etc/hadoop/
scp ./* root@hadoop131:/opt/module/hadoop-3.3.5/etc/hadoop/
scp ./* root@hadoop132:/opt/module/hadoop-3.3.5/etc/hadoop/
```

## 六、Hadoop集群启动与管理
### 1. 格式化NameNode
```bash
hdfs namenode -format
```

### 2. 启动HDFS集群
```bash
./sbin/start-dfs.sh
```

### 3. 停止HDFS集群
```bash
./sbin/stop-dfs.sh
```

### 4. 启动YARN集群
```bash
./sbin/start-yarn.sh
```

### 5. 停止YARN集群
```bash
./sbin/stop-yarn.sh
```

### 6. 启动所有服务
```bash
./sbin/start-all.sh
```

### 7. 停止所有服务
```bash
./sbin/stop-all.sh
```

### 8. 查看目录结构（示例）
```bash
tree -L 2 -C
```

### 9. 启动任务历史服务器
```bash
mr-jobhistory-daemon.sh start historyserver
```

### 10. 停止任务历史服务器
```bash
mr-jobhistory-daemon.sh stop historyserver
```

## 七、Hadoop常用操作
### 1. HDFS文件上传
```bash
hadoop fs -put 本地文件路径 HDFS目标路径
```

### 2. HDFS文件下载
```bash
hadoop fs -get HDFS文件路径 本地目标路径
```

### 3. 查看HDFS目录内容
```bash
hadoop fs -ls HDFS路径
```

### 4. 创建HDFS目录
```bash
hadoop fs -mkdir -p HDFS目录路径
```

### 5. 删除HDFS文件/目录
```bash
hadoop fs -rm -r HDFS文件/目录路径
```

### 6. 查看HDFS文件内容
```bash
hadoop fs -cat HDFS文件路径
```

### 7. 运行WordCount示例程序
```bash
hadoop jar /opt/module/hadoop-3.3.0/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.0.jar wordcount 输入路径 输出路径
```
