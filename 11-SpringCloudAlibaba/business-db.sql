-- ============================================================
-- 业务数据库建表 SQL 及初始数据
-- 场景: 模拟电商下单流程 (下单 -> 扣减库存 -> 扣减账户余额)
-- 涉及 3 个业务数据库:
--   1. seata_order  - 订单服务库
--   2. seata_storage - 库存服务库
--   3. seata_account - 账户服务库
-- ============================================================


-- ============================================================
-- 1. 订单数据库 seata_order
-- ============================================================
CREATE DATABASE IF NOT EXISTS `seata_order` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `seata_order`;

-- undo_log 表 (AT 模式必须)
CREATE TABLE IF NOT EXISTS `undo_log`
(
    `branch_id`     BIGINT       NOT NULL COMMENT 'branch transaction id',
    `xid`           VARCHAR(128) NOT NULL COMMENT 'global transaction id',
    `context`       VARCHAR(128) NOT NULL COMMENT 'undo_log context,such as serialization',
    `rollback_info` LONGTEXT     NOT NULL COMMENT 'rollback info',
    `log_status`    INT          NOT NULL COMMENT '0:normal status,1:defense status',
    `log_created`   DATETIME(6)  NOT NULL COMMENT 'create datetime',
    `log_modified`  DATETIME(6)  NOT NULL COMMENT 'modify datetime',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT ='AT transaction mode undo table';

-- 订单表 t_order
DROP TABLE IF EXISTS `t_order`;
CREATE TABLE `t_order` (
    `id`              BIGINT(11)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT(11)   DEFAULT NULL COMMENT '用户ID',
    `product_id`      BIGINT(11)   DEFAULT NULL COMMENT '产品ID',
    `count`           INT(11)      DEFAULT NULL COMMENT '数量',
    `money`           DECIMAL(11,0) DEFAULT NULL COMMENT '金额',
    `status`          INT(1)       DEFAULT NULL COMMENT '订单状态: 0-创建中, 1-已完成',
    PRIMARY KEY (`id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT = '订单表';


-- ============================================================
-- 2. 库存数据库 seata_storage
-- ============================================================
CREATE DATABASE IF NOT EXISTS `seata_storage` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `seata_storage`;

-- undo_log 表
CREATE TABLE IF NOT EXISTS `undo_log`
(
    `branch_id`     BIGINT       NOT NULL COMMENT 'branch transaction id',
    `xid`           VARCHAR(128) NOT NULL COMMENT 'global transaction id',
    `context`       VARCHAR(128) NOT NULL COMMENT 'undo_log context,such as serialization',
    `rollback_info` LONGTEXT     NOT NULL COMMENT 'rollback info',
    `log_status`    INT          NOT NULL COMMENT '0:normal status,1:defense status',
    `log_created`   DATETIME(6)  NOT NULL COMMENT 'create datetime',
    `log_modified`  DATETIME(6)  NOT NULL COMMENT 'modify datetime',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT ='AT transaction mode undo table';

-- 库存表 t_storage
DROP TABLE IF EXISTS `t_storage`;
CREATE TABLE `t_storage` (
    `id`              BIGINT(11)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`      BIGINT(11)   DEFAULT NULL COMMENT '产品ID',
    `total`           INT(11)      DEFAULT NULL COMMENT '总库存',
    `used`            INT(11)      DEFAULT NULL COMMENT '已用库存',
    `residue`         INT(11)      DEFAULT NULL COMMENT '剩余库存',
    PRIMARY KEY (`id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT = '库存表';

-- 库存初始数据: 产品1, 总库存100, 已用0, 剩余100
INSERT INTO `t_storage` (`id`, `product_id`, `total`, `used`, `residue`)
VALUES (1, 1, 100, 0, 100);


-- ============================================================
-- 3. 账户数据库 seata_account
-- ============================================================
CREATE DATABASE IF NOT EXISTS `seata_account` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `seata_account`;

-- undo_log 表
CREATE TABLE IF NOT EXISTS `undo_log`
(
    `branch_id`     BIGINT       NOT NULL COMMENT 'branch transaction id',
    `xid`           VARCHAR(128) NOT NULL COMMENT 'global transaction id',
    `context`       VARCHAR(128) NOT NULL COMMENT 'undo_log context,such as serialization',
    `rollback_info` LONGTEXT     NOT NULL COMMENT 'rollback info',
    `log_status`    INT          NOT NULL COMMENT '0:normal status,1:defense status',
    `log_created`   DATETIME(6)  NOT NULL COMMENT 'create datetime',
    `log_modified`  DATETIME(6)  NOT NULL COMMENT 'modify datetime',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT ='AT transaction mode undo table';

-- 账户表 t_account
DROP TABLE IF EXISTS `t_account`;
CREATE TABLE `t_account` (
    `id`              BIGINT(11)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT(11)   DEFAULT NULL COMMENT '用户ID',
    `total`           DECIMAL(11,0) DEFAULT NULL COMMENT '总额度',
    `used`            DECIMAL(11,0) DEFAULT NULL COMMENT '已用余额',
    `residue`         DECIMAL(11,0) DEFAULT '0' COMMENT '剩余可用额度',
    PRIMARY KEY (`id`)
) ENGINE = InnoDB AUTO_INCREMENT = 1 DEFAULT CHARSET = utf8mb4 COMMENT = '账户表';

-- 账户初始数据: 用户1, 总额度1000, 已用0, 剩余1000
INSERT INTO `t_account` (`id`, `user_id`, `total`, `used`, `residue`)
VALUES (1, 1, 1000, 0, 1000);
