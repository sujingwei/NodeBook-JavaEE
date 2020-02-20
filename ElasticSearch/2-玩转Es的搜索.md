# 一、批量导入数据

- Es提供一个叫**bulk**的API来进行批量操作(批量的CRUD)

**准备数据，bulk规定最后一条数据后面必需有一个换行**

```json
{"index": {"_index":"book","_type":"_doc","_id":1}}
{"name":"权力的游戏"}
{"index": {"_index":"book","_type":"_doc","_id":2}}
{"name":"疯狂的石头"}

```

导入操作

```sh
curl -X POST "localhost:9200/_bulk" -H 'Content-Type: application/json' --data-binary @filename
# 操作如下：
curl -X POST "http://localhost:9200/_bulk" -H "Content-Type: application/json" --da ta-binary @E:\es
```

# 二、term的多种查询

term是单词级别查询，这些查询通常用于结构化的数据，比如：number,date,keyword等，而不是text

也就是说，全文查询之前要先对文本内容进行分词，而单词级别的查询直接在相应字段的反向索引中精确查找，单词级别的查询一般用于数值、日期等类型的字段上

## 1、Term Query精准匹配查询

查询出球衣号是 23 号的所有球员

```js
post /nba/_search
{
  "query": {
    "term": {
      "jerseyNo": "23" 
    }
  },
  "from":0,
  "size":5
}
```

## 2、Exsit Query 在特定的字段中查询非空的文档

teamNameEn字段不为空的所有文档

```js
post /nba/_search
{
  "query": {
    "exists": {
      "field": "teamNameEn"
    }
  }
}
```

## 3、Prefix Query 查找包含带指定前缀的term的文档

不能查询**text类型**的字段

```js
post /nba/_search
{
  "query": {
    "prefix": {
      "teamNameEn": "Rock"
    }
  }
}
```

## 4、Wildcard Query 支持通配符查询

```js
post /nba/_search
{
  "query": {
    "wildcard": {
      "teamNameEn`": "Ro*k"
    }
  }
}
```

## 5、Regexp Query正则查询

```js
post /nba/_search
{
  "query": {
    "regexp": {
      "teamNameEn": "Ro.*k"
    }
  }
}
```

## 6、ids Query 通过ID查询

```js
post /nba/_search
{
  "query": {
    "ids": {
      "values": [1,2,3,4,5]
    }
  }
}
```

# 三、ElasticSearch的范围查询

- 查找指定字段在指定范围内包含值(日期、数字或字符串)的文档

如球龄在2 - 10 年范围内的球员

```js
POST /nba/_search
{
  "query": {
    "range": {
      "playYear": {
        "gte": 2,
        "lte": 10
      }
    }
  }
}
```

在1990-01-01 - 2022出生的球员

```js
POST /nba/_search
{
  "query": {
    "range": {
      "birthDayStr": {
        "gte": "01/01/1999",
        "lte": "2022",
        "format": "dd/MM/yyyy||yyyy"  // 日期格式，需要format
      }
    }
  }
}
```

# 四、布尔查询

| type     | description                  |
| -------- | ---------------------------- |
| must     | 必须出现在匹配文档中         |
| filter   | 必须出现在文档中，但是不打分 |
| must_not | 不能出现在文档中             |
| should   | 应该出现在文档中             |

## 1、must

```
POST /nba/_search
{
  "query": {
    "bool": {     // 布尔查询
      "must": [   // must 查询
        {
          "match": {
            "displayNameEn": "james"
          }
        }
      ]
    }
  }
}
```

## 2、filter

```js
POST /nba/_search
{
  "query": {
    "bool": {         // 布尔查询
      "filter": [     // filter 查询
        {
          "match": {
            "displayNameEn": "james"
          }
        }
      ]
    }
  }
}
```

## 3、must_not

displayNameEn包含“james”，并且不在“Eastern”的球员

```
POST /nba/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "displayNameEn": "james"
          }
        }
      ],
      "must_not": [    // 不包含
        {
          "term": {
            "teamConferenceEn": {
              "value": "Eastern"
            }
          }
        }
      ]
    }
  }
}
```

## 4、should

displayNameEn包含“james”，并且不在“Eastern”的球员，并且球龄**应该在(不一定在)**11 - 20 年之间

```js
POST /nba/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "displayNameEn": "james"
          }
        }
      ],
      "must_not": [
        {
          "term": {
            "teamConferenceEn": {
              "value": "Eastern"
            }
          }
        }
      ],
      "should": [
        {
          "range": {
            "playYear": {
              "gte": 11,
              "lte": 20
            }
          }
        }
      ],
      "minimum_should_match": 1   // 如果加入它，就是必须包含 should 里的条件，而不是应该包含
    }
  }
}
```

# 五、ES的排序

## 1、火箭队中按打球时间从大到小排序的球员

```js
POST /nba/_search
{
  "query": {
    "match": {
      "teamNameEn": "Rockets"   // 查找出所有火箭队的球员
    }
  },
  "sort": [
    {
      "playYear": {            // 对 playYear 字段进行倒序排序
        "order": "desc"
      }
    }
  ],
  "from": 0,                   // 分页
  "size": 100
}
```

## 2、火箭队中按打球时间从大到小，结果打球年龄相同则按照身高从低到高排序球员

```js
POST /nba/_search
{
  "query": {
    "match": {
      "teamNameEn": "Rockets"
    }
  },
  "sort": [
    {
      "playYear": {     // 球龄从大到小
        "order": "desc"
      }
    },
    {
      "heightValue": {  // 身高从小到大
        "order": "asc"
      }
    }
  ],
  "from": 0,
  "size": 100
}
```

# 六、查询之指标聚合

聚合查询是数据库中重要的特性，完成对一个查询到数据集的聚合计算，如果：找出某个字段(或计算表达式的结果)的最大值、最小值，计算和、平均值等。Es作为搜索引擎，同样提供了强大的聚合分析能力。

对一个数据集求最大、最小、和、平均值等指标聚合，在Es中称为**指标聚合**

而关系型数据库中除了有聚合函数外，还可以对查询出的数据进行分组group by，再在组上进行指标聚合。在 ES中称为**桶聚合**。

## 1、指标聚合

### 1）求火箭队的球员的平均年龄

```js
POST /nba/_search
{
  "query":{
    "term": {
      "teamNameEn.keyword": {
        "value":"Rockets"
      }
    }
  },
  "aggs": {           // 使用指标聚合
    "avgAge": {       // 自定义输出字段名称
      "avg": {        // 求平均值
        "field":"age" // 指定字段
      }
    }
  },
  "size": 0          // 如果设置size为0，表示不输出查询的结果信息
}
```

### 2）非空字段的文档数

```js
POST /nba/_search
{
  "query":{
    "term": {
      "teamNameEn.keyword": {
        "value":"Rockets"
      }
    }
  },
  "aggs": {
    "countPlayerYear": {
      "value_count": {   // 查询出非空字段
        "field":"playYear"
      }
    }
  },
  "size": 0
}
```

### 3）查出火箭队有多少名球员（不属于聚合）

```
POST /nba/_count
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  }
}
```

### 4）得到火箭队球员年龄不相同的个数

```js
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "countAge": {
      "cardinality": {
        "field": "age"   // 对age字段的值去重
      }
    }
  },
  "size":0
}
```

### 5）stats一次统计count,max,min,avg,sum 五个值

查出灯火箭队球员的年龄stats

```js
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "statsAge": {
      "stats": {
        "field": "age"
      }
    }
  },
  "size":0
}
```

返回结果：

```json
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
      "value" : 21,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [ ]
  },
  "aggregations" : {
    "statsAge" : {
      "count" : 21,
      "min" : 21.0,
      "max" : 37.0,
      "avg" : 26.761904761904763,
      "sum" : 562.0
    }
  }
}
```

使用**extended_stats**会比**stats**返回更多的数据，包含<u>平方和、方差、标准差、平均值加/减的区间</u>。

```
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "extendStatsAge": {
      "extended_stats": {
        "field": "age"
      }
    }
  },
  "size":0
}
```

### 6）Percentiles占比百分位对应的值，默认返回[1,5,25,50,75,95,99]分位上的值

**查出火箭的球员的年龄占比**

```
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "percentilesAge": {
      "percentiles": {
        "field": "age"
      }
    }
  },
  "size":0
}
```

返回值：

```json
{
  "took" : 2,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 21,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [ ]
  },
  "aggregations" : {
    "percentilesAge" : {
      "values" : {
        "1.0" : 21.0,
        "5.0" : 21.0,
        "25.0" : 22.75,                  // 少于 22.75岁的，占 25%
        "50.0" : 25.0,                   // 少于 25.0岁的，占 50%
        "75.0" : 30.25,                  // 少于 30.25岁的，占 75%
        "95.0" : 35.349999999999994,     // 少于 35.35岁的，占 95%
        "99.0" : 37.0                    // 少于 37.0岁的，占 99%
      }
    }
  }
}
```

可以自定义**分位值**：

```js
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "percentilesAge": {
      "percentiles": {
        "field": "age",
        "percents": [20, 50, 70]
      }
    }
  },
  "size":0
}
```

## 2、桶聚合

### 1）根据字段项目分组聚合

* 火箭队根据年龄进行分组

```js
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "aggsAge": {
      "terms": {
        "field": "age",   // 需要分组的字段
        "size": 10,       // 指定显示桶数,如果分组比较多，可以指定更多的桶数
      }
    }
  },
  "size":0
}
```

结果：

```json
{
  "took" : 1,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 21,
      "relation" : "eq"
    },
    "max_score" : null,
    "hits" : [ ]
  },
  "aggregations" : {
    "aggsAge" : {
      "doc_count_error_upper_bound" : 0,
      "sum_other_doc_count" : 3,
      "buckets" : [
        {
          "key" : 21,
          "doc_count" : 4  // 21 岁的有4份文档，也就是有4个人
        },
        {
          "key" : 25,
          "doc_count" : 3
        },
        {
          "key" : 23,
          "doc_count" : 2
        },
        {
          "key" : 30,
          "doc_count" : 2
        },
        {
          "key" : 34,
          "doc_count" : 2
        },
        {
          "key" : 22,
          "doc_count" : 1
        },
        {
          "key" : 24,
          "doc_count" : 1
        },
        {
          "key" : 26,
          "doc_count" : 1
        },
        {
          "key" : 27,
          "doc_count" : 1
        },
        {
          "key" : 29,
          "doc_count" : 1
        }
      ]
    }
  }
}

```

### 2）order分组聚合排序

* 火箭队根据年龄进行分组，分组信息通过年龄从大到小排序，也可以是其它排序字段

```js
POST /nba/_search
{
  "query": {
    "term": {
      "teamNameEn.keyword": {
        "value": "Rockets"
      }
    }
  },
  "aggs": {
    "aggsAge": {
      "terms": {
        "field": "age",
        "size": 10,
        "order":{
          "_key": "desc"   // 如果要对文档数进行排序，"key"改为"_count"
        }
      }
    }
  },
  "size":0
}
```

### 3）每支球队按该队所有球员的平均年龄进行分组排序(通过分组指标值)

```
POST /nba/_search
{
  "aggs": {
    "aggsTeamName": {
      "terms": {
        "field": "teamNameEn.keyword",
        "size": 30,
        "order": {"avgAge":"desc"}  // 自定义名称
      },
      "aggs": {
        "avgAge": {
          "avg": {
            "field": "age"
          }
        }
      }
    }
  },
  "size": 0
}
```

### 4）筛选分组

* 湖人和火箭队按球队平均年龄进行分组排序（指定值列表）

```js
POST /nba/_search
{
  "aggs": {
    "aggsTeamName": {
      "terms": {
        "field": "teamNameEn.keyword",
        "include": ["Lakers", "Rockets", "Warriors"],   // 要包含的球队
            // 也可以这样使用：
            // "include": Lakers|Ro.*|Warriors.* // 使用正则匹配出火箭和勇士
        "exclude": ["Warriors"],                        // 不要包含的球队
        "size": 30,
        "order": {"avgAge":"desc"}  // 自定义名称
      },
      "aggs": {
        "avgAge": {
          "avg": {
            "field": "age"
          }
        }
      }
    }
  },
  "size": 0
}
```

### 5）Range Aggregation 范围分组聚合

* NBA球员年龄按照20,20-35,35,这样分组