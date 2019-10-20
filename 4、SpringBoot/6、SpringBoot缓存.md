# 缓存

## 一、JSR-107规范

Java Caching定义了5个核心接口，分别是CachingProvider, Cachemanager, Cache, Entry和Expiry。

`CachingProvider`定义了创建、配置、获取管理和控制多个CacheManager。一个应用可以在运行期间访问多个CachingProvider。

`Cachemanager`定义了创建、配置、获取、管理和控制多个唯一命名的Cache，这些Cache存在于Cachemanager的上下文中。

`Cache`就一个类似Map的数据结构，并临时存储以Key为索引的值。一个Cache仅被一个CacheManager拥有。

`Entry`是一个存储在Cache中的key-value对

`Expiry`每一个存储在Cache中的条目有一个定义有效期。一旦超过这个时间，条目为过期的状态。一旦过期，条目将不可访问、更新和删除。缓存有效期可以通过ExpiryPolicy设置。

实际开发中，不使用JSR-107，会使用SpringBoot缓存抽象。

| Cache            | 缓存接口定义缓存操作，实现有：RedisCache、EhCacheCache、ConcurrentMapCache等 |
| ---------------- | ------------------------------------------------------------ |
| **CacheManager** | **缓存管理器，管理各种缓存(Cache)组件**                      |
| @Cacheable       | 针对方法配置，能够根据方法的请求参数对其结果进行缓存         |
| @CacheEvict      | 清空缓存                                                     |
| @CachePut        | 保证方法被调用，又希望结果被缓存                             |
| @EnableCaching   | 开启基于注解的缓存                                           |
| KeyGenerator     | 缓存数据时key的生成策略                                      |
| serialize        | 缓存数据时value序列化策略                                    |

