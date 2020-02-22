# 一、索引别名

索引别名主像一个快捷方式或是软连接，可以指向一个或多个索引，也可以给任意一个需要索引名的API来使用。别名的应用为程序提供了极大的灵活性。

## 1、查询别名

```js
GET /nba/_alias
GET /_alias
```

## 2、新增别名

```js
# 方法一
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "nba",
        "alias": "nba_v1.0"
      }
    }
  ]
}

# 方法二
PUT /nba/_alias/nba_v1.1
```

## 3、删除别名

```js
# 方法一
POST /_aliases
{
  "actions": [
    {
      "remove": {
        "index": "nba",
        "alias": "nba_v1.0"
      }
    }
  ]
}

# 方法二
DELETE /nba/_alias/nba_v1.1

```

## 4、重命名别名

```js
POST /_aliases
{
  "actions": [
    {
      "remove": {
        "index": "nba",
        "alias": "nba_v1.0"
      }
    },
    {
      "add": {
        "index":"nba",
        "alias": "nba_v2.0"
      }
    }
  ]
}
```

## 5、为多个索引指定同一个别名

> <h3>注意</h3>
>
> 对别名进行操作，会同步多个索引中

```js
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "nba",
        "alias": "national_player",
         "is_write_index": true // 指定只有nab这个索引能写文档
      }
    },
    {
      "add": {
        "index": "wnba",
        "alias": "national_player"
      }
    }
  ]
}
```

## 6、为同个索引指定多个别名

```js
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "nba",
        "alias": "nba_v2.1"
      }
    },
    {
      "add": {
        "index": "nba",
        "alias": "nba_v2.2"
      }
    }
  ]
}
```

# 二、重建索引

> Elasticsearch是⼀个实时的分布式搜索引擎，为⽤户提供搜索服务，当我们决定存储某种数据时，在创建索引的时候需要将数据结构完整确定下来，于此同时索引的设定和很多固定配置将⽤不能改变。当需要改变数据结构时，就需要重新建⽴索引，为此，Elastic团队提供了很多辅助⼯具帮助开发⼈员进⾏重建索引

## 第一步：nba取一个别名nba_latest，作为对外使用

```
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "nba",
        "alias": "nba_latest"
      }
    }
  ]
}
```

## 第二步：新增一个索引nab_20220222，结构复制于nba索引，根据业务要求修改字段

```js
PUT /nba_20220222
{
 "mappings": {
 "properties": {
 "age": {
 "type": "integer"
 },
 "birthDay": {
 "type": "date"
 },
 "birthDayStr": {
 "type": "keyword"
 },
 "code": {
 "type": "text"
 },
 "country": {
 "type": "keyword"
 },
 "countryEn": {
 "type": "keyword"
 },
 "displayAffiliation": {
 "type": "text"
 },
 "displayName": {
 "type": "text"
 },
 "displayNameEn": {
 "type": "text"
 },
 "draft": {
 "type": "long"
 },
 "heightValue": {
 "type": "float"
 },
 "jerseyNo": {
 "type": "keyword"
 },
 "playYear": {
 "type": "long"
 },
 "playerId": {
 "type": "keyword"
 },
 "position": {
 "type": "text"
 },
 "schoolType": {
 "type": "text"
 },
 "teamCity": {
 "type": "text"
 },
 "teamCityEn": {
 "type": "text"
 },
 "teamConference": {
 "type": "keyword"
 },
 "teamConferenceEn": {
 "type": "keyword"
 },
 "teamName": {
 "type": "keyword"
 },
 "teamNameEn": {
 "type": "keyword"
 },
 "weight": {
 "type": "text"
 }
 }
 }
}
```

## 第三步：将nba数据同步到nab_20220222

- Elastic Search 通过`reindex`来同步数据

> wait_for_completion=false 表示使用异步的方式来同步数据，页面不无需等待，数据量大的时候建议使用

```js
POST /_reindex?wait_for_completion=false
{
  "source": {
    "index": "nba"              // 旧索引
  },
  "dest": {
    "index": "nba_20220222"     // 新索引
  }
}
```

## 第四步：给nab_20220222添加别名nba_latest，删除nba别名nba_latest

```js
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "nba_20220222",
        "alias": "nba_latest"
      }
    }
  ]
}


POST /_aliases
{
  "actions": [
    {
      "remove": {
        "index": "nba",
        "alias": "nba_latest"
      }
    }
  ]
}
```

## 第五步：删除nba索引

```js
DELETE /nba
```

# 三、Es的refresh操作

> 新的数据一添加到索引中并不会立即被搜索到。有时候需要强制刷新（类似文件的写操作）。

在插入数据的时候带上`refresh` 参数

```js
PUT /star/_doc/666?refresh
{
	....
}
```

查看及修改refresh的时间

```js
# 首次先修改
PUT /star/_settings
{
  "index": {
    "refresh_interval": "5s" // 如这个这值为-1，就不会自动刷新
  }
}

# 查看
GET /star/_settings
```

# 四、搜索结果高亮显示

## 1、使用 "highlight"，就可以了

```
POST /nba_latest/_search
{
  "query": {
    "match": {
      "displayNameEn": "james"
    }
  },
  "highlight": {
    "fields": {
      "displayNameEn": {}
    }
  }
}
```

**结果：**

```js
{
  "took" : 7,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 5,
      "relation" : "eq"
    },
    "max_score" : 4.699642,
    "hits" : [
      {
        "_index" : "nba_20220222",
        "_type" : "_doc",
        "_id" : "214",
        "_score" : 4.699642,
        "_source" : {
          "countryEn" : "United States",
          "teamName" : "火箭",
          "birthDay" : 620107200000,
          "country" : "美国",
          "teamCityEn" : "Houston",
          "code" : "james_harden",
          "displayAffiliation" : "Arizona State/United States",
          "displayName" : "詹姆斯 哈登",
          "schoolType" : "College",
          "teamConference" : "西部",
          "teamConferenceEn" : "Western",
          "weight" : "99.8 公斤",
          "teamCity" : "休斯顿",
          "playYear" : 10,
          "jerseyNo" : "13",
          "teamNameEn" : "Rockets",
          "draft" : 2009,
          "displayNameEn" : "James Harden",
          "heightValue" : 1.96,
          "birthDayStr" : "1989-08-26",
          "position" : "后卫",
          "age" : 30,
          "playerId" : "201935"
        },
        "highlight" : {
          "displayNameEn" : [
            "<em>James</em> Harden" // 高亮显示,默认标签：<em>
          ]
        }
      }
      // ......
    ]
  }
}

```

## 2、自定义标签

```js
POST /nba_latest/_search
{
  "query": {
    "match": {
      "displayNameEn": "james"
    }
  },
  "highlight": {
    "fields": {
      "displayNameEn": {
        "pre_tags": ["<h1>"],    // 开始标签
        "post_tags": ["</h1>"]   // 结束标签
      }
    }
  }
}
```

# 五、词条建议查询

假设我们在百度里进行搜索：jave （本来是要搜索java的，输出错误），这个时候，百度就会弹出 **jave是什么，java语言，javaEE是什么，javelin**等建议查询的词语。这就是建议查询

## 1、term suggester词条建议器

*  term suggester 词条建议器，对给入的文本进行分词，为每个分词荐建议

```js
POST /nba_latest/_search
{
  "suggest": {
    "my-suggestion": {
      "text": "jamse",       // 原单词为：james，特意输错
        "suggest_mode": "missing",
        "field": "displayNameEn"
      }
    }
  }
}

// 结果
{
  "took" : 5,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 0,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [ ]
  },
  "suggest" : {
    "my-suggestion" : [
      {
        "text" : "jamse",  // 词条查询单词
        "offset" : 0,
        "length" : 5,
        "options" : [
          {
            "text" : "james", // 推荐结果 1
            "score" : 0.8,
            "freq" : 5
          },
          {
            "text" : "jamal",  // 推荐结果 2
            "score" : 0.6,
            "freq" : 2
          },
          {
            "text" : "jake",  // 推荐结果 3
            "score" : 0.5,
            "freq" : 1
          },
          {
            "text" : "jose",
            "score" : 0.5,
            "freq" : 1
          }
        ]
      }
    ]
  }
}

```

## 2、Phrase Suggester短语建议

phrase短语建议，在term的基础上，会考量多个term之间的关系，比如是否同时出现在索引的原文里，相邻程度，以及词频等

```
POST /nba_latest/_search
{
  "suggest": {
    "my-suggestion": {
      "text": "jamse harden",
      "phrase": {
        "field": "displayNameEn"
      }
    }
  }
}
```

## 3、Completion Suggester完成建议

搜索单词不完成，建议补全

```js
POST /nba_latest/_search
{
  "suggest": {
    "my-suggestion": {
      "text": "Miami",  // 一个不完成的错误单词
      "completion": {
        "field": "displayCityEn"
      }
    }
  }
}
```

