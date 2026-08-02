-- ============================================================
-- undo_log 表 (AT 模式必须)
-- 说明: AT 模式下,每个参与分布式事务的数据库都需要创建此表
--       Seata 在执行业务 SQL 前,会先保存数据的前镜像(before image),
--       执行后保存后镜像(after image),写入此表。
--       当全局事务回滚时,RM 根据 undo_log 中的镜像数据反向补偿。
--       当全局事务提交时,TC 异步通知 RM 删除对应的 undo_log 记录。
-- ============================================================

-- undo_log 建表语句 (通用,适用于所有业务库)
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
