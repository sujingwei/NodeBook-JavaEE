# Java中的锁

通过下面两个类进行解释

L.java

```java
class L {
  boolean flag = false; // 1 byte
}
```

TestLock.java

```java
class TestLock {
  
  private static L l = new L(); 
  
  private static 
  
  public static void main(String[] args) {
    lockTest();
  }
  
  public static void lockTest() {
    
  }
}
```

## 1、对象头

在JVM中，对象内存中的布局分为三块区域：`对象头`、`实例数据`和对`齐填充数据`。

>  <b style="color:deeppink;">每个GC管理的堆对象开头的公共结构</b>
>
> 包括了堆对象的<i style="color:deeppink;">布局、类型、GC状态、同步状态和标识哈希码</i>的基本信息。由两个"词(bn 也可以叫字长，是CPU单元，分别是Mark Word、Class Metadata Address)"组成。在数组中，它后面紧跟着一个长度字段。注意，Java对象和Jvm内部对象都有一个能用的对象头格式。

一个对象的内存布局：

| 布局     | 描述                                                         |
| -------- | ------------------------------------------------------------ |
| 实例数据 | 实例变量，存在类的属性数据                                   |
| 填充数据 | 如果对象头 + 实例数据的结果不等于 8的倍数，通过填充数据来保证对象所占的内存为：8的最小倍数；<br/>如果对象头 + 实例数据的字节数刚好等于8的位数，那么就不会有填充数据 |
| 对象头   | 每个GC管理的堆对象开头的公共结构                             |

### 1) 查看对象使用内存

引用依赖

```xml
<dependency>
    <groupId>org.openjdk.jol</groupId>
    <artifactId>jol-core</artifactId>
    <version>0.9</version>
</dependency>
```

java脚本

```java
public class App {
    static L l = new L();
    public static void main(String[] args) {
      // 输出 l 对象的内存使用情况
        System.out.println(ClassLayout.parseInstance(l).toPrintable());
    }
}
```

打印内存使用情况:

![](http://notebook-1.aoae.top/16069739721798)

从图片可以看出，前三个 `object header`是对象的头区域平均占**4个字节**；`boolean L.b` 是对象的属性，**占1个字节**；<u>最后是3个字节是填充数据</u>，用于保证整个对象最终使用16个字节的大小，保证最终"L"<b style="color:deeppink;">对象的大小是8的整数倍</b>。

### 2) 什么是对象头

> 每个GC管理的堆对象开头的公共结构，针对64位系统
>
> 对象头的第一组成部分：Mark Word                           64bit
>
> 对象头的第二组成部分：Class Metadata Address.    32bit
>
> 64 + 32 = 96 bit

对象头信息与对象自身定义的数据无关的额外成本，考虑到虚拟机的空间效率，Mark Word被设计成一个非固定的数据结构以便在极小的空间内存储尽量多的信息，它会根据对象状态复用自己的存储空间。

对Mark Word的设计方式上，非常像网络协议报文头：将Mark Word划分为多个比特位区间，并在不同的对象状态下赋于不同的含义。下图为32位虚拟机上，在对象不同状态时Mark Word各个比特位区间的含义。

#### （1）32位系统Mark Word：

<table>
  <thead>
  	<tr>
      <td colspan="6" align="center"><b>32位系统 Mark Word</b></td>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2" align="center">锁状态</td>
      <td colspan="2" align="center">HashCode:25bit</td>
      <td rowspan="2" align="center">age:4bit</td>
      <td align="center">1bit</td>
      <td align="center">2bit</td>
    </tr>
    <tr>
      <td align="center">23bit</td>
      <td align="center">2bit</td>
      <td align="center">是否偏向锁</td>
      <td align="center">锁标志位(lock)</td>
    </tr>
    <tr>
      <td align="center">无锁</td>
      <td colspan="2" align="center">对象的HashCode</td>
      <td align="center">分代年龄</td>
      <td align="center">0</td>
      <td align="center">01</td>
    </tr>
    <tr>
      <td align="center">偏向锁</td>
      <td align="center">线程ID</td>
      <td align="center">Epoch</td>
      <td align="center">分代年龄</td>
      <td align="center">1</td>
      <td align="center">01</td>
    </tr>
    <tr>
      <td align="center">轻量锁</td>
      <td colspan="4" align="left">指向栈中锁记录的指针</td>
      <td align="center">00</td>
    </tr>
    <tr>
      <td align="center">重量锁</td>
      <td colspan="4" align="left">指向重量级锁的指针</td>
      <td align="center">10</td>
    </tr>
    <tr>
      <td align="center">GC标记</td>
      <td colspan="4" align="left">空</td>
      <td align="center">11</td>
    </tr>
  </tbody>
</table>

>  共 4byte = 32bit

**普通对象**

```mysql
|--------------------------------------------------------------|
|                     Object Header (64 bits)                  |
|------------------------------------|-------------------------|
|        Mark Word (32 bits)         |    Klass Word (32 bits) |
|------------------------------------|-------------------------|
```

数组对象

```mysql
|-------------------------------------------------------------------------|
|                                 Object Header (96 bits)                 |
|-----------------------------|--------------------|----------------------|
|        Mark Word(32bits)    | Klass Word(32bits) |  array length(32bits)|
|-----------------------------|--------------------|----------------------|
```

Mark word

```mysql
|-------------------------------------------------------|--------------------|
|                  Mark Word (32 bits)                  |       State        |
|-------------------------------------------------------|--------------------|
| identity_hashcode:25 | age:4 | biased_lock:1 | lock:2 |       Normal       |
|-------------------------------------------------------|--------------------|
|  thread:23 | epoch:2 | age:4 | biased_lock:1 | lock:2 |       Biased       |
|-------------------------------------------------------|--------------------|
|               ptr_to_lock_record:30          | lock:2 | Lightweight Locked |
|-------------------------------------------------------|--------------------|
|               ptr_to_heavyweight_monitor:30  | lock:2 | Heavyweight Locked |
|-------------------------------------------------------|--------------------|
|                                              | lock:2 |    Marked for GC   |
|-------------------------------------------------------|--------------------|
```

#### （2）64位系统Mark Word：

64位系统的Mark Word的内存分配和32位系统略有不同。是否偏向锁也是用了`1bit`，锁标记位也是用了`2bit`。

略。

```mysql
|------------------------------------------------------------------------------|--------------------|
|                                  Mark Word (64 bits)                         |       State        |
|------------------------------------------------------------------------------|--------------------|
| unused:25 | identity_hashcode:31 | unused:1 | age:4 | biased_lock:1 | lock:2 |       Normal       |
|------------------------------------------------------------------------------|--------------------|
| thread:54 |       epoch:2        | unused:1 | age:4 | biased_lock:1 | lock:2 |       Biased       |
|------------------------------------------------------------------------------|--------------------|
|                       ptr_to_lock_record:62                         | lock:2 | Lightweight Locked |
|------------------------------------------------------------------------------|--------------------|
|                     ptr_to_heavyweight_monitor:62                   | lock:2 | Heavyweight Locked |
|------------------------------------------------------------------------------|--------------------|
|                                                                     | lock:2 |    Marked for GC   |
|------------------------------------------------------------------------------|--------------------|
```

> 共 12byte = 96bit

 ### 3) 对象锁

| biased_lock | lock |   状态   |
| :---------: | :--: | :------: |
|      0      |  01  |   无锁   |
|      1      |  01  |  偏向锁  |
|      0      |  00  | 轻量级锁 |
|      0      |  10  | 重量级锁 |
|      0      |  11  |  GC标记  |

### 4）HashCode

只有调用了对象的hashCode()方法，对象头中才会有hashCode的值

```
511d50c0
# WARNING: Unable to attach Serviceability Agent. You can try again with escalated privileges. Two options: a) use -Djol.tryWithSudo=true to try with sudo; b) echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
top.aoae.L object internals:
 OFFSET  SIZE   TYPE DESCRIPTION       VALUE
      0     4        (object header)   01 c0 50 1d (00000001 11000000 01010000 00011101) (491831297)
      4     4        (object header)   51 00 00 00 (01010001 00000000 00000000 00000000) (81)
      8     4        (object header)   43 c1 00 f8 (01000011 11000001 00000000 11111000) (-134168253)
     12     4        (loss due to the next object alignment)
Instance size: 16 bytes
Space losses: 0 bytes internal + 4 bytes external = 4 bytes total
```

输出hashCode的值为`511d50c0`, `51 + 1d + 50 + c0`这4个值加起来就是HashCode的值，HashCode的值是从第5个byte开始，倒序计算的。

