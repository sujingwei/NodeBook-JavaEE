## 1、架构

![k8s架构](http://notebook-1.aoae.top/16157791694284)

## 2、Kubernetes集群

**安装方式：**

- kubeadm，是官方为了简化k8s的部署开发的工具
- 二进制，针对不同的平台，一步一步的部署
- Minikube
- Yum

**安装工具：**

| 工具/命令 | 作用 |
| --------- | ---- |
| docker    |      |
| kubeadm   |      |
| kubelet   |      |
| Kubectl   |      |

Kubeadm是官方社区推出的一个用于快速部署k8s的集群工具。用这个工具能通过两条指令完成一个k8s集群的部署。

```sh
# 初始化Master节点
kubeadm init

# 将一个node节点加入到当前集群中
kubeadm join <Master>节点的IP和端口
```

### 1)、安装要求

- 一台或多台centos 7的服务器
- 2核2G内存
- 集群中所有机器之间网络互通
- 禁止swap分区

配置3台Linux服务器，如下：

```sh
[root@k8s-3 ~]# cat /etc/hosts
127.0.0.1   localhost
192.168.1.126 k8s-1
192.168.1.127 k8s-2
192.168.1.128 k8s-3
```

通过上面的hosts文件，可以确定这3台节点。

### 2)、所有节点要安装Docker/Kubeadm/kubelet/kubectl

Kubernetes默认(容器运行时)为Docker，因此先安装Docker

#### (1) 安装Docker

```sh
# 配置阿里云的源
wget https://download.docker.com/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo

# docker，请复制
yum install -y docker-ce-18.06.1.ce-3.el7

# 启动docker
systemctl enable docker 
systemctl start docker

# 查看版本
docker --version
```

#### (2)配置阿里云软件包

> kubeadm、kubelet和kubectl没有办法安装，需要配置阿里云源

**vim /etc/yum.repos.d/kubernetes.repo** 

```ini
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg                                              
```

#### (3) 安装kubeadm、kubelet和kubectl

```shell
yum install kubelet-1.15.0 kubeadm-1.15.0 kubectl-1.15.0
```

## 3、部署Master与Node加入集群

**K8s-1**

```sh
kubeadm init \ 
--apiserver-advertise-address=192.168.1.126 \
--image-repository registry.aliyuncs.com/google_containers \
--kubernetes-version v1.15.0 \
--service-cidr=10.1.0.0/16 \
--pod-network-cidr=10.244.0.0/16
```





