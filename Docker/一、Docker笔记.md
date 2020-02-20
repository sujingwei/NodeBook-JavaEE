# 一、Docker的安装

参考官网CentOS的安装方式:

https://docs.docker.com/install/linux/docker-ce/centos/

# 二、容器的基本操作

docker ps [-a] [-i]

docker rm ID

docker run [ubuntu] echo "Hello World"

# 三、镜像的命令

## 1、docker images

```shell
# 参数列表
-a # 列出本地所有的镜像（含中间映像层，默认情况下，过滤掉中间映像层）
-q # 只显示IMAGE ID
--digests  # 显示镜像的摘要信息
--no-trunc  # 显示完整的镜像信息
```

```shell
# 输出列表
REPOSITORY 镜像的仓库源
TAG 镜像标签
IMAGE ID 镜像创建时间
SIZE 镜像大小
```

​	同一仓库可以有多个TAG，代表这个仓库源的不同版本，我们使用`REPOSITORY:TAG`来定义不同的镜像。如果你不指定一个镜像的版本标签，例如你只使用`ubuntu`, docker默认使用`ubuntu:latest`镜像。

## 2、docker search

查询 docker hub 里的镜像源

网页查询：[https://hub.docker.com](https://hub.docker.com/)

使用方式：

docker search tomcat

```shell
# 参数说明
--no-trunc # 显示完事的镜像描述信息
-s # 列出点收藏数不小于指定值的镜像 docker search -s 30 tomcat, 显示收藏数大于30的镜像
--automated # 只列出AUTOMATED值等于OK的镜像
```

## 3、docker pull

从docker hub上下载镜像，如果下载速度比较慢的话，那可以使用阿里云镜像

```shell
docker pull tomcat[:latest] # 下载最新的镜像
```

## 4、docker rmi

删除镜像

使用方式：

docker rmi hello-world/镜像ID

```shell
docker rmi -f hello-world  # 加上 -f 可以强制删除
docker rmi -f hello-world nginx # 删除多个镜像
docker rmi -f $(docker images -q) # 删除所有镜像
```

# 四、Docker容器命令（上）

## 1、新建并启动容器 docker run

新建并启动容器

使用方式：

docker run [OPTIONS] IMAGE [COMMAND] [ARGS...]

```shell
# 参数
--name="容器新名字"  # 为容器指定一个名字
-d  # 后台运行容器，并返回容器的ID
-i  # 以交互模式运行容器，通常与-t同时使用
-t  # 为容器重新分配一个伪终端，通常能 -i 同时使用
-P  # 随机端口映射
-p  # 指定端口映射，有以下四种格式
	-p ip:hostPort:containerPort
	-p ip:containerPort
	-p hostPort:containerPort
	-p containerPort
```

####  docker run -it  IMAGE_ID/容器名，生成容器

**生成并登录到容器**

```shell
docker run -it centos 
```

## 2、查看容器 Docker ps

显示列表：

```shell
CONTAINER ID    # 容器ID
IMAGE           # 镜像ID
COMMAND         # 命令行
CREATED         # 容器创建时间
STATUS          # 容器运行状态
PORTS           # 容器映射端口
NAMES           # 容器名称
```

参数列表：

```shell
-a  # 列出当前运行的容器和历史上运行过的容器
-l  # 显示最近创建的容器
-n  # 显示最近n个创建的容器
-q  # 静默模式，只显示容器编号
--no-trunc  # 不截断输出
```

## 3、退出容器

### (1)、在容器系统中

```
exit (回车)
```

* 退出后容器会停止运行，相当于Linux的关机

### (2)、在容器系统中

`Ctrl + P + Q`

* 退出后容器还在运行，相当于Linux的退出登录

### (3)、开启&重启关闭的容器

```shell
docker start 16428639fcff    # 开启关闭的容器
docker restart 16428639fcff  # 重启容器
```

### (4)、停止容器

```shell
docker stop 16428639fcff   # 慢慢停止(关)
docker kill 16428639fcff   # 强制停止(关)
```

## 4、删除已停止的容器

语法方式:

docker rm 容器ID

```shell
docker rm 16428639fcff         # 删除
docker rm -f 16428639fcff      # 强制删除
docker rm -f $(docker ps -qa)  # 删除所有的容器
```

# 五、Docker容器命令（下）

## 1、后台运行服务

​	如：`docker run -d centos`；加上`-d`参数就可以在后台运行了，但是但通过`docker ps`查看，就会发现容器已经退出。很重要的一个说明：<u>Docker后台运行，就必须有一个前台进程</u>。容器运行的命令如果不是那些<u>一直挂起的命令(比如top, tall)</u>，就会自动退出。这是docker的机制问题，比如你的web容器，我们以nginx为例，正常情况下，我们配置启动服务只需要启动响应的service即可。例如`systemctl start nginx`。但是，这样做，nginx为后台进程模式运行，就导致docker前台没有运行应用，这样 的容器启动后就会立即自杀，因为它学得没事可做了。所以最佳的解决方案是：将你要运行的程序以<u>前台进程</u>的形式运行。

## 2、查看容器日志

docker logs 21f6c1905e49

```shell
-t          # 日志加上时间
-f          # 显示所有的日志，Ctrl+C 退出
--tail num  # 显示最后几行的日志
```

## 3、查看容器内的进程

docker top 容器ID/容器名

## 4、查看容器内部的细节

docker inspect 容器ID/容器名

## 5、重新进入容器

`docker attach 9a82b1db3581`

这样就可以重新进入容器了

docker exec -t 9a82b1db3581 /bin/bash  # 这样也可以进入到容器中

## 6、执行容器脚本

`docker exec -t 9a82b1db3581 ls -l /tmp`

这样就可以在容器外执行脚本

`docker exec -t 9a82b1db3581 /bin/bash` # 这样也可以进入到容器中

## 7、拷贝容器的文件到主机上

```shell
# 把容器9a82b1db3581,/tmp/yum.log 拷贝到 主机/root 目录里
docker cp 9a82b1db3581:/tmp/yum.log /root/
```

```shell
# 把主机里的www目录拷贝到容器中
docker cp  /works/www 9a82b1db3581:/www
```

## 8、通过容器生成镜像

`docker commit -m="提交的描述信息" -a="作者" 容器ID 要创建的目标镜像名[:标签名]`

```shell
# 通过容器创建sujingwei/tomcat:1.2镜像
docker commit -m="tomcat new image" -a="sujingwei" tomcat_id \
sujingwei/tomcat:1.2
```

# 六、容器数据卷

容器在关闭(shop|kill)后它里面的数据就会掉失。容器数据卷是用于做数据持久化的。

* 对容器里的数据进行持久化

* 容器之间共享数据

特点：

* 数据卷可以在容器之间共享或重用数据
* 卷中的更改可以直接生效
* 数据卷中的更改不会包含在镜像的更新中
* 数据卷的生命周期一直持续到没有容器使用它为止

## 1、命令添加数据卷

`docker run -it -v /宿主机绝对路径目录:/容器内目录 镜像名`

```shell
# 新建容器，并指定了容器的/dataValumn目录和主机/hostVolumn目录共享数据
# 当主机/hostVolumn目录中的文件改变的时候，容器/dataValumn目录里的文件一同更改
# 当容器/dataValumn目录里的文件改变的时候，主机/hostVolumn目录里的文件一同更改
# 当容器里停用（shop|kill）后，可以通过 docker start 容器ID 再次启用，文件再次同步
docker run -it -v /hostVolumn:/dataValumn centos
```

```shell
# 同上
# 加上:ro 表示容器/dataValumn只读，但不可写
# /hostVolumn目录写入，/dataValumn同步
# /dataValumn目录不可写入
docker run -it -v /hostVolumn:/dataValumn:ro centos
```

## 2、DockerFile添加数据卷

出于可移植和分享的考虑，用-v 主机目录:容器目录这种方法不能够直接在Dockerfile中实现。由于宿主机目录是依赖于特定宿主机的，并不能够保证在所有的宿主机上都存在这样的特定目录。

### 第一步 创建DockerFile文件

```dockerfile
# /mydocker/dockerfile
FROM centos
VOLUME ["/dataVolumnContainer1", "/dataVolumnContainer2"]
CMD echo "finished,----------success1"
CMD /bin/bash
```

执行上边代码相当于：`docker run -it -v /host1:dataVolumnContainer1 -v /host2:dataVolumnContainer2 centos /bin/bash`

### 第二步 通过Docker build 创建镜像

```shell
# 通过dockerfile文件创建镜像
docker build -f /mydocker/dockerfile -t zzyy/centos .
```

### 第三步 通过镜像生成容器

```shell
# 在生成的容器里已经生成了/dataVolumnContainer1和/dataVolumnContainer2卷目录
docker run -it zzyy/centos /bin/bash
```

进入容器后，你会发现已经生成了/dataVolumnContainer1和/dataVolumnContainer2卷目录。那主机里的共享目录在哪里呢？这个时候可以在主机里通过`docker inspect`命令查看

`docker inspect 54ba68c85a57`

```json
[
    {
        "Id": "54ba68c85a579a6ba1cd4bafc31068ef09119f010691580218ef9f2a91ffdbf6",
        "Created": "2019-05-25T06:44:14.067021794Z",
        "Path": "/bin/sh",
        ......
        "Mounts": [
            {
                "Type": "volume",
                "Name":  					 "34b653cb144f0c7765e16eaac8cf4dda6823513ff939eb1c0bc9150ea83eb1b7",
                "Source": "/var/lib/docker/volumes/34b653cb144f0c7765e16eaac8cf4dda6823513ff939eb1c0bc9150ea83eb1b7/_data",
                "Destination": "/dataVolumnContainer1",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            },
            {
                "Type": "volume",
                "Name": "52f4ae09d17d2fc1f6909d85ae9909c81907ee6392722fac4a2a102b954e1638",
                "Source": "/var/lib/docker/volumes/52f4ae09d17d2fc1f6909d85ae9909c81907ee6392722fac4a2a102b954e1638/_data",
                "Destination": "/dataVolumnContainer2",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "54ba68c85a57",
            "Volumes": {
                "/dataVolumnContainer1": {},
                "/dataVolumnContainer2": {}
            },
        }
    }
]
```

## 3、数据卷容器

​	命名容器挂载数据卷，其它容器通过挂载这个(父容器)实现数据共享，挂载数据卷的容器，称之为数据卷容器。

语法：

`docker run -it -name dc02 --volumes-from dc01 zzyy/centos`

`docker run -it -name dc03 --volumes-from dc01 zzyy/centos`

上面创建了dc02和dc03都挂载了dc01容器，这时候dc01里的/dataVolumnContainer1和/dataVolumnContainer2卷目录会同时和dc02、dc03共享数据。

#### 如果删除dc01

如果删除dc01，那么dc02和dc03的数据还会共享，在dc02的/dataVolumnContainer2卷目录里更新文件，dc03里的文件也会更新

# 七、DockerFile

* DockerFile是用来构建Docker镜像的构建文件，是由一系列命令和参数构成的脚本。
* 构建三步骤：编写Dockerfile文件、docker build 、docker run

**以Centos6.8的DockerFile文件为例：**

```dockerfile
# 继承于scratch（原镜像）
FROM scratch
# 作者+邮箱
MAINTAINER The CentOS Project <cloud-ops@centos.org>
ADD c68-docker.tar.xz /
LABEL name="CentOS Base Image" \
    vendor="CentOS" \
    license="GPLv2" \
    build-date="2016-06-02"

# Default command
CMD ["/bin/bash"]
```

**DockerFile的基础知识：**

* 每条保留字指令必须为大写字母且后面要跟随至少一个参数
* 指令按照从上到下，顺序执行
* #表示注释
* 每条指令都会创建一个新的镜像层，并对镜像进行提交

**Docker执行DockerFile的大致流程：**

+ docker从基础镜像运行一个容器

+ 执行一条指令并对容器作出修改
+ 执行类似docker commit的操作提交一个新的镜像层
+ docker再基于刚提交的镜像运行一个新容器
+ 执行dockerfile中的下条指令直到所有指令都执行完成

## 1、保留字指令

| 关键字     | 关键词说明                                                   |
| ---------- | ------------------------------------------------------------ |
| FROM       | 基础镜像，当前编写的镜像是基于哪个镜像的                     |
| MAINTAINER | 镜像维护者的姓名和邮箱地址                                   |
| RUN        | 容器构建时需要运行的命令                                     |
| EXPOSE     | 容器暴露出镜像的端口                                         |
| WORKDIR    | 指定在创建容器后，终端默认登录到容器的工作目录 WORKDIR /works |
| ENV        | 用来构建镜像过程中设计环境变量， ENV MY_PATH /usr/local/mypath |
| ADD        | 在构建镜像的时候把指定架包拷贝并压缩到镜像容器中，参考centos6.8 |
| COPY       | 同上, 但不解压架包                                           |
| VOLUME     | 创建数据卷目录，用于数据持久化                               |
| CMD        | 指定一个容器启动时要执行的命令，可以有多个CMD，但只有最后一个会生效 |
| ENTRYPOINT | 同上，多个ENTRYPOINT                                         |
| ONBUILD    | 当构建一个被继承的DockerFile时运行命令，父镜像在被子继承后父镜像的onbuild被触发 |

## 2、自定义CentOS镜像

编写DockerFile文件

```dockerfile
# /mydocker/dockerfile2
FROM centos
MAINTAINER zzyy<zzyy167@126.com>

ENV MYPATH /usr/local
WORKDIR $MYPATH

RUN yum install -y vim
RUN yum install -y net-tools

EXPOSE 80

CMD echo $MYPATH
CMD echo "success --------------- ok"
CMD /bin/bash
```

执行build命令，生成镜像

```shell
docker build -f /mydocker/dockerfile2 -t mycentos:1.3 .
# 在生成过程中，yum命令可能没有办法执行，这时候要关闭宿主机，重启docker服务

# 运行
docker run -it mycentos:1.3
```

## 3、ENTRYPOINT和CMD区别

### 情况一：docker run myip -i

```dockerfile
# /mydocker/dockerfile3
FROM centos
RUN yum install -y curl
CMD ["curl", "-s", "http://ip.cn"]
```

如果DockerFile文件使用CMD命令，那么就会报错，因为 -i 参数会覆盖原来的CMD命令，变成没有意义的 -i

### 情况二：docker run myip2 -i

```dockerfile
# /mydocker/dockerfile4
FROM centos
RUN yum install -y curl
ENTRYPOINT ["curl", "-s", "http://ip.cn"]
```

如果DockerFile文件使用了ENTRYPOINT命令，那么 -i 就会追加到原来的命令上，正常运行

## 4、安装自定义Tomcat

### (1) dockerfile

```dockerfile
FROM centos
MAINTAINER zzyy<zzyybs@163.com>
# 把宿主机当前上下文的c.txt拷贝到容器/usr/local路径下
COPY c.txt /usr/local/ci8ncontainer.txt
# 把java和tomcat从宿主机中拷贝到容器的/usr/local并解压
ADD jdk-8u171-linux-x86.tar.gz /usr/local
ADD apache-tomcat-9.0.8.tar.gz /usr/local
# 安装vim编辑器
RUN yum install -y vim
# 设置工作访问的WORKDIR路径，和登录后目录
ENV MYPATH /usr/local
WORKDIR $MYPATH
# 配置java与tomcat环境变量
ENV JAVA_HOME /usr/local/jdk1.8.0_171
ENV CLASSPATH $JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
ENV CLASS_LINA_HOME /usr/local/apache-tomcat-9.0.8
ENV CLASS_LINA_BASE /usr/local/apache-tomcat-9.0.8
ENV PATH $PATH:$JAVA_HOME/bin:$CATALINA_HOME/lib:$CATALINA_HOME/bin
# 容器运行时监听的端口
EXPOSE 8080
CMD /usr/local/apache-tomcat-9.0.8/bin/startup.sh && tail -F /usr/local/apache-tomcat-9.0.8/bin/logs/catalina.out
```

### (2) build

```shell
docker build -f /mydocker/dockerfile3 -t tomcat9:1.2 .
```

### (3) run

```shell
docker run -d -p 7777:8080 --name myt9 \
-v /zzyy/mydockerfile/tmycat9/test:/usr/local/apache-tomcat-9.0.8/webapps/test\
-v /zzyy/mydockerfile/tomcat9/tomcat9logs/:/usr/local/apache-tomcat-9.0.8/lobs\
--privileged=true \
tomcat9:1.2
```

# 八、安装Mysql和Redis

## 1、安装MySQL

### (1) DockerFile(不需要)

不需要都可以，使用官方提供DockerFile

```shell
# 安装mysql5.6镜像
docker pull mysql:5.6
```

### (2) 运行

```shell
docker run -p 3306:3306 --name mysql \
-v /zzyyuse/mysql/conf:/etc/mysql/conf.d \
-v /zzyyuse/mysql/logs:/logs \
-v /zzyyuse/mysql/data:/var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=123456 \
-d mysql:5.6
```

### (3) 数据备份

```shell
docker exec c8aec7fdd88e sh -c ' exec mysqldump -u root -p "123456" --all-databases > /zzyyuse/all-database.sql'
```

## 2、安装Redis

### (1) 安装Redis镜像

```shell
 docker pull redis:3.2
```

### (2) 运行

```shell
docker run -p 6379:6379 --name redis \
-v /zzyyuse/myredis/data:/data \
-v /zzyyuse/myredis/conf/redis.conf:/usr/local/etc/redis/redis.conf \
-d redis:3.2 redis-server /usr/local/etc/redis/redis.conf \
--appendonly yes
```

### (3) 使用

```shell
docker exec -it 45ffc2450ca6 redis-cli
```

## 3、安装nginx

### (1) 安装nginx

```shell
docker pull nginx:1.16  # 这里我安装的是nginx1.16版本
```

### (2) 运行

这里我安装的是nginx 1.6

```shell
# 直接运行
docker run -d nginx:1.16

# 指定数据卷运行
docker run -d -p 8082:80 --name runoob-nginx-test-web 
-v nginx/www:/usr/share/nginx/html \               # 指定项目目录
-v~/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \  # 指定配置文件
-v ~/nginx/logs:/var/log/nginx \                   # 指定日志目录
nginx:1.16                                         # 要运行的镜像          
```

# 九、本地镜像发布到阿里云

##### 生成本地镜像

```shell
docker commit -a 作者 -m "信息" 容器ID 镜像名:标签名
```

##### 登录阿里云

```shell
docker login --username=阿里云帐号
```

##### 创建本地标签号

```shell
docker tag 镜像ID 阿里云帐号/镜像名:标签名
```

##### 发布到阿里云/docker hub

```shell
docker push 阿里云帐号/镜像名:标签名
```

