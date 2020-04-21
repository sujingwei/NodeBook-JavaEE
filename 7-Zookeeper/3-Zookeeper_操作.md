# 一、Zookeeper CLI

ZooKeeper命令行界面（CLI）用于与ZooKeeper集合进行交互以进行开发。它有助于调试和解决不同的选项。

要执行ZooKeeper CLI操作，首先打开ZooKeeper服务器（“bin/zkServer.sh start”），然后打开ZooKeeper客户端（“bin/zkCli.sh”）。一旦客户端启动，你可以执行以下操作：

- 创建znode
- 获取数据
- 监视znode的变化
- 设置数据
- 创建znode的子节点
- 列出znode的子节点
- 检查状态
- 移除/删除znode

现在让我们用一个例子逐个了解上面的命令。

## 1、创建Znodes

- 用给定的路径创建一个znode。flag参数指定创建znode是临时的，持久的还是顺序的。默认情况下，所有znode都是持久的。

- 当会话过期或客户端断开连接时，临时节点(flag: -e)将被自动删除
- 顺序节点保证znode路径将是唯一的
- Zookeeper集合将向znode路径 填充10位序列号。例如，znode路径`/myapp`将转换为`/myapp0000000001`，下一人序列号将为`/myapp0000000002`。如果没有指定`flag`，则znode被认为是持久的。

### 1) 基本创建znode

语法

```sh
create /path /data
```

示例

```sh
[zk: localhost:2181(CONNECTED) 0] create /FirstZnode "Myfirstzookeeper-app"
Created /FirstZnode
```

### 2) 创建顺序节点

要**创建顺序节点**，请添加flag: **-s**，如下所示：

语法

```sh
create -s /path /data
```

示例

```sh
[zk: localhost:2181(CONNECTED) 9] create -s /Firstznode "second-data"
Created /Firstznode0000000001
```

### 3) 创建临时节点

要创建临时节点，请添加flag: -e，如下所示。

语法：

```sh
create -e /path /datasg
```

示例：

```sh
[zk: localhost:2181(CONNECTED) 13] create -e /SecondZnode "Ephemeral-data"
Created /SecondZnode
```

记住当客户端断开连接时，临时节点将被删除。你可以通过退出ZooKeeper CLI，然后重新打开CLI来尝试。

## 2、获取数据

它返回znode的关联数据和指定znode的元数据。你将获得信息，例如上次通过退出Zookeeper CLI，然后重新打开CLI来尝试。

### 1) 获取znode信息

语法：

```sh
# -s 详细信息
# -w 其它
get [-s] [-w] /path
```

示例：

```sh
[zk: localhost:2181(CONNECTED) 1] get /FirstZnode
Myfirstzookeeper-app
```

### 2) 访问顺序节点，必须输入znode的完事路径

示例

```sh
[zk: localhost:2181(CONNECTED) 5] get /FirstZnode0000000003
Firstznode-data
```

## 3、Watch（监视）

当指定Znode或Znode的子数据更改时，监视器会显示通知。你只能在**get**命令中设置**watch**。

语法

```sh
get /path [watch] 1
```

示例

```sh
get /FirstZnode 1
```

## 4、Set设置数据

设置指定znode的数据。完成些设置操作后，你可以使用get cli命令检查数据。

语法

```sh
set /path /data
```

示例

```sh
[zk: localhost:2181(CONNECTED) 24] create /SecondZnode "second-data"
Created /SecondZnode
[zk: localhost:2181(CONNECTED) 25] set /SecondZnode "Data-updated"
[zk: localhost:2181(CONNECTED) 26] get -s /SecondZnode
Data-updated
cZxid = 0x30000000d
ctime = Mon Apr 20 13:01:19 CST 2020
mZxid = 0x30000000e
mtime = Mon Apr 20 13:01:36 CST 2020
pZxid = 0x30000000d
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 12
numChildren = 0
```

## 5、创建子项/子节点

创建子节点类似于创建新的znode。唯一区别是，子znode的路径也是有父路径。

语法：

```sh
create /parent/path/subnode/path /data
```

示例

```shell
[zk: localhost:2181(CONNECTED) 27] create /FirstZnode/clild1 firstchildren
Created /FirstZnode/clild1
[zk: localhost:2181(CONNECTED) 28] get /FirstZnode/clild1
firstchildren
```

## 6、列出子项

此命令用于列出和显示znode的子项

语法

```sh
ls /path
```

示例

```sh
[zk: localhost:2181(CONNECTED) 32] ls /FirstZnode
[Child2, clild1]
```

## 7、检查状态

状态描述指定的znode的元数据。它包含时间戳、版本号、ACL、数据长度和子znode等细项。

语法

```sh
stat /path
```

示例

```sh
[zk: localhost:2181(CONNECTED) 33] stat /FirstZnode
cZxid = 0x300000002
ctime = Mon Apr 20 11:21:29 CST 2020
mZxid = 0x30000000c
mtime = Mon Apr 20 11:48:48 CST 2020
pZxid = 0x300000010
cversion = 2
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 12
numChildren = 2
```

## 8、移除znode

移除指定的znode并递归其所有子节点。只有这样的znode可用的情况下才会发生

### 1) 包含子节点的删除 deleteall

语法：

```sh
delete /path
```

示例

```sh
[zk: localhost:2181(CONNECTED) 36] deleteall /FirstZnode
WATCHER::
WatchedEvent state:SyncConnected type:NodeDeleted path:/FirstZnode
```

### 2）只能删除当前节点 delete

语法

```sh
delete /path
```

示例

```sh
[zk: localhost:2181(CONNECTED) 38] delete /Firstznode0000000001
```

# 二、Zookeeper API

导入依赖

```xml
<!-- https://mvnrepository.com/artifact/org.apache.zookeeper/zookeeper -->
<dependency>
    <groupId>org.apache.zookeeper</groupId>
    <artifactId>zookeeper</artifactId>
    <version>3.6.0</version>
</dependency>
```

创建连接工具类

```java
public class ZooKeeperConnection {

    private ZooKeeper zoo;
    final CountDownLatch connectedSignal = new CountDownLatch(1);
	// 连接
    public ZooKeeper connect(String host) throws IOException, InterruptedException {
        zoo = new ZooKeeper(host, 5000, new Watcher() {
            @Override
            public void process(WatchedEvent we) {
                if (we.getState() == Event.KeeperState.SyncConnected){
                    connectedSignal.countDown();
                }
            }
        });
        connectedSignal.await();
        return zoo;
    }
    
	// 关闭连接
    public void close() throws InterruptedException {
        zoo.close();
    }
}
```

## 1、新建Znode节点

```java
@Test
public void create() {
        String path = "/MyFirstZnode";
        byte[] data = "My First zookeeper app".getBytes();
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");

            zk.create(path, data, ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT);

            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
}
```

## 2、判断znode节点是否存在

```java
@Test
public void exists() {
        String path = "/MyFirstZnode";
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");

            Stat stat = zk.exists(path, true);
            if (stat != null) {
                System.out.println("Node exists and the node version is " +
                        stat.getVersion());
            } else {
                System.out.println("Node does not exists");
            }

            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
}
```

## 3、返回节点数据

```java
@Test
public void getData() {
        final String path = "/MyFirstZnode";
        final CountDownLatch connectedSignal = new CountDownLatch(1);
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");

            Stat stat = zk.exists(path, true);
            if (stat != null) {
                byte[] b = zk.getData(path, new Watcher() {
                    @Override
                    public void process(WatchedEvent we) {
                        if (we.getType() == Event.EventType.None) {
                            switch (we.getState()) {
                                case Expired:
                                    connectedSignal.countDown();
                                    break;
                            }
                        } else {
                            try {
                                byte[] bn = zk.getData(path, false, null);
                                String data = new String(bn, "UTF-8");
                                System.out.println(data);
                                connectedSignal.countDown();
                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }
                    }
                }, null);

                String data = new String(b, "UTF-8");
                System.out.println(data);
                connectedSignal.await();

            } else {
                System.out.println("Node does not exists");
            }

            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
}
```

## 4、设置节点的值

```java
@Test
public void setData() {
        String path = "/MyFirstZnode";
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");

            zk.setData(path, "Success".getBytes(), 
                       zk.exists(path, true).getVersion());

            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
}
```

## 5、返回所有子节点

```java
@Test
public void getChildren() {
        String path = "/MyFirstZnode";
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");
            if (zk.exists(path, true) != null) {
                List<String> children = zk.getChildren(path, false);
                System.out.println(children);
            } else {
                System.out.println("Node does not exists");
            }
            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
}
```

## 6、删除当前节点

```java
@Test
    public void delete() {
        String path = "/MyFirstZnode";
        try {
            conn = new ZooKeeperConnection();
            zk = conn.connect("192.168.25.89");
            Stat stat = zk.exists(path, true);
            if (stat != null) {
                zk.delete(path, stat.getVersion());
            } else {
                System.out.println("Node does not exists");
            }
            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
```

