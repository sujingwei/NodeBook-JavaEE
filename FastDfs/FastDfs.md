FastDFS服务端有两个角色：跟踪器(tracker)和存储节点(storage)。跟踪器主要做调度工作，在访问上起负载均衡作用。

## 一、Linux下安装FastDfs

### 1、安装FastDFS

#### 1）、安装gcc

```sh
yum install -y gcc-c++ gcc
yum install -y libevent
yum install -y perl pcre pcre-devel zlib zlib-devel openssl openssl-devel
```

#### 2）、安装libfastcommon

```sh
tar -zxvf libfastcommon-1.0.35.tar.gz
cd libfastcommon-1.0.35/
./make.sh 
./make.sh install
```

#### 3）、安装fastdfs

```sh
tar -zxvf fastdfs-5.11.tar.gz
cd fastdfs-5.11/
make && make install
```

#### 4）、查看tracker和storage的可执行脚本

```sh
ls -l /etc/init.d/ | grep fdfs
> xx xx xx xx fdfs_storaged
> xx xx xx xx fdfs_trackerd
```

#### 5）、准备配置文件

> cd /etc/fdfs/

```sh
cp client.conf.sample client.conf
cp storage.conf.sample storage.conf
cp storage_ids.conf.sample storage_ids.conf
cp tracker.conf.sample tracker.conf
```

#### 6）、修改tracker的存放数据和日志的目录

> cd /etc/fdfs/

`vim tracker.conf`

```sh
#  放数据和日志的目录
base_path=/home/sjw/fastdfs/tracker
```

#### 7）、启动tracker

````sh
service fdfs_trackerd start
````

启动成功后会在`/home/sjw/fastdfs/tracker`目录下创建两个目录：`data`和`logs`。

#### 8）、配置storage

> cd /etc/fdfs/

`vim storage.conf`

```sh
# 配置组名，访问文件的时候，需要配置组名
group_name=group1

# base_path
base_path=/home/sjw/fastdfs/storage

# store存放文件的位置
store_path0=/home/sjw/fastdfs/storage
# store_path1=/home/sjw/fastdfs/storage # 可以配置多个
# store_path2=/home/sjw/fastdfs/storage # 可以配置多个

# 配置tracker的地址，查询tracker.conf可以看到端口信息
tracker_server=127.0.0.1:22122
```

#### 9）、启动storage

```sh
service fdfs_storaged start
```

启动成功后查看`ls /home/sjw/fastdfs/storage/data`目录，会发现多了很多文件夹。

### 2、测试上传

#### 1）、修改client.config

```sh
base_path=/home/sjw/fastdfs/storage
# 配置tracker的地址，查询tracker.conf可以看到端口信息
tracker_server=127.0.0.1:22122
```

#### 2）、上传操作

```sh
# 上传图片
/usr/bin/fdfs_upload_file /etc/fdfs/client.conf /root/baobao.png 
> group1/xx/xx/xxx/xxxxxxxx.jpg #上传成功，返回路径
```

#### 3）、查看上传图片

目前无法查询，需要整合nginx才可以查看上传的图片信息

### 3、安装Nginx

略。