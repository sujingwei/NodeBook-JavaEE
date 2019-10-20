# 一、MySQL简介

### 1、MySQL 当前主流版本

5.6 , 5.7, 8.0

选择版本：MySQL Oralce官方版，选择(GA版，时间在近期内的)

红帽：MariaDB

Percona：PerconaDB

* 推荐使用 5.7.20 二进制版本

下载地址：https://downloads.mysql.com/archives/community/, 打开后选择版本

### 2、安装

#### 第一步：解压，目录重命名为mysql

#### 第二步：添加到环境变量中 /etc/perfile

```shell
export PATH=/app/mysql/bin:$PATH
```

#### 第三步：创建用户和组

```shell
 > groupadd mysql
 > useradd -g mysql mysql -s /sbin/nologin
```

#### 第四步：创建数据目录

```shell
mkdir -p /data/mysql
chown -R mysql:mysql /app/*
chown -R mysql:mysql /data/*
```

#### 第五步：初始化数据

###### 方式一

```shell
# 初始化完后，/data/mysql目录下就有文件了
mysqld --initialize --user=mysql --basedir=/app/mysql --datadir=/data/mysql

# 以下是正确安装时报的信息
2019-10-20T08:18:12.158805Z 0 [Warning] TIMESTAMP with implicit DEFAULT value is deprecated. Please use --explicit_defaults_for_timestamp server option (see documentation for more details).
2019-10-20T08:18:12.368862Z 0 [Warning] InnoDB: New log files created, LSN=45790
2019-10-20T08:18:12.397979Z 0 [Warning] InnoDB: Creating foreign key constraint system tables.
2019-10-20T08:18:12.456711Z 0 [Warning] No existing UUID has been found, so we assume that this is the first time that this server has been started. Generating a new UUID: 286ae99f-f312-11e9-9732-000c296ded7b.
2019-10-20T08:18:12.459966Z 0 [Warning] Gtid table is not ready to be used. Table 'mysql.gtid_executed' cannot be opened.
2019-10-20T08:18:12.464110Z 1 [Note] A temporary password is generated for root@localhost: y.6OiyH6aREs
# TODO mysql 5.7 加入了全新的安全机制，密码在安装信息最后一行显示，并且在日志里记录一份
# 密码复杂度，长度大于或等于12位，字符混乱组合
# 密码过期时间180天
```

###### 方式二(企业中没有要求，使用这种方式)

```shell
# 初始化，加上--initialize-insecure
# 没有密码复杂度
# 密码没有过期时间
mysqld --initialize-insecure --user=mysql --basedir=/app/mysql --datadir=/data/mysql

# 输出信息
2019-10-20T08:30:57.336097Z 0 [Warning] TIMESTAMP with implicit DEFAULT value is deprecated. Please use --explicit_defaults_for_timestamp server option (see documentation for more details).
2019-10-20T08:30:57.540058Z 0 [Warning] InnoDB: New log files created, LSN=45790
2019-10-20T08:30:57.579513Z 0 [Warning] InnoDB: Creating foreign key constraint system tables.
2019-10-20T08:30:57.636974Z 0 [Warning] No existing UUID has been found, so we assume that this is the first time that this server has been started. Generating a new UUID: f0802733-f313-11e9-8769-000c296ded7b.
2019-10-20T08:30:57.638794Z 0 [Warning] Gtid table is not ready to be used. Table 'mysql.gtid_executed' cannot be opened.
2019-10-20T08:30:57.639707Z 1 [Warning] root@localhost is created with an empty password ! Please consider switching off the --initialize-insecure option.
```

#### 第六步：添加配置文件

###### 删除MariaDB

```shell
yum remove mariadb
```

###### vi /etc/my.cnf基本设置

```shell
[mysqld]
user=mysql
basedir=/app/mysql
datadir=/data/mysql
server_id=6
port=3306
socket=/tmp/mysql.sock
[mysql]
socket=/tmp/mysql.sock
prompt=3306 [\\d]>
```

#### 第七步：启动

###### MySQL 5.7启动方式

```shell
# 启动
/app/mysql/support-files/mysql.server start

# 日志输出
Starting MySQL.Logging to '/data/mysql/localhost.localdomain.err'.
 SUCCESS!

# 关闭
/app/mysql/support-files/mysql.server stop

# 重启
/app/mysql/support-files/mysql.server restart
```

###### CentOS6 & CentOS7启动方式

```shell
# 把文件复制到 /etc/init.d/目录下，并命名为mysqld
cp /app/mysql/support-files/mysql.server /etc/init.d/mysqld

# CentOS6和CentOS7通用的方法，就可以使用以下的操作了
service mysqld restart
```

###### CentOS7启动方式

vi /etc/systemd/system/mysqld.service

```shell
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target
[Install]
WantedBy=multi-user.target
[Service]
User=mysql
Grouup=mysql
ExecStart=/app/mysql/bin/mysqld --defaults-file=/etc/my.cnf
LimitNOFILE = 5000


### 写完以上文件，就可以使用以下命令来管理MySQL服务了
systemctl start mysqld
```

#### 第八步：设置密码

```shell
mysqladmin -uroot -p password 123
Enter password:  # 这里不用输入密码

# mysql5.7查看帐号信息
select host, user, authentication_string from mysql.user;
```

# 二、MySQL的体系结构

## 1、体系结构

mysql是一个CS架构的应用。连接方式：

```shell
TCP/IP方式：
mysql -h 192.168.0.103 -u root -p -P3306

Socket方式（仅本地）
mysql -uroot -poldboy123 -s /tmp/mysql.sock
```

## 2、mysqld的程序结构

* 连接层

* SQL 层
* 存储引擎层

mysql出现故障或性能的问题80%以上都是人为的。

### （1）连接层

* 连接层提供Tcp/Ip、Socket的连接方式

* 和用户登录信息的校验

* 提供专用连接线程：接收用户SQL，返回结果

```mysql
# 每一个会话，MySQL都会有对应的线程来接收其SQL语句请求
# 下面有两个会话连接
> show processlist;
+----+------+-----------+------+---------+------+----------+------------------+
| Id | User | Host      | db   | Command | Time | State    | Info             |
+----+------+-----------+------+---------+------+----------+------------------+
|  7 | root | localhost | NULL | Sleep   |   77 |          | NULL             |
|  8 | root | localhost | NULL | Query   |    0 | starting | show processlist |
+----+------+-----------+------+---------+------+----------+------------------+
```

这个线程的作用是接收SQL语句，返回结果。

### （2）SQL层

* 接收上层传送的SQL语句

* 语法验证模块：验证语句语法，是满足SQL_MODE

* 语义检查：判断SQL语句的类型

  | SQL语句类型 | SQL语句类型解析 |
  | ----------- | --------------- |
  | DDL         | 数据定义语言    |
  | DCL         | 数据控制语言    |
  | DML         | 数据操作语言    |
  | DQL         | 数据查询语言    |


* 权限检查：用户对库表有没有权限
* 解析器：进行SQL的预处理，产生解析树(执行计划)，生成执行方案(多个方案)
* 优化器：根据”解析器“得出的多种执行判断，选择最优的执行计划
  * 代价模型：通过(CPU IO MEM)的损耗评估性能好坏
* 执行器：根据最优执行计划，执行SQL语句，产生执行结果：在磁盘的 xxxx 位置上
* 提供查询缓存（默认是没有开启），会使用redis tair替代查询缓存功能
* 提供日志记录：binlog，默认是没开启的

### （3）存储引擎层

​	类似于Linux中的文件系统，负责根据SQL层执行的结果，从磁盘上拿数据。将16进制的磁盘数据，交由SQL结构化成表，由连接层的专用线程返回给用户。

```mysql
3306 [mysql]>select host,user,authentication_string from mysql.user;
+-----------+---------------+-------------------------------------------+
| host      | user          | authentication_string                     |
+-----------+---------------+-------------------------------------------+
| localhost | root          | *23AE809DDACAF96AF0FD78ED04B6A265E05AA257 |
| localhost | mysql.session | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
| localhost | mysql.sys     | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
+-----------+---------------+-------------------------------------------+
```

## 3、MySQL的逻辑结构

库、表、字段、数据行(记录)

* 库包含了：库名、库属性

* 表包含了：表名、列(字段)、行(记录)
* 字段：字段名、类型、索引

* 数据行

## 4、MySQL物理结构

​	在 `/data/mysql`目录下(数据存储目录)新建一个 `abc` 的目录，那么通过 show databases;查看，就会发现多了一个叫`abc`的数据库。

**mysql.user的磁盘下的文件(MyIsAm引擎的表结构)**

```shell
-rw-r-----. 1 mysql mysql   10816 10月 20 16:30 user.frm   # 存储表结构
-rw-r-----. 1 mysql mysql     396 10月 20 17:34 user.MYD   # 存储数据记录
-rw-r-----. 1 mysql mysql    4096 10月 20 18:29 user.MYI   # 存储索引
```

**mysql.time_zone(InnoDB引擎的表结构)**

```shell
-rw-r-----. 1 mysql mysql    8636 10月 20 16:30 time_zone.frm  # 存储表结构
-rw-r-----. 1 mysql mysql   98304 10月 20 16:30 time_zone.ibd  # 存储数据和索引
```

## 5、MySQL(InnoDB)的”段”，“区”，“页“

* 页：16kb(最小的IO单元)
* 区：用一个或多个连续的页来存储一个数据，那么这些连续的页就叫区

* 段：一个表就是一个段，包含一个或多个区