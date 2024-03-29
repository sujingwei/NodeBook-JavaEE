kafka的消息通过主题进行分类。主题就好比数据库的表，或者文件系统里的文件夹。主题可以被分为若干个分区，一个分区就是一个提交日志。消息以追回的方式写入分区，然后以先入先出的顺序读取。要注意，一个主题一般包含几个分区，因此无法在事个主题范围内保证消息的顺序，但可以保证消息在单个分区内的顺序。图1-5所示的主题有4个分区，消息被追加写入每个分区的尾部。kafka通过分区来实现数据冗余和伸缩性。分区可以分布在不同的服务器上，也就是说，一个主题可以横跨多个服务器，以此来提供比单个服务器更强大的性能。

消息者订阅1个或多个主题，并按照消息生成的顺序读取它们。消费者通过检查消息的偏移量来区分已经读取过的消息。偏移量是另一种元数据

一个独立的Kafka服务器称为Broker。broker接收来自生产者的消息，为消息设置偏移量，并提交消息到磁盘保存。broker为消息者提供服务，对读取分区的请求作响应，返回已提交到磁盘上的消息

broker是集群的组成部分。每个集群都有一个brroker同时充当了集群控制器角色。控制器负责管理工作，包括将分区分配给broker和监控broker。在集群中，一**个分区从属于一个broker**,该borker被称为分区首领。一个分区可以分配给多个broker，这个时候会发生分区复制，这种复制机制为分区提供消息冗余，如果有一个broker失效，其他broker可以接管领导权。



主题可以配置自己的保留策略，可以将消息保留到不再使用它们为止。例如，用于跟踪用户活动的数据可能需要保留几天，应用程序的度量指标可能只需2保留几小时。可以通过配置把主题当作紧凑型日志，只有最后一个带有特定键的消息会被保留下来。这种情况对于变更日志类型的数据来说比较适用，因为人们只关心最后时刻发生的那个变更。

随着，kafka部署数量的增加，基于以下几点原因，最好使用多个集群

1. 数据类型分离
2. 安全需求隔离
3. 多数据中心（灾难恢复）

如果使用多个数据中心，就需要在它们之们复制消息。这样，在线应用程序才可以访问到多个站点的用户活动信息。如果一个用户修改了他们的资料信息，不管从哪个数据中心都应该能看到这些改动。

或者多个站点的监控数据可以被聚集到1个部署分析程序和告警系统中心位置。不过kafka的消息复制机制只能在单个集群里进行，不能在多个集群间进行

kafka提供1个叫MirroMaker的工具，可以用它来实现集群间的消息复制。 MirrorMaker的核心组件包含一个生产者和一个消费者，两者之间通过一个队列相连

消费都从一个集群读取消息，生产者把消息发到另一个集群上。

消费者可以在进行应用程序维护时离线1小时，而无需担心消息丢失或

一个包含多个broker的集群，即使个别失效，依然可以持续地为客户提供服务

