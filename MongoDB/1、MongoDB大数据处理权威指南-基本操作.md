# MongoDB大数据处理权威指南-基本操作

## 一、mongod启动命令参数

### 1、基本配置参数

| 参数                                            | 描述                                                         |
| ----------------------------------------------- | ------------------------------------------------------------ |
| --quiet                                         | \# 安静输出                                                  |
| <span style="color:blue;">--port arg</span>     | \# 指定服务端口，默认端口21017                               |
| --bind_ip arg                                   | \# 绑定服务IP，若绑定127.0.0.1，则只能本机访问，不指定默认本地所有IP访问 |
| <span style="color:blue;">--logpath arg</span>  | \# 指定MongoDB日志文件，注意是文件而不是目录                 |
| <span style="color:blue;">--logappend</span>    | \# 使用追加的方式写日志                                      |
| --pidfilepath arg                               | \# PID File的完整路径，如果没有设置，则没有PID文件           |
| --keyFile arg                                   | \# 集群的私钥的完整路径，只对Replica Set架构有效             |
| --unixSocketPrefix arg                          | \# UNIX域套接字替代目录，默认/tmp                            |
| <span style="color:blue;">--fork</span>         | \# 以守护进程的方式运行MongoDB，创建服务器进程               |
| --auth                                          | \# 启用验证                                                  |
| --cpu                                           | \# 定期显示CPU和CPU利用率和iowait                            |
| <span style="color:blue;">--dbpath arg</span>   | \# 指定数据库路径                                            |
| --diaglog arg                                   | \# diaglog选项 0=off 1=W 2=R 3=both 7=W+some reads           |
| --directoryperdb                                | \# 设置每个数据库将被保存在一个单独的目录                    |
| --journal                                       | \# 启用日志选项，MongoDB的数据操作将会写入到journal文件夹的文件里 |
| --journalOptions arg                            | \# 启用日志诊断选项                                          |
| --ipv6                                          | \# 启用IPv6选项                                              |
| --jsonp                                         | \# 允许JSONP形式通过HTTP访问（有安全影响）                   |
| <span style="color:blue;">--maxConns arg</span> | \# 最大同时连接数 默认2000                                   |
| --noauth                                        | \# 不启用验证                                                |
| --nohttpinterface                               | \# 关闭http接口，默认关闭27018端口访问                       |
| --noprealloc                                    | \# 禁用数据文件预分配(往往影响性能)                          |
| --noscripting                                   | \# 禁用脚本引擎                                              |
| --notablescan                                   | \# 不允许表扫描                                              |
| --nounixsocket                                  | \# 禁用Unix套接字监听                                        |
| --nssize arg (=16)                              | \# 设置数据库.ns文件大小(MB)，就是，名称空间                 |
| --objcheck                                      | \# 在收到客户数据,检查的有效性                               |
| --profile arg                                   | \# 档案参数 0=off 1=slow, 2=all                              |
| --quota                                         | \# 限制每个数据库的文件数，设置默认为8                       |
| --quotaFiles arg                                | \# number of files allower per db, requires --quota          |
| <span style="color:blue;">--rest</span>         | \# 开启简单的rest API，3.2后的版本已丢去                     |
| --repair                                        | \# 修复所有数据库run repair on all dbs                       |
| --repairpath arg                                | \# 修复库生成的文件的目录,默认为目录名称dbpath               |
| --slowms arg (=100)                             | \# value of slow for profile and console log                 |
| --smallfiles                                    | \# 使用较小的默认文件                                        |
| --syncdelay arg (=60)                           | \# 数据写入磁盘的时间秒数(0=never,不推荐)                    |
| --sysinfo                                       | \# 打印一些诊断系统信息                                      |
| --upgrade                                       | \# 如果需要升级数据库                                        |

### 2、Replicaton配置参数

| 参数            | 描述                                                         |
| --------------- | ------------------------------------------------------------ |
| --fastsync      | \# 从一个dbpath里启用从库复制服务，该dbpath的数据库是主库的快照，可用于快速启用同步 |
| --autoresync    | \# 如果从库与主库同步数据差得多，自动重新同步                |
| --oplogSize arg | \# 设置oplog的大小(MB)                                       |

### 3、主/从参数

| 参数             | 描述                          |
| ---------------- | ----------------------------- |
| --master         | \# 主库模式                   |
| --slave          | \# 从库模式                   |
| --source arg     | \# 从库端口号                 |
| --only arg       | \# 指定单一的数据库复制       |
| --slavedelay arg | \# 设置从库同步主库的延迟时间 |

### 4、Replica set(副本集)选项

| 参数          | 描述              |
| ------------- | ----------------- |
| --replSet arg | \# 设置副本集名称 |

### 5、Sharding(分片)选项

| 参数             | 描述                                                         |
| ---------------- | ------------------------------------------------------------ |
| --configsvr      | \# 声明这是一个集群的config服务,默认端口27019，默认目录/data/configdb |
| --shardsvr       | \# 声明这是一个集群的分片,默认端口27018                      |
| --noMoveParanoia | \# 关闭偏执为moveChunk数据保存                               |

### 6、配置文件方式启动

**/etc/mongo.conf**

```
./mongod -f /etc/mongo.conf
```

## 二、mongo的CRUD操作

### 1、数据库基本操作

**登录：**

```sh
mongo ip:port
```

**显示所有的数据库：**

```sh
show dbs/databases
```

**显示当前使用的数据库：**

```sh
db
```

**切换当前使用的数据库：**

```sh
use database_name	
```

**创建数据库：**

```sh
# mongodb没有专门创建数据库的语句，可以使用"use"来使用某个数据库，如果数据库存不存在，将会创建一个，当向该库加入文档后，保存成功为件。
```

**删除数据库：**

```shell
db.dropDatabase()
```

**查询集合：**

```sh
show collections/tables
```

**显示创建集合：**

```sh
db.createCollection("classes")
```

### 2、CRUD操作

**insert**

```sh
db.users.insert({"userId":"u1"})
# 插入多个文档，使用 [ ]
db.users.insert([{"userId":"u2", "name": "11"},{"userId":"u2", "age":"22"}])
# 每个Doc必须少于16M
```

**find**

```hs
db.classes.find()
```

**drop**

```sh
# 删除集合
db.users.drop()
```

**remove**

```sh
# 不加条件就全部删除
db.users.remove();
# 只删除指定条件的
db.users.remove({"userId": "u6"})
```

**stats**

```sh
# 查看数据库/集合信息
db.stats()  # 查看当前数据库信息

# 查看集合信息
db.classes.stats()
```

**update**

```sh
db.users.update({"userId":"u1"},{"userId":"u1","name":"u1Name"})
# 第三个参数&& 第四个参数分别为：upsert、multi，分别用于：
# upsert，如果不数据不存在，就插入，否则就更新，通常这个参数会设置为 0/false
# multi，修改多条记录(通常是不允许的,必需和修改器(如：$set)一起使用)
# 建议 第三个参数和第四人参数默认设置为 0 和 1
```

**$set**

```sh
# 如果 "name" 字段不存在，就创建一个
# 如果把第四个参数改为0，那么只有一个会被修改
db.users.update({"userId": "u2"}, {$set: {"name": "u2Name22"}}, 0, 1)
```

**$unset**

```sh
# 删除某个字段
db.users.update({"age":"22"}, {$unset: {"name": true}})
```

**$inc**

```sh
# 相当于 ++ / --
db.users.update({"userId": "u1"}, {$inc: {"age": 10}})  # age字段+10
```

**$push**

```sh
# 向已有数组(字段的值是一个数组)未尾加入一个元素，要是没有就新建一个数组
db.users.update({"userId": "u1"}, {$push: {"score": 3}}) # score:[1,2] => score:[1,2,3]
```

**$each**

```sh
# 通过一次$push来操作多个值
db.users.update({"userId": "u1"}, {$push: {"score": {$each: [4, 5, 6]}}})
```

**$slice**

```sh
# 限制数组只包含最后加入的n个元素，其值必需是负整数
# 以下操作，会让“score”只保留后5个元素
db.users.update({"userId": "u1"}, {$push: {"score": {$each: [7,8,9], $slice: -5}}})

# 如果如下:
# { "_id" : ObjectId("5e363d59861d685b205c31bd"), "userId" : "u1", "name" : "u1Name", "age" : 103, "score" : [ 5, 6, 7, 8, 9 ] }
```

**$sort**

```sh
# 对数据里的数据进行排序：1为升序，-1为倒序
db.users.update({"userId": "u1"}, {$push: {"score": {$each: [1,2,3], $slice: -5, $sort: -1}}})
# 注意：不能将$slice或者$sort与$push配合使用，必需使用$each
```

**$ne**

```sh
# 不等于
db.users.update({"userId": "u1", score:{$ne: 3}}, ...)
```

**$addToSet**

```sh
# 如果不包含值，就添加
db.users.update({"userId": "u1"}, {$addToSet: {"score": 7}})
```

**$pop**

```sh
# 从数组一端删除元素, 1从尾部删除一个，-1从头部删除一个
db.users.update({"userId": "u1"}, {$pop: {"score": -1}})
```

**$**

```sh
# $ 用来修改第一个匹配的元素
db.users.update({"userId": "u1"}, {$set: {"score.1": 5}}) # 第1个元素的值改为5
db.users.update({"userId": "u1", "score.0": "3"}， {$set: {"score.$": 5}}) # 第0个元素的值改为5
```

**save**

```sh
# 如果_id存在就是修改，否则就是新增
db.users.save({"_id" : ObjectId("5e363da3861d685b205c31bf") ,"userId":"u6"})
```

**显示错误信息**

```
# 方法1
db.getLastError()
# 方法2
db.runCommand({"getLastError": 1})
```

## 三、MongoDB 查询相关操作

### 1、指定要返回的键

```sh
# 通过第二个参数指定,1:显示，0：不显示
db.users.find({}, {"userId":1, "name":1, "_id":0})
```

### 2、按条件查询

```sh
db.users.find({"userId": "u1"})
```

#### 1）比较操作$lt，$lte，$gt，$gte，$ne

```sh
db.users.find({"age": {$lt:110}})
# 两个条件
db.users.find({"age": {$gte:103, $lt:105}})
# 也是两个条件
db.users.find({"userId": "u1", "age": {$ne: 103}})
```

#### 2) $and、$or、$nor、$not、$mod、$in、$all、$exists、null、正则表达式

```sh
# 等同于：db.users.find({"userId": "u1", "age": {$ne: 103}})
db.users.find({$and: [{"userId": "u1"}, {"age": {$ne: 103}}]})

# $or操作
db.users.find({$or: [{"userId": "u1"}, {"age": {$ne: 103}}]})

# $nor操作
db.users.find({$nor: [{"userId": "u1"}, {"age": {$ne: 103}}]})

# $not,只能用在条件判断里或正则表达式里
db.users.find({"age": {$not: {$gt: 100}}}) # 条件判断
db.users.find({"userId": {$not: /u1/}}) # 正则表达式，不显示 "u1"

# 求模
db.users.find({"age": {$mod: [100, 3]}})

# $in
db.users.find({"age": {$in: [103, 104]}})

# $all 完全配置
db.users.find({"age": {$all: [103, 104]}})

# $exists,必需包含某个字段
db.users.find({"name": {$exists: 1}})

# 配置到某个字段不存在，或某个字段为空的数据
db.users.find({"name": null})

# 正则表达式
db.users.find({"userId": /u1/})
```

#### 3) 集合查询

```sh
# 集合中第1个元素 == 5 的数据
db.users.find({"score.1":5})

# 集合长度为 3 的数据
db.users.find({"score": {$size: 3}})

# 只显示集合的前两个元素
db.users.find({"score": {$exists: 1}}, {"score": {$slice: 2}})

# 多条件查询
db.users.find({"score": {$elemMatch: {$gt:4,$lt:6}}})

# 查询内嵌对象
db.users.find({"score.key1":{$gt:1, $lte:9}})
db.users.find({"score.yw":{$lte:80}, "score.sx":90})
```

#### 4) JavaScript查询

```sh
# 定义t1函数
function t1(){
	for (var a in this){
		if(a.userId!=null){
			return true;
		}
	}
	return false;
}
# 使用 t1 函数查询
db.users.find({$where:t1})

# 注意：性能比较差，安全性也是问题
```

#### 5、聚合函数

**count()**

```sh
 db.users.count() # 或
 db.users.find().count()
```

**limit()**

```
db.users.find().limit(2)
```

**skip()**

```sh
db.users.find().skip(2)

# 数据量比较大的话，不建议使用skip来分页;
# 也可以使用其他方式来分布，比如采用自定义的id（自增），然后根据id来分页
```

**sort()**

```sh
# 1-顺序，2-倒序
db.users.find().sort({"userId":-1})
```

### 6、游标

```js
var c = db.users.find();

while(c.hasNext()){
	printjson(it.next())
}

// c 是游标，取完值后c就为空了

// 也可以这样子输出
c.forEach(function(obj){
    printjson(obj)
})
```

### 7、存储过程

**定义函数**

```js
var addF = function(a, b){
	return a+b;
}
```

**创建存储过程**

```sh
# db.system.js.save({"_id":名称, "value":函数名称})
db.system.js.save({"_id":"myF", "value":addF})
```

**查询系统中定义的存储过程**

```
db.system.js.find()
```

**调用存储过程**

```sh
# db.eval(名称)
db.eval("myF(3,5)")  # 输出 8
```

## 四、聚合框架

MongoDB的聚合框架，主要用来对集合中的文档进行变换和组合，从而对数据进行分析加以利用。

聚合框架的基本思想是：采用多个构件来创建一个管道，用于对一连串的文档进行处理。这些构件包括：<u>筛选(filtering)、投影(projecting)、分组(grouping)、排序(sorting)、限制(limiting)和跳过(skipping)</u>。

使用聚合框架的方式：

```
db.集合.aggregate(构件1, 构件2....)
```

> 注意：由于聚合的结果要返回到客户端，因此聚合结果必需限制在16M以内，这是MongoDB支持的最大响应消息大小。

```js
// 添加400失记录
for (var i=0;i<100;i++){
    for(var j=0;j<4;j++){
    	db.scores.insert({"userId":"s"+i, "course":"课程"+j,"score":Math.random()*100});
    }
}
```

### 0、案例(Hello World)：

#### 第1步、查询所有考了80分以上的学生:

```sh
# {$match: {"score": {$gte: 80}}}
db.scores.aggregate({
	$match: {"score": {$gte: 80}}}
)
```

#### 第2步、将每个学生的名称投影出来：

```sh
# 构件：{$project: {"userId": 1}}
db.scores.aggregate(
	{$match: {"score": {$gte: 80}}}, 
	{$project: {"userId": 1}}
)
```

#### 第3步、对学生的名字排序，某个学生的名字只出现一次，就给他加 1:

```sh
# {$group: {"_id":"$userId", "count": {$sum: 1}}}, "count"是一个自定义字段
db.scores.aggregate(
	{$match: {"score": {$gte: 80}}}, 
	{$project: {"userId": 1}}, 
	{$group: {"_id":"$userId", "count": {$sum: 1}}}
)
```

#### 第4步、对结果集按照count进行降序排列

```sh
# {$sort: {"count": -1}} , 对count字段排序 -1：降序，1：正序
db.scores.aggregate(
	{$match: {"score": {$gte: 80}}}, 
	{$project: {"userId": 1}}, 
	{$group: {"_id":"$userId", "count": {$sum: 1}}}, 
	{$sort: {"count": -1}}
)
```

#### 第5步、返回前3条记录

```sh
# {$limit: 3}
db.scores.aggregate(
	{$match: {"score": {$gte: 80}}}, 
	{$project: {"userId": 1}}, 
	{$group: {"_id":"$userId", "count": {$sum: 1}}}, 
	{$sort: {"count": -1}}, 
	{$limit: 3}
)
```

### 1、聚合框架

**管道操作符简介：**

> <h5 style="color:#FF00F0">每个操作符接受一系列的文档，对这些文档做相应的处理，然后把转换后的文档作为结果传递给下一个操作符。最后一个操作符会将结果返回。</h5>
>
> <h5 style="color:#FF00F0">不同的管道操作符，可以按照任意顺序，任意个数组合在一起使用</h5>

#### 1) $match

用于对文档集合进行筛选，里面**可以使用所有常规的查询操作符**。通常放置在管道最前面的位置，理由如下：

* 快速将不需要的文档过滤，减少后续操作的数据量
* 在投影和分组之前做筛选，查询可以使用索引

#### 2) $project

用来从文档中提取字段，可以指定包含和排除字段，也可以重命名字段。比如要将studentId改为sid，如下：

```sh
db.scores.aggregate({$project: {"sid": "$studentId"}})
```

##### （1）管道操作符$project的数学表达式，比如给成绩集体加20分，如下：

```sh
db.scores.aggregate({$project: {"newScore": {$add: ["$score", 20]}}})
# db.scores.aggregate({$project: {"_id":0, "userId":1,"score":1,  "newScore": {$add: ["$score", 20]}}})
```

##### （2）管理操作符$project的日期表达式

聚合框架包含了一些用于提取日期信息的表达式，如下：

>  $year, $month, $week, $dayOfMonth, $dayOfWeek, $dayOfYeay, $hour, $minute, $second

注意：这些只能操作日期型的字段，不能操作数据，使用示例：

```sh
{$project: {"opeDay": {$dayOfMonth: "$recoredTime"}}}
```

##### （3）管理操作符$projec的字符串表达式

```sh
$substr 字符串截取
$concat 字符串连接
$toLower
$toUpper
# 例如
db.scores.aggregate(
{$project: {
    "_id":0, 
    "uid":{$concat:["$userId","aaa"]},  # 字符串连接
    "score":1,  
    "newScore": {$add: ["$score", 20]}}}
)
```

##### （4）管理操作符$projec的逻辑表达式

> $eq, $ne, $gte, $gt, $lte, $lt, $and, $or, $not, $ifNull......

#### 3）$group

用来将文档依据特定字段的不同值进行分组。选定了分组字段过后，就可以把这些字段传给$group函数的"_id"字段。例如：

```sh
db.scores.aggregate({$group:{"_id": "$studentId"}}); # 按 studentId 字段分组
db.scores.aggregate({$group: {"_id": {"sid": "$studentId", "score":"$score"}}}) # 按 studentId 和 score 字段分组
```

$group支持的操作符

| 操作符         | 描述                                                         |
| -------------- | ------------------------------------------------------------ |
| $sum:value     | 对于每个文档分组的平均值                                     |
| $avg:value     | 返回每个分组的平均值                                         |
| $max:expr      | 返回分组内的最大值                                           |
| $min:expr      | 返回分组内的最小值                                           |
| $first:expr    | 返回分组的第一个值，忽略其他的值，一般只有排序后，明确知道数据顺序的时候，这个操作才有意义 |
| $last:expr     | 与上面一个相反，返回分组的最后一个值                         |
| $addToSet:expr | 如果当前数组中不包含expr，那就将它加入到数组中               |
| $push:expr     | 把expr加入到数组中                                           |

**案例**

```sh
# 求出所有人的平均分
> db.scores.aggregate({$group: {"_id": "$userId", "avgScore": {$avg: "$score"}}})
{ "_id" : "s99", "avgScore" : 75.76066351030022 }
{ "_id" : "s97", "avgScore" : 35.54359102854505 }
{ "_id" : "s95", "avgScore" : 54.64489869773388 }
{ "_id" : "s94", "avgScore" : 52.169793570647016 }
{ "_id" : "s93", "avgScore" : 50.86269551538862 }
{ "_id" : "s92", "avgScore" : 61.06720945099369 }
{ "_id" : "s90", "avgScore" : 41.11441081040539 }
{ "_id" : "s98", "avgScore" : 56.571172951953486 }
{ "_id" : "s89", "avgScore" : 61.568312044255435 }
{ "_id" : "s84", "avgScore" : 36.8549324455671 }
{ "_id" : "s83", "avgScore" : 58.725763706024736 }
{ "_id" : "s87", "avgScore" : 40.51579721271992 }
{ "_id" : "s86", "avgScore" : 63.34823765209876 }
{ "_id" : "s82", "avgScore" : 53.65498082828708 }
{ "_id" : "s81", "avgScore" : 57.088160095736384 }
{ "_id" : "s80", "avgScore" : 53.707223519450054 }
{ "_id" : "s76", "avgScore" : 71.61178048700094 }
{ "_id" : "s78", "avgScore" : 28.316039184574038 }
{ "_id" : "s48", "avgScore" : 67.39862706162967 }
{ "_id" : "s75", "avgScore" : 51.421846623998135 }
Type "it" for more
```

#### 4）$unwind

用来把数组中的每个值拆分成为单独的文档，如下：

```sh
> db.t1.find()
{ "_id" : ObjectId("5e378e0fe1ac29c7347bbcf6"), "userId" : "u1", "score" : [ 10, 20, 30 ] }
> db.t1.aggregate({$unwind: "$score"})
{ "_id" : ObjectId("5e378e0fe1ac29c7347bbcf6"), "userId" : "u1", "score" : 10 }
{ "_id" : ObjectId("5e378e0fe1ac29c7347bbcf6"), "userId" : "u1", "score" : 20 }
{ "_id" : ObjectId("5e378e0fe1ac29c7347bbcf6"), "userId" : "u1", "score" : 30 }
```

#### 5）$sort

排序，强烈建议在管道的第一个阶段进行排序，这时可以使用索引。

#### 6）count

用于返回集合中文档的数量

#### 7）distinct

找出给定键的所有不同值，使用时必须指定集合和键，如：

```sh
db.runCommand({"distinct":"users", "key":"userId"})
```

### 2、MapReduce

MongoDB的聚合框架中，还可以使用MaprReduce，它非常强大和灵活，但具有一定的复杂性，专门用于实现一些复杂的聚合功能。

MongoDB中的MapReduce使用JavaScript来作为查询语言，因此能表达任意的逻辑，<u>但是它运行非常慢，不应该用在实时数据分析中</u>。

#### 案例：实现功能，找出集合中所有的键，并统计每个键出现的次数

**Map 函数**使用**emit函数来返回**要处理的值，示例如下：

```js
var map = function(){
    // this 表示对当前文档的引用
	for (var key in this) {
		emit(key, {count: 1});  // key每出现一次就追加，并返回，不能使用return返回
	}
}
```

**Reduce函数**需要处理Map阶段或者是前一个Reduce的数据，因此Reduce返回的文档必须要能作为Reduce的第二个参数的一个元素，示例如下:

```js
var reduce = function (key, emits) {
	var total = 0;
    for (var i in emits) {
        total += emits[i].count;
    }
    return {"count": total};
}
```

**运行MapReduce**，示例如下：

```js
var mr = db.runCommand({
	"mapreduce":"scores", // 操作的集合
	"map":map,            // Map函数名
	"reduce": reduce,     // Reduce函数名
	"out":"myout"         // 结果存放的集合
})
```

运行后会得到一个新的集合：myout

**查询myout集合**信息:

```sh
> db.myout.find()
{ "_id" : "_id", "value" : { "count" : 400 } }
{ "_id" : "course", "value" : { "count" : 400 } }
{ "_id" : "score", "value" : { "count" : 400 } }
{ "_id" : "userId", "value" : { "count" : 400 } }
```

#### 更多MapReduce可选的键

|                   |                                                         |
| ----------------- | ------------------------------------------------------- |
| finalize:function | 可以将reduce的结果发送到finalize,这是整个处理的最后一步 |
| keeptemp:boolean  | 是否连接关闭的时候，保存临时结果集合                    |
| query:document    | 在发送给map前对文档进行过滤                             |
| sort:document     | 在发送给map前对文档进行排序                             |
| limit:integer     | 发往map函数的文档数量上限                               |
| scope:document    | 可以在javascript中使用的变量                            |
| verbose:boolean   | 是否记录详细的服务器日志                                |

