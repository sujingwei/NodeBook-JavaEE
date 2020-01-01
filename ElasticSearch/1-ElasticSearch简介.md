# 一、简介

​	Elasticsearch，简称es，是一个开源的高扩展的分布式全文检索引擎，它可以近乎实时的存储、检索数据；扩展性能好，可以扩展到上百台服务器，处理PB级别的数据。通过简单的RestFul API来隐藏Lucene的复制性，从而让全文搜索变得简单。

# 二、安装与启动

## 3、安装elasticsearch 中文分词（elasticsearch-analysis-ik）插件

> [https://github.com/medcl/elasticsearch-analysis-ik/releases](https://github.com/medcl/elasticsearch-analysis-ik/releases) 下载<u>对应</u>版本

解压后旋转在 `es/plugins/ik/`目录下，重启es。测试安装是否成功：

> POST /_analyze
>
> {
> 	"analyzer": "ik_smart",
> 	"text": "中国驻洛杉矶领事馆遭亚裔男子枪击 嫌犯已自首"
> }

结果：

```json
{
    "tokens": [
        {
            "token": "中国",
            "start_offset": 0,
            "end_offset": 2,
            "type": "CN_WORD",
            "position": 0
        },
        {
            "token": "驻",
            "start_offset": 2,
            "end_offset": 3,
            "type": "CN_CHAR",
            "position": 1
        },
        {
            "token": "洛杉矶",
            "start_offset": 3,
            "end_offset": 6,
            "type": "CN_WORD",
            "position": 2
        },
        {
            "token": "领事馆",
            "start_offset": 6,
            "end_offset": 9,
            "type": "CN_WORD",
            "position": 3
        },
        {
            "token": "遭",
            "start_offset": 9,
            "end_offset": 10,
            "type": "CN_CHAR",
            "position": 4
        },
        {
            "token": "亚裔",
            "start_offset": 10,
            "end_offset": 12,
            "type": "CN_WORD",
            "position": 5
        },
        {
            "token": "男子",
            "start_offset": 12,
            "end_offset": 14,
            "type": "CN_WORD",
            "position": 6
        },
        {
            "token": "枪击",
            "start_offset": 14,
            "end_offset": 16,
            "type": "CN_WORD",
            "position": 7
        },
        {
            "token": "嫌犯",
            "start_offset": 17,
            "end_offset": 19,
            "type": "CN_WORD",
            "position": 8
        },
        {
            "token": "已",
            "start_offset": 19,
            "end_offset": 20,
            "type": "CN_CHAR",
            "position": 9
        },
        {
            "token": "自首",
            "start_offset": 20,
            "end_offset": 22,
            "type": "CN_WORD",
            "position": 10
        }
    ]
}
```

# 三、ElasticSearch相关概念（术语）

## 1、概述

Elasticsearch是面向文档(document oriented)的，这意味着它可以存储事个对象或文档(document)。然而它不仅仅是存储，还会索引(index)每个文档的内容，使之可以被搜索。在ElasticSearch中，你可以对文档的(而非成行成列的数据)进行索引、搜索、排序、过滤。Elasticsearch比传统关系型数据库如下：

```
Relational DB -> DataBases -> Tables -> Rows -> Colums
Elasticsearch -> Indexs -> Types -> Documents -> Fields
```

## 2、核心概念

### 1）索引 Index

一个索引就是一个拥有几分相似特征的文档集合。比如说，你可以有一个客户数据索引，另一个产品目录的索引，还有一个订单数据索引。<u>一个索引由一个名字来标识</u>（必须全部都是小写字母），<u>并且当我们要对对应于这个索引中的文档进行索引、搜索、更新和删除的时候，都需要使用这个名字</u>。在一个集群中，可以定义任意多的索引。

### 2）类型 Type

> es 7.x 开始，Type会被丢去

在一个索引中，你可以定义一种或多种类型。<u>一个类型是你的索引的一个逻辑上的分类/分区，其语义完全由你来定。通常，会为具有一组共同字段的文档定义一个类型</u>。比如说，我们假设你运营一个博客平台并且将你所有的数据存储到一个索引中。在这个索引中，你可以为用户数据定义一个类型，为博客数据定义另一个类型，当然，也可以为评论数据定义另一个类型。

### 3）文档 Document

一个文档是一个可被索引的基础信息单元。比如，<u>你可以拥有某一个客户的文档</u>，当然也可以<u>拥有某个订单的一个文档</u>。文档以JSON格式来表示，而JSON是一个到处存在的互联网数据交互格式。

### 4）字段 Field

相当于数据表的字段，对文档数据根据不同的属性进行分类标识。

### 5）映射 Mapping

mapping是处理数据的方式和规则方面做一些限制，如某个字段的数据类型、默认值、分析器、是否被索引等等，这些都是映射里面可以设置的，其它就是es里面数据的一些使用规则设置也叫映射，按着最优规则处理数据对性能提高很大，因此才需要建立映射，并且需要思考如何映射才能对性能更好。

### 6）接近实时 NRT

Elasticsearch是一个接近实时的搜索平台。这意味着，从索引一个文档直到这个文档被搜索到有一个轻微的延迟(通常是1秒内)

### 7）集群 Cluster

一个集群就是由一个或多个节点组织在一起，它们共同持有整个数据，并一起提供索引和搜索功能。<u>一个集群由一个唯一的名字标识</u>，这个名字默认就是"**elasticsearch**"。这个名字是重要的，<u>因为一个节点只能通过指定某个集群的名字来加入这个集群</u>。

### 8）节点 Node

<u>一个节点是群集中的一个服务器，作为集群的一部分，它存储数据，参与集群索引和搜索功能</u>。和集群类似，一个节点也是由一个名字来标识的，默认情况下，这个名字是一个随机的漫威角色的名字，这个名字会在启动的时候赋予节点。这个名字对于管理工作来说很重要，因为在这个管理过程中，你会去确定网络中的哪些服务器对应于Elasticsearch集群中的哪些节点。

<u>一个节点可以通过配置集群名称的方式来加入一个指定的集群</u>。默认情况下，每个节点都会被安排加入一个叫**"elastersearch"**的集群中，这意味着，如果你在网络中启动了若干个节点，并假定它们能够相互发现彼此；它们将会自动地形成并加入到一个叫**“elasticsearch”**的集群中。

<u>在一个集群里，只要你想，可以拥有任意多个节点</u>。而且；如果当前你的网络中没有运行任何Elasticsearch节点，这时启动一个节点，会默认创建并加入一个叫“elasticsearch”的集群。

### 9）分片和复制 Shards & Replicas

一个索引可以存储超出单个结点硬件限制的大量数据。比如，一个具有10亿文档的索引占据1TB的磁盘空间，而任一节点都没有这样大的磁盘空间；或者单个节点的处理搜索请求，响应太慢。为了解决这个问题，<u>Elasticsearch提供了将索引划分成多分的能力，这些份就是分片</u>。当你创建一个索引的时候，你可以指定你想要的分片数量每个分片本身也是一个功能完善并且独立的“索引”，这个“索引”可以被转到集群中的任何节点上。分片很重要，主要有两方面的原因：

- 1  允许你水平分割/扩展你的内容容量

+ 2  允许你在分片之上进行分布工的、并行的操作，进而提高性能/吞吐量

至于一个分片怎样分布，它的文档怎样聚合回搜索请求，是完全由Elasticsearch管理的，对于作为用户的你来说，这些都是透明的。

在一个网络/云的环境里，失败随时会发生，在某个分片/节点不知怎么就处理离线状态，或者由于任何原因消失了，这种情况下，有一个故障转移机制是非常有用并且是强烈推荐的。为此目的，<u>Elasticsearch允许你创建分片的一份或多份拷贝，这些拷贝叫做复制分片</u>，或者直接叫复制。

复制之所以重要，有两个主要原因：<u>在分片/节点失败的情况下，提供了高可用性</u>。因为这个原因，<u>复制分片从不与原/主要(original/primary)分片置于同一节点上是非常重要的</u>。<u>扩展你的搜索量/吞吐量，因为搜索可以在所有复制上并行运行</u>。总之，每个索引就有了主分片(作为复制源的分片)和复制分片(主分片拷贝)之别。分片和复制分片数量可以在索引创建的时候指定。在索引创建之后，<u>你可以在任何时候动态地改变复制的数量，但是你事后不能改变分片的数量</u>。

默认情况下，Elasticsearch中每个索引被分片5个主分片和1个复制分片，这意味着，如果你的集群中至少有两个节点，你的索引将会有5个主分片和另外5个复制分片(1个完全拷贝)，这样的话每个索引总共就有10个分片。

# 四、Elasticsearch的客户端操作

## 1、创建索引

### 1）创建基本索引

> **PUT** http://127.0.0.1:9200/blog

```json
// 基本索引信息
{
    "blog":{
        "aliases":{},
        "mappings":{},
        "settings":{
            "index": {
                "creation_date":"1577858754935",
                "number_of_shards":"1",
                "number_of_replicas":"1",
                "uuid":"ZkIDY4VDRDiiml-B0GGDXA",
                "version":{"created":"7030299"},
                "provided_name":"blog"
            }
        }
    }
}
```

### 2）创建索引时设置mapping信息

> **PUT** http://127.0.0.1:9200/blog1
>
> es 6.x 以前操作，请求体，如下：{
> 	"mappings": {
> 		"article": { // article相关于Type(表名)的名称。es7中，不再使用
> 			"properties": {    // 表属性
> 				"id": {
> 					"type": "long",
> 					"store": true,
> 					"index": "not_analyzed"  // 不索引，默认，可不设置
> 				}, 
> 				"title": {
> 					"type": "text",
> 					"store": true,
> 					"index": "analyzed",   // 索引，非默认
> 					"analyzed": "standard" // 标准分词器
> 				}, 
> 				"content": {
> 					"type": "text",
> 					"store": true,
> 					"index": "analyzed",
> 					"analyzed": "standard"
> 				}
> 			}
> 		}
> 	}
> }
>
> 
>
> es 7.x 以后版本的操作
>
> {
> 	"mappings": {
>
> ​		//  不再有 article (Type) 了
>
> ​		"properties": {
> ​			"id": {
> ​				"type": "long",
> ​				"store": true,
> ​				"index": false
> ​			}, 
> ​			"title": {
> ​				"type": "text",
> ​				"store": true,
> ​				"index": true,
> ​				"analyzer": "ik_max_word"
> ​			}, 
> ​			"content": {
> ​				"type": "text",
> ​				"store": true,
> ​				"index": true,
> ​				"analyzer": "ik_max_word"
> ​			}
> ​		}
> ​	}
> }

生成索引结果：

```json
{"blog1":
 {
     "aliases":{},
     "mappings":{
         "properties":{
             "content":{
                 "type":"text",
                 "store":true,
                 "analyzer":"ik_max_word"
             },"id":{
                 "type":"long",
                 "index":false,
                 "store":true
             },"title":{
                 "type":"text",
                 "store":true,
                 "analyzer":"ik_max_word"
             }
         }
     },
     "settings":{
         "index":{
             "creation_date":"1577862320645",
             "number_of_shards":"1",
             "number_of_replicas":"1",
             "uuid":"HpqGRc-gQn6DAbZamdul3g",
             "version":{"created":"7030299"},
             "provided_name":
             "blog1"
         }
     }
 }
}
```

### 3）给创建后的索引设置mapping信息

> **POST** /blog/_mapping
>
> {
> 	"properties": {
> 		"id": {
> 			"type": "long",
> 			"store": true,
> 			"index": false
> 		}, 
> 		"title": {
> 			"type": "text",
> 			"store": true,
> 			"index": true,
> 			"analyzer": "ik_max_word"
> 		}, 
> 		"content": {
> 			"type": "text",
> 			"store": true,
> 			"index": true,
> 			"analyzer": "ik_max_word"
> 		}
> 	}
> }
>
>  
>
> 查询映射关系(Mapping)
>
> **GET** /blog/_mapping

查询映射关系结果：

```json
{
    "blog":{
        "mappings":{
            "properties":{
                "content":{
                    "type":"text",
                    "store":true,
                    "analyzer":"ik_max_word"
                },
                "id":{"
                      type":"long",
                      "index":false,
                      "store":true
                     },
                "title":{
                    "type":"text",
                    "store":true,
                    "analyzer":"ik_max_word"
                }
            }
        }
    }
}
```

## 2、删除索引

> **DELETE** /blog2

## 3、创建文档

> **POST** /blog1/_doc/1
>
> {
> 	"id":1,
> 	"title":"新添加的文档1",
> 	"content":"新添加的文档的内容"
> }

生成结果：

| _index | _type | _id  | _score |  id  | title         | content            |
| :----: | :---: | :--: | :----: | :--: | ------------- | ------------------ |
| blog1  | _doc  |  1   |   1    |  1   | 新添加的文档1 | 新添加的文档的内容 |

**注意：在es6.x版本中，_doc 应该是类型(Type)的名称**

## 4、删除文档

> **DELETE** /blog1/_doc/1

## 5、编辑文档

> **POST** /blog1/_doc/1
>
> {
> 	"id":1,
> 	"title":"修改后的文档1",
> 	"content":"修改后的文档的内容"
> }

## 6、查询

### 1）根据id查询文档

> **GET** /blog1/_doc/1

查询结果：