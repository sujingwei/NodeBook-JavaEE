## 一、maven基础知识回顾

maven是一个项目管理工具，主要有以下两个功能：

* 依赖管理：maven对项目中jar包的管理过程。传统工程我们直接把jar包放置在项目中。maven工程 真正的jar包放置在仓库中。项目中只用放置jar包的坐标。
* 一键构建：maven自身集成了tomcat插件，可以对项目进行编译、测试、打包、安装、发布等操作。

仓库的种类：

* 本地仓库
* 远程仓库（私服）
* 中央仓库

当我们启去一个maven工程的时候，maven工程会通过pom.xml文件中的jar包坐标去本地仓库找对就的jar包。如果本地仓库没有对应jar包， maven工程人自动去中央仓库下载jar包到本地仓库

maven自身集成的tomcat组件是通过以下几个命令来使用的：

* clean
* compile 编译
* test 测试
* package 打包
* install 安装到本地仓库
* deploy 从本地上传jar包到私服

maven生命周期：清理生命周期(clean)、默认生命周期(compile/test/package/install)、站点生命周期

## 1、解决jar包冲突的三种技

```xml
<dependencies>
        <!--
          maven 工程要导入jar包坐标，就必须考虑解决jar包冲突
          解决方法一：第一声明原则，那个jar包先声明，就导入那个jar包的jar文件到项目中
          解决方法二：直接依赖
          解决方法三：排除某个jar包
        -->
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-beans</artifactId>
            <version>4.2.4.RELEASE</version>
            <!-- 当我们要排除某个jar包 -->
            <exclusions>
                <exclusion>
                    <groupId>org.springframework</groupId>
                    <artifactId>spring-core</artifactId>
                </exclusion>
            </exclusions>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-context</artifactId>
            <version>5.0.2.RELEASE</version>
        </dependency>

        <!-- 直接依赖：直接指定版本， -->
        <!--<dependency>-->
            <!--<groupId>org.springframework</groupId>-->
            <!--<artifactId>spring-core</artifactId>-->
            <!--<version>4.2.8.RELEASE</version>-->
        <!--</dependency>-->

    </dependencies>
```

# 二、Maven父子工程

​	工程和模块的区别：工程和模块不等于完整的项目，一个完整的项目看的是代码，代码完整，就可以说这是一个完整的项目和此项目工程模块没有关系。

* 工程天生只能使用自己的内部资源，工程是独立的。后天可以和其它工程模块建立关联系统。
* 模块天生不是独立的，它是属于父工程的，模块一旦创建，所有父工程的资源都可以使用。

父子工程，子模板天生集成父工程所有资源。子模块之间天生是没有任何关系的。

父子工程这间不用建立关系，继承关系是先天的，不需要手动建立。

平直之间的引用就依赖。依赖是后天建立的。

在实际开发中，如果传递依赖丢失，表现形式就是jar的坐标导不进去，我们的做法就是直接再导入一次。

## 1、创建Maven的父子工程

### 第一步：创建父项目和子模块

父工程中，只需要存在pom.xml文件就可以，其它目录和文件可以删除。在工程中建立子模块就可以了。

在项目中建立maven_day02_dao、maven_day02_service、maven_day02_web三个子模块。

### 第二步：建立模块与模块之间的关系

**maven_day02_service模块引用maven_day02_dao模块**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>maven_day_02_parent</artifactId>
        <groupId>com.itheima</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <artifactId>maven_day02_service</artifactId>

    <dependencies>

        <!-- 引入maven_day02_dao模块 -->
        <dependency>
            <groupId>com.itheima</groupId>
            <artifactId>maven_day02_dao</artifactId>
            <version>1.0-SNAPSHOT</version>
        </dependency>

    </dependencies>
</project>
```

**maven_day02_web模块引用maven_day02_service模块**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>maven_day_02_parent</artifactId>
        <groupId>com.itheima</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <artifactId>model_day02_web</artifactId>
    <packaging>war</packaging>

    <dependencies>
        <!-- 引入maven_day02_service模块 -->
        <dependency>
            <groupId>com.itheima</groupId>
            <artifactId>maven_day02_service</artifactId>
            <version>1.0-SNAPSHOT</version>
        </dependency>

    </dependencies>

</project>
```

### 第三步、三种启动方式

#### 第一种，通过启动父工程的tomcat maven插件启动项目

#### 第二种，通过启动model_day_web模块启动（注意，父工程必需使用 mvn install）

#### 第三种，通过本地安装的tomcat启动，需要配置

# 三、nexus私服

