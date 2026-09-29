-- Align SpringBoot menu uniqueness with the NestJS full-field duplicate check.
-- The migration is defensive because existing databases may use a generated
-- name for the old single-column unique index, or may not have that index.

SET @menu_name_index = (
    SELECT MAX(s.INDEX_NAME)
    FROM INFORMATION_SCHEMA.STATISTICS s
    WHERE s.TABLE_SCHEMA = DATABASE()
      AND s.TABLE_NAME = 'menu'
      AND s.NON_UNIQUE = 0
      AND s.COLUMN_NAME = 'name'
      AND s.INDEX_NAME <> 'PRIMARY'
      AND (
          SELECT COUNT(*)
          FROM INFORMATION_SCHEMA.STATISTICS s2
          WHERE s2.TABLE_SCHEMA = s.TABLE_SCHEMA
            AND s2.TABLE_NAME = s.TABLE_NAME
            AND s2.INDEX_NAME = s.INDEX_NAME
      ) = 1
);

SET @drop_menu_name_index = IF(
    @menu_name_index IS NULL,
    'SELECT 1',
    CONCAT('ALTER TABLE `menu` DROP INDEX `', @menu_name_index, '`')
);

PREPARE drop_menu_name_index_statement FROM @drop_menu_name_index;
EXECUTE drop_menu_name_index_statement;
DEALLOCATE PREPARE drop_menu_name_index_statement;

SET @menu_identity_index_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS s
    WHERE s.TABLE_SCHEMA = DATABASE()
      AND s.TABLE_NAME = 'menu'
      AND s.INDEX_NAME = 'uk_menu_identity'
);

SET @drop_menu_identity_index = IF(
    @menu_identity_index_exists = 0,
    'SELECT 1',
    'ALTER TABLE `menu` DROP INDEX `uk_menu_identity`'
);

PREPARE drop_menu_identity_index_statement FROM @drop_menu_identity_index;
EXECUTE drop_menu_identity_index_statement;
DEALLOCATE PREPARE drop_menu_identity_index_statement;

-- A multi-column utf8mb4 index cannot cover all six VARCHAR(255) fields within
-- MySQL's index-size limit. The generated digest is based on every complete
-- field value and uses a dedicated marker for NULL, so NULL equals NULL for
-- duplicate detection instead of following MySQL's nullable-index behavior.
SET @menu_identity_column_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.TABLE_SCHEMA = DATABASE()
      AND c.TABLE_NAME = 'menu'
      AND c.COLUMN_NAME = 'menu_identity_hash'
);

SET @add_menu_identity_column = IF(
    @menu_identity_column_exists = 0,
    'ALTER TABLE `menu` ADD COLUMN `menu_identity_hash` BINARY(32) GENERATED ALWAYS AS (UNHEX(SHA2(CONCAT(IF(`name` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`name`), '':'', `name`)), IF(`order` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`order`), '':'', `order`)), IF(`menuType` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`menuType`), '':'', `menuType`)), IF(`parentId` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`parentId`), '':'', `parentId`)), IF(`path` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`path`), '':'', `path`)), IF(`icon` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`icon`), '':'', `icon`)), IF(`component` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`component`), '':'', `component`)), IF(`locale` IS NULL, ''-1:'', CONCAT(CHAR_LENGTH(`locale`), '':'', `locale`))), 256))) STORED',
    'SELECT 1'
);

PREPARE add_menu_identity_column_statement FROM @add_menu_identity_column;
EXECUTE add_menu_identity_column_statement;
DEALLOCATE PREPARE add_menu_identity_column_statement;

SET @menu_identity_index_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS s
    WHERE s.TABLE_SCHEMA = DATABASE()
      AND s.TABLE_NAME = 'menu'
      AND s.INDEX_NAME = 'uk_menu_identity'
);

SET @add_menu_identity_index = IF(
    @menu_identity_index_exists = 0,
    'ALTER TABLE `menu` ADD UNIQUE KEY `uk_menu_identity` (`menu_identity_hash`)',
    'SELECT 1'
);

PREPARE add_menu_identity_index_statement FROM @add_menu_identity_index;
EXECUTE add_menu_identity_index_statement;
DEALLOCATE PREPARE add_menu_identity_index_statement;
