-- ============================================================
-- Seata Server 存储表结构 (DB 模式)
-- 数据库: seata_server
-- 适用版本: Seata 1.5.x ~ 2.5.x (Apache)
-- 说明: 当 Seata Server 的 store.mode=db 时,需要创建以下表
-- ============================================================

CREATE DATABASE IF NOT EXISTS `seata_server` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `seata_server`;

-- ------------------------------------------------------------
-- 1. 全局事务表 global_table
--    记录每一个全局事务的 XID、事务名、状态、超时时间等
--    TC 通过此表管理全局事务的生命周期
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `global_table`
(
    `xid`                       VARCHAR(128) NOT NULL,
    `transaction_id`            BIGINT,
    `status`                    TINYINT      NOT NULL,
    `application_id`            VARCHAR(32),
    `transaction_service_group` VARCHAR(32),
    `transaction_name`          VARCHAR(128),
    `timeout`                   INT,
    `begin_time`                BIGINT,
    `application_data`          VARCHAR(2000),
    `gmt_create`                DATETIME,
    `gmt_modified`              DATETIME,
    PRIMARY KEY (`xid`),
    KEY `idx_status_gmt_modified` (`status` , `gmt_modified`),
    KEY `idx_transaction_id` (`transaction_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- ------------------------------------------------------------
-- 2. 分支事务表 branch_table
--    记录每一个分支事务的信息,包括所属全局事务 XID、
--    分支事务 ID、资源 ID、事务状态等
--    TC 通过此表管理各分支事务的提交与回滚
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `branch_table`
(
    `branch_id`         BIGINT       NOT NULL,
    `xid`               VARCHAR(128) NOT NULL,
    `transaction_id`    BIGINT,
    `resource_group_id` VARCHAR(32),
    `resource_id`       VARCHAR(256),
    `branch_type`       VARCHAR(8),
    `status`            TINYINT      NOT NULL,
    `client_id`         VARCHAR(64),
    `application_data`  VARCHAR(2000),
    `gmt_create`        DATETIME(6),
    `gmt_modified`      DATETIME(6),
    PRIMARY KEY (`branch_id`),
    KEY `idx_xid` (`xid`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- ------------------------------------------------------------
-- 3. 全局锁表 lock_table
--    在 AT 模式下,Seata 通过全局锁实现写隔离
--    当分支事务修改某行数据时,会在此表记录该行的锁信息
--    防止其他全局事务并发修改同一行数据
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `lock_table`
(
    `row_key`        VARCHAR(128) NOT NULL,
    `xid`            VARCHAR(128),
    `transaction_id` BIGINT,
    `branch_id`      BIGINT       NOT NULL,
    `resource_id`    VARCHAR(256),
    `table_name`     VARCHAR(32),
    `pk`             VARCHAR(36),
    `status`         TINYINT      NOT NULL DEFAULT '0' COMMENT '0:locked ,1:rollbacking',
    `gmt_create`     DATETIME,
    `gmt_modified`   DATETIME,
    PRIMARY KEY (`row_key`),
    KEY `idx_branch_id` (`branch_id`),
    KEY `idx_xid` (`xid`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- ------------------------------------------------------------
-- 4. 分布式锁表 distributed_lock
--    Seata 1.5+ 新增,用于 TC 集群内部的选主与协调
--    例如: 防止多个 TC 节点同时进行事务日志清理
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `distributed_lock`
(
    `lock_key`       CHAR(20) NOT NULL,
    `lock_value`     VARCHAR(20) NOT NULL,
    `expire`         BIGINT,
    primary key (`lock_key`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

INSERT IGNORE INTO `distributed_lock` (lock_key, lock_value, expire) VALUES ('AsyncCommitting', ' ', 0);
INSERT IGNORE INTO `distributed_lock` (lock_key, lock_value, expire) VALUES ('RetryCommitting', ' ', 0);
INSERT IGNORE INTO `distributed_lock` (lock_key, lock_value, expire) VALUES ('RetryRollbacking', ' ', 0);
INSERT IGNORE INTO `distributed_lock` (lock_key, lock_value, expire) VALUES ('TxTimeoutCheck', ' ', 0);
