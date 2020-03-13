# 一、RabbitMQ的消息确认机制

问题：生产者将消息发送出去之后，消息到底有没有到达 rabbitmq服务器，默认情况是不知道的。

## 1、AMQP事务机制

缺点：大量的消息添加和回滚，会降低吞吐量

* txSelect 用于将当前 channel 设置成 transaction (事务) 模式
* txCommit 用于提交事务
* txRollback 用于回滚事务

### （1）生产者

```java
public class TxSend {
    private static final String QUEUE_NAME = "test_queue_tx";
    public static void main(String[] args) throws IOException, TimeoutException {
        Connection connection = ConnectionRabbitMQUtils.getConnection();
        Channel channel = connection.createChannel();
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        String msg = "hello tx message";
        try {
            channel.txSelect();  // 开启事务模式
            channel.basicPublish("", QUEUE_NAME, null, msg.getBytes());
            int a = 1 / 0;
            System.out.println("send: " + msg);
            channel.txCommit();
        } catch (Exception e){
            channel.txRollback();
            System.out.println("发送异常，回滚");
        }

        channel.close();
        connection.close();
    }
}
```

### （3）消费者

```java
public class TxRecv {
    private static final String QUEUE_NAME = "test_queue_tx";
    public static void main(String[] args) throws IOException, TimeoutException {
        Connection connection = ConnectionRabbitMQUtils.getConnection();
        Channel channel = connection.createChannel();
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        channel.basicConsume(QUEUE_NAME, true, new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException {
                super.handleDelivery(consumerTag, envelope, properties, body);
                System.out.println(new String(body, "utf-8"));
            }
        });
    }
}
```

## 2、Confirm模式

> 生产者将信道设置成confirm模式，一旦信道进入confirm模式，所有在该信道上面发布的消息都会指派一个唯一的ID(从1开始)，一旦消息被投递到所有匹配的队列后，broker就会发送一个确认给生产者（包含消息唯一ID），这就使得生产者知道消息已经正确到达目的队列了，如果消息和队列是可持久的，那么确认消息会将消息写入磁盘之后发出，broker回传给生产者的三角窗消息中deliver-tag域包含确认消息的序列号，此外broker也可以设置basic.ack的multiple域，表示到这个序列号之前的所有消息都已已经得到处理。

- Confirm模式，最大的好处是异步的

**开启Confirm模式：**

```java
channel.confimSelect();  //
编程模式：
    1、普通 waitForConfims(), 每发一条，调用一下这个方法
    2、批量 waitForConfims()，每发一批，调用一下这个方法
    3、异步confirm模式，提供一个回调方法
```

### 1）串行确认

**生产者 1，发送单条消息**

```java
public class Send1 {
    private static final String QUEUE_NAME = "test_queue_confirm_1"; // 必需是个新队列
    public static void main(String[] args) throws IOException, TimeoutException, InterruptedException {
        Connection connection = ConnectionRabbitMQUtils.getConnection();
        Channel channel = connection.createChannel();
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        // todo 生产者调用confirmSelect，开启confirm模式
        channel.confirmSelect();
        channel.basicPublish("", QUEUE_NAME, null, "hello confirm message".getBytes());

        if(!channel.waitForConfirms()){
            System.out.println("发送失败");
        }else{
            System.out.println("发送成功");
        }
        channel.close();
        connection.close();
    }
}
```

**生产者 2，批量发消息**

```java
public class Send2 {
    private static final String QUEUE_NAME = "test_queue_confirm_1"; // 必需是个新队列

    public static void main(String[] args) throws IOException, TimeoutException, InterruptedException {
        Connection connection = ConnectionRabbitMQUtils.getConnection();
        Channel channel = connection.createChannel();
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        // todo 生产者调用confirmSelect，开启confirm模式
        channel.confirmSelect();

        for (int i = 0; i < 10; i++)
            // 哈哈，这就是批量了
            channel.basicPublish("", QUEUE_NAME, null, "hello confirm message".getBytes());

        if (!channel.waitForConfirms()) {
            System.out.println("发送失败");
        } else {
            System.out.println("发送成功");
        }

        channel.close();
        connection.close();
    }
}
```

### 2）异步确认

Channel对象提供的`confirmListener()`回调方法只包含`deliveryTag`(当前Chanel发出的消息序号)，我们需要自己为第一个Channel维护一个 `unconfirm` 的消息序号集合，每回调一次`handleAck`方法，`unconfirm`集合删掉相应一条(multiple=false)或多条(multiple=true)记录，从程序运行羊效率上看，这个`unconfirm`集合采用`SortedSet`存储结构。

**生产者：**

```java
public class Send3 {
    private static final String QUEUE_NAME = "test_queue_confirm_1"; // 必需是个新队列

    public static void main(String[] args) throws IOException, TimeoutException, InterruptedException {
        Connection connection = ConnectionRabbitMQUtils.getConnection();
        Channel channel = connection.createChannel();
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        // todo 生产者调用confirmSelect，开启confirm模式
        channel.confirmSelect();

        //   发送失败的消息的id会保存在这个集合中
        SortedSet<Long> confirmSet = Collections.synchronizedSortedSet(new TreeSet<Long>());

        channel.addConfirmListener(new ConfirmListener() {
            // 没有问题的handleAck
            @Override
            public void handleAck(long deliverTag, boolean b) throws IOException {
                if (b) {
                    System.out.println("多条发送成功");
                    confirmSet.headSet(deliverTag + 1).clear(); // 清空集合
                }else {
                    System.out.println("单条发送成功");
                    confirmSet.remove(deliverTag); // 删除集合中id
                }
            }

            // 发送失败的
            @Override
            public void handleNack(long deliverTag, boolean b) throws IOException {
                if (b) {
                    System.out.println("多条发送失败");
                    confirmSet.headSet(deliverTag + 1).clear(); // 清空集合
                }else {
                    System.out.println("单条发送失败");
                    confirmSet.remove(deliverTag); // 删除集合中id
                }
            }
        });


        while (true){
            long seqNo = channel.getNextPublishSeqNo();
            channel.basicPublish("", QUEUE_NAME, null, "sss".getBytes());
            confirmSet.add(seqNo);
        }
    }
}
```

