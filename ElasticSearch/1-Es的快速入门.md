# ElastisSearch的快速入门

本文使用 ElasticSearch7.2.0版本

## 一、ElasticSearch核心概念
|关键字|描述|
|---|---|
|索引(index)|一个索引可以理解成一个关系型数据库存|
|类型(type)|一种type就像一个表，比如user表,order表，Es7.x以后已经移除type这个概念|
|映射(mapping)|mapping定义每个字段的类型等信息。相当于关系型数据库的表结构|
|文档(document)|一个document相当于关系型数据库的一行记录|
|字段|相当于关系型数据库的一个字段|
|集群|集群由一个或多个节点组成，一个集群有一个默认名称"elasticsearch"|
|节点|集群的节点，一台机器或者一个进程|
|分片和副本|副本是分片的副本，分片有主分片和副分片<br>一个Index数据在物理上被分布在多个分片中，每个分片只存放部分数据。<br>每个分片可以有多个副本，叫副本分片，是主分片的复制|

## 二、基本的CRUD

**获取elasticsearch状态**

> GET /

```json
{
  "name": "DESKTOP-488QE2I",
  "cluster_name": "elasticsearch",
  "cluster_uuid": "81jIsrkYR6qEC1d3Cgc2IA",
  "version": {
    "number": "7.2.0",
    "build_flavor": "default",
    "build_type": "zip",
    "build_hash": "508c38a",
    "build_date": "2019-06-20T15:54:18.811730Z",
    "build_snapshot": false,
    "lucene_version": "8.0.0",
    "minimum_wire_compatibility_version": "6.8.0",
    "minimum_index_compatibility_version": "6.0.0-beta1"
  },
  "tagline": "You Know, for Search"
}
```

**新增一个文档**

> POST /xdclass/_doc/1

```json
{
	"user": "iouis",
	"message": "louis is good"
}
```

**删除一个文档**

> DELETE  /xdclass/_doc/1

## 三、索引的介绍和使用

### 1、创建索引

**请求：**

```
// 创建一个名叫nba的索引
PUT /nba
```

**响应：**

```json
{
    "acknowledged": true,
    "shards_acknowledged": true,
    "index": "nba"
}
```

### 2、获取创建的索引

**请求：**

```
GET /nba
```

**响应：**

```json
{
    "nba": {
        "aliases": {},   // 别名
        "mappings": {},  // 表结构
        "settings": {    // 索引的设置
            "index": {
                "creation_date": "1581243115915",
                "number_of_shards": "1",    // 分片数
                "number_of_replicas": "1",  // 副本数
                "uuid": "T5kjQRhCRSqqKYGS121Pyw",
                "version": {
                    "created": "7020099"
                },
                "provided_name": "nba"
            }
        }
    }
}
```

### 3、删除索引

**请求：**

```
DELETE /nba
```

**响应：**

```
{
    "acknowledged": true
}
```

### 4、获取多个索引

**请求：**

```
GET /cba,nba
```

**响应：**

```json
{
    "cba": {
        "aliases": {},
        "mappings": {},
        "settings": {
            "index": {
                "creation_date": "1581243393338",
                "number_of_shards": "1",
                "number_of_replicas": "1",
                "uuid": "xObwBg8IQV-8C0uuPpboSA",
                "version": {
                    "created": "7020099"
                },
                "provided_name": "cba"
            }
        }
    },
    "nba": {
        "aliases": {},
        "mappings": {},
        "settings": {
            "index": {
                "creation_date": "1581243388060",
                "number_of_shards": "1",
                "number_of_replicas": "1",
                "uuid": "JBjFa58bSayc1qYj2UJ5Bg",
                "version": {
                    "created": "7020099"
                },
                "provided_name": "nba"
            }
        }
    }
}
```

### 5、获取所有索引

**请求：**

```
GET /_all
```

**响应：**

```json
{
    "cba": {
        "aliases": {},
        "mappings": {},
        "settings": {
            "index": {
                "creation_date": "1581243393338",
                "number_of_shards": "1",
                "number_of_replicas": "1",
                "uuid": "xObwBg8IQV-8C0uuPpboSA",
                "version": {
                    "created": "7020099"
                },
                "provided_name": "cba"
            }
        }
    },
    "nba": {
        "aliases": {},
        "mappings": {},
        "settings": {
            "index": {
                "creation_date": "1581243388060",
                "number_of_shards": "1",
                "number_of_replicas": "1",
                "uuid": "JBjFa58bSayc1qYj2UJ5Bg",
                "version": {
                    "created": "7020099"
                },
                "provided_name": "nba"
            }
        }
    }
}
```

### 6、判断索引是否存在

**请求：**

```
HEAD /nba
```

**响应：**

```
STATUS 200
```

### 7、关闭索引

**请求：**

```
POST /nba/_close
```

**响应：**

```json
{
    "acknowledged": true,
    "shards_acknowledged": true
}
```

**再查看：**

```json
{
    "nba": {
        "aliases": {},
        "mappings": {},
        "settings": {
            "index": {
                "verified_before_close": "true",  // 代表已关闭这个索引
                "number_of_shards": "1",
                "provided_name": "nba",
                "creation_date": "1581243388060",
                "number_of_replicas": "1",
                "uuid": "JBjFa58bSayc1qYj2UJ5Bg",
                "version": {
                    "created": "7020099"
                }
            }
        }
    }
}
```

### 8、开启索引

**请求：**

```json
POST /nba/_open
```

**响应：**

```json
{
    "acknowledged": true,
    "shards_acknowledged": true
}
```

## 四、映射的介绍

之前定义的 nba是没有指定mapping，现在指定。

**type字段说明**

| KEY     | VALUE      |
| ------- | ---------- |
| keyword | 不支持分词 |
| text    | 支持分词   |

- ElasticSearch的字段在指定类型后，就不能再修改

### 1、新增

**请求：**

```
PUT /nba/_mapping
```

**请求数据：**

```json
{
	"properties": {
        "name": {
            "type": "text"
        },
        "team_name": {
            "type": "text"
        },
        "position": {
            "type": "keyword"
        },
        "play_year": {
            "type": "keyword"
        },
        "jerse_no": {
            "type": "keyword"
        }
    }	
}
```

**响应：**

```json
{
    "acknowledged": true
}
```

**返回mapping的方式:**

```
GET /nba/_mapping  # 返回nba的mapping
GET /nba,cba/_mapping # 返回nba和cba的mapping
GET /_all/_mapping  # 返回所有mapping
GET /_mapping  # 同上
```

### 2、编辑mapping

**请求：**

```
POST /nba/_mapping
```

**请求数据：**

```js
{
	"properties": {
        "name": {
            "type": "text"
        },
        "team_name": {
            "type": "text"
        },
        "position": {
            "type": "keyword"
        },
        "play_year": {
            "type": "keyword"
        },
        "jerse_no": {
            "type": "keyword"
        },
        "contry": {  // 这是新添加的
        	"type": "keyword"
        }
    }	
}
```

**响应：**

```
{
    "acknowledged": true
}
```

## 五、文档的CRUD操作

ElasticSearch7.2之后取消了 type，改为 _doc

### １、新建文档

```js
# PUT /nba/_doc/1[?op_type=create]
// 1 表示文档的ID，如果不指定,Es会创建一个字符串作为文档ID
// 带上 ?op_type=create参数，如果已经包含"/nba/_doc/1"文档，则创建失败，原来是我们发的是PUT请求也会修改原文档
{
	"name":"库里",
	"team_name":"勇士",
	"position":"组织后卫",
	"play_year":"10",
	"jerse_no":"30"
}
```

### 2、查看文档

```js
# GET /nba/_doc/1
```

### 3、查看多份文档

```js
# POST /_mget
// 如果请求的url指定了索引，那么是不需要指定 "_index" 参数
// 同上，如果指定了 "_doc"，那也不用指定 "_type" 参数，如 POST /nba/_doc/_mget
{
	"docs": [
		{
			"_index":"nba",
			"_type":"_doc",
			"_id":"1"
		},{
			"_index":"nba",
			"_type":"_doc",
			"_id":"2"
		}
	]
}

//也可用使用以下简单的方法：
# POST /nba/_doc/_mget
{
    "ids": ["1", "2"]
}
```

### 4、修改文档

```js
# POST /nba/_update/1

{
	"doc": {
		"name": "大胡子",
		"team_name": "火剪",
		"position": "得分后卫",
		"play_year": "10",
		"jerse_no": "13"
	}
}
```

对单个文档进行编辑

#### （1）添加一个字段

```js
# POST /nba/_update/1
{
	"script": "ctx._source.age = 18" 
}
```

#### （2）删除一个字段 

```js
# POST /nba/_update/1
{
	"script": "ctx._source.remove(\"age\")" 
}
```

#### （3）更新指定文档的字段 

```js
# POST /nba/_update/1

{
	"script": {
        // += params.age的值
		"source": "ctx._source.age += params.age", 
		"params": {
			"age":4
		}
	},
	"upsert": { // 如果值不存在，就先加入这个字段
		"age": 1
	}
}
```

### 5、删除文档

```js
# DELETE /nba/_doc/1
```

## 六、简单的查询

### 1、term(词条)查询

> 词条查询：不会分析查询条件，只有当词条查询字符串完全匹配时，才会匹配搜索。

```js
# POST http://127.0.0.1:9200/nba/_search

{
	"query":{
		"term": {  // term表示精确查询
			"jerse_no":"23"
		}
	}
}

{
	"query":{
		"terms": {  // 查询多条
			"jerse_no":["13","23"]
		}
	}
}
```

### 2、full text(全文)查询

> 全文查询：ElasticSearch引擎先分析查询字符串，将其拆分成多个分词，只要分析的字段中包含词条的任意一个，或全部包含，就匹配查询条件，返回该文档；如果不不包含任意一个分词，表示没有任何文档匹配查询配件。

#### 1）match_all查看全部

```js
# POST /nba/_search
{
	"query":{
		"match_all": {}
	}
}
```

#### 2）match_all分页查询

```js
{
	"query":{
		"match_all": {}
	},
	"from":0,  // 跳过第几条
	"size":100 // 显示多少条
}

{
	"query":{
		"match": {  // 带上查询条件的，mapping的指定的字段类型必须是text才可以
			"name":"库里"  //会对它进行分词查询
		}
	},
	"from":0,
	"size":100
}
```

#### 3) match_phrase 准确查询，类似词条查询

```js
# POST /nba/_search
{
	"query": {
		"match_phrase": {
			"position": "得分后卫"
		}
	}
}
```

#### 4）match_phrase_prefix，前缀查询

```js
# POST /nba/_search
{
	"query": {
		"match_phrase_prefix": {
			"title": "the b"    // 前缀
		}
	}
}
```

## 七、分词器的介绍和使用

常用的内置分词器

* standard analyzer 默认分词器
* simple analyzer
* whitespace analyzer
* stop analyzer
* language analyzer
* pattern analyzer

### 1、standard

```json
# POST /_analyze
{
	"analyzer": "standard",
	"text": "The best 3-points shooter is Curry!"
}

// 结果如下：
{
    "tokens": [
        {
            "token": "the",       // 词
            "start_offset": 0,    // 开始位置
            "end_offset": 3,      // 结束位置
            "type": "<ALPHANUM>", // 英文单词
            "position": 0         // 第几个
        },
        {
            "token": "best",
            "start_offset": 4,
            "end_offset": 8,
            "type": "<ALPHANUM>",
            "position": 1
        },
        {
            "token": "3",
            "start_offset": 9,
            "end_offset": 10,
            "type": "<NUM>",
            "position": 2
        },
        {
            "token": "points",
            "start_offset": 11,
            "end_offset": 17,
            "type": "<ALPHANUM>",
            "position": 3
        },
        {
            "token": "shooter",
            "start_offset": 18,
            "end_offset": 25,
            "type": "<ALPHANUM>",
            "position": 4
        },
        {
            "token": "is",
            "start_offset": 26,
            "end_offset": 28,
            "type": "<ALPHANUM>",
            "position": 5
        },
        {
            "token": "curry",
            "start_offset": 29,
            "end_offset": 34,
            "type": "<ALPHANUM>",
            "position": 6
        }
    ]
}
```

### 2、simple analyzer

simple分析器当它遇到只要不是字母的字符，就将文本解析成term，而且所有term都是小写的。

```js
# POST /_analyze
{
	"analyzer": "simple",
	"text": "The best 3-points shooter is Curry!"
}
```

### 3、whitespace analyzer

只是使用空格来分词

```js
# POST /_analyze
{
	"analyzer": "whitespace",
	"text": "The best 3-points shooter is Curry!"
}
```

### 4、stop analyzer

stop分词器和simple分词器很像，唯一不同的是，stop分词器增加了对删除停止词的支持，默认使用了english停止词

预备停止词列表，比如(the,a,an,this,of,at)等等。分词结果不包含停止词列表里的词。

```js
# POST /_analyze
{
	"analyzer": "stop",
	"text": "The best 3-points shooter is Curry!"
}
```

### 5、language analyzer

```js
# POST /_analyze
{
	"analyzer": "english", // 使用英语语法分词,可以换语言
	"text": "The best 3-points shooter is Curry!"
}
```

### 6、pattern analyzer

用正则表达式来将文本分割成terms，默认的正则表达式是\W+（非单词字符）

```js
# POST /_analyze
{
	"analyzer": "pattern", // 使用英语语法分词,可以换语言
	"text": "The best 3-points shooter is Curry!"
}
```

### 7、案例

创建一个新的索引

```json
# PUT /my_index
{
	"settings": {
		"analysis": {
			"analyzer": {
				"my_analyzer": {
					"type":"whitespace"
				}
			}
		}
	},
	"mappings": {
		"properties": {
			"name": {
				"type": "text"
			},"team_name": {
				"type": "text"
			},"position": {
				"type": "text"
			},"play_year": {
				"type": "long"
			},"jerse_no": {
				"type": "keyword"
			},"title": {
				"type": "text",
				"analyzer": "whitespace"
			}
		}
	}
}
```

插入数据

```js
# PUT /my_index/_doc/1
{
 "name": "库⾥",
 "team_name": "勇⼠",
 "position": "控球后卫",
 "play_year": 10,
 "jerse_no": "30",
 "title": "The best 3-points shooter is Curry!"
 }
```

搜索

```js
# POST /my_index/_search
{
	"query": {
		"match": {
			"title":"aaa Curry!" // 因为使用了whitespace词，所以需要加入"!"
		}
	}
}
```

## 八、常见中文分词器

常见分词器

* smartCN 一个简单的中文或英文混合文本的分词器
* IK分词器 ，更智能友发的中文分词器

### 1、smartCN 

#### (1)  安装

安全成功后要重启 ElasticSearch

```shell
elasticsearch-plugin install analysis-smartcn
```

#### (2) 使用

```js
# POST /_analyze
{
	"analyzer": "smartcn",
	"text": "火箭明年总冠军"
}
```

### 2、IK分词器

#### 1）安装

```js
# https://github.com/medcl/elasticsearch-analysis-ik/releases 下载地址
# 下载对应 es的版本
# 下载完后解压到 plugs目录中
# 重启 ElasticSearch
```

#### 2）使用

```js
# POST /_analyze
{
	"analyzer": "ik_max_word",
	"text": "火箭明年总冠军"
}
```

## 九、常见字段类型

常见的字段类型的介绍和使用

* 核心数据类型
* 复杂数据类型
* 专用数据类型

### 1、核心数据类型

* 字符串

  * **tex**t 用于全文索引，可以使用分词器进行分词
  * **keyword** 不分词，只能搜索字段的完整值

* 数值类型

  * **long, integer, short, byte, double, float, half_float, scaled_float**

* 布尔型-**boolean**

* 二进制-**binary**

  * 该类型的字段把值当做经过base64编码的字符串，默认不存储，且不可搜索

* 范围类型

  * 范围类型表示值昌一个范围，而不是一个具体的值
  * integer_range,float_range,long_range,double_range, date_range
  * 譬如age的类型是integer_range,那么可以是那么值可以是{"gte" : 20, "lte" : 40}；搜索 "term" : {"age": 21} 可以搜索该值

* 日期-date

  * 由于Json没有date类型，所以es通过识别字符串是否符合format定义的格式来判断是否

    为date类型 , format默认为：strict_date_optional_time||epoch_millis格式

  * "2022-01-01" "2022/01/01 12:10:30" 这种字符串格式

  * 从开始纪元（1970年1?1?0点）开始的毫秒数,从开始纪元开始的秒

案例

**删除nba索引后重新创建nab索引，mapping 如下：**

```json
{
	"properties": {
			"jerse_no": {
				"type":"keyword"
			},"name": {
				"type":"text"
			},"play_year": {
				"type":"long"
			},"position": {
				"type":"text"
			},"team_name": {
				"type":"text"
			},"age_range": {
				"type":"integer_range"
			}
	}
	
}
```

**插入数据**

```json
{
	"name":"哈登",
	"team_name":"火箭",
	"position":"得分后卫",
	"play_year": 10,
	"jerse_no": 13,
	"age_range": {
		"gte": 20,
		"lte": 40
	}
}
```

**查询**

```js
{
    "query":{
        "term":{
        	"age_range":21  // 查到范围在 20 - 40 间的数据
        }
    }
}
```

### 2、复杂数据类型

```js
{
	"name":"柯登",
	"team_name":"火箭",
	"position":"后卫",
	"play_year": 10,
	"jerse_no": 13,
	"array_test":[1,2]  // 数据，复杂的数据类型
}
```

### 3、专用数据类型

如IP类型,用于存储ipV4和ipV6

## 十、Kibana的安装及使用

解压，config/kibana.yml

```sh
server.port: 5601
server.host: "localhost"
server.name: "kibana"
elasticsearch.hosts: ["http://localhost:9200"]
xpack.reporting.encryptionKey: "abc123" # 随机字符串
```

