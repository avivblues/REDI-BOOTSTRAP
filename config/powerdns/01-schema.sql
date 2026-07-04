-- =============================================================================
-- PowerDNS MySQL Schema — Official schema for PowerDNS 4.8+
-- Source: https://doc.powerdns.com/authoritative/backends/generic-mysql.html
-- =============================================================================

CREATE TABLE IF NOT EXISTS domains (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(8) NOT NULL,
  notified_serial       INT UNSIGNED DEFAULT NULL,
  account               VARCHAR(40) CHARACTER SET utf8mb4 DEFAULT NULL,
  options               VARCHAR(64000) DEFAULT NULL,
  catalog               VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY name_index (name),
  KEY catalog_idx (catalog)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS records (
  id                    BIGINT AUTO_INCREMENT,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               TEXT DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  disabled              TINYINT(1) DEFAULT 0,
  ordername             VARCHAR(255) BINARY DEFAULT NULL,
  auth                  TINYINT(1) DEFAULT 1,
  PRIMARY KEY (id),
  KEY domain_id (domain_id),
  KEY nametype_index (name, type),
  KEY domain_id_ordername (domain_id, ordername)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) CHARACTER SET utf8mb4 NOT NULL,
  PRIMARY KEY (ip, nameserver)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) CHARACTER SET utf8mb4 DEFAULT NULL,
  comment               TEXT CHARACTER SET utf8mb4 NOT NULL,
  PRIMARY KEY (id),
  KEY comments_domain_id_idx (domain_id),
  KEY comments_name_type_idx (name, type),
  KEY comments_order_idx (domain_id, modified_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32) DEFAULT NULL,
  content               TEXT DEFAULT NULL,
  PRIMARY KEY (id),
  KEY domainmetadata_idx (domain_id, kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS cryptokeys (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL DEFAULT NULL,
  published             BOOL DEFAULT 1,
  content               TEXT DEFAULT NULL,
  PRIMARY KEY (id),
  KEY domainidindex (domain_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tsigkeys (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) DEFAULT NULL,
  algorithm             VARCHAR(50) DEFAULT NULL,
  secret                VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY namealgoindex (name, algorithm)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- REDI LAB — Initial zone data
-- =============================================================================

INSERT INTO domains (name, type, account) VALUES ('redi.lab', 'NATIVE', 'redi-admin');

SET @domain_id = LAST_INSERT_ID();

INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth) VALUES
(@domain_id, 'redi.lab', 'SOA', 'ns1.redi.lab hostmaster.redi.lab 2026010101 3600 600 604800 3600', 3600, 0, 0, 1),
(@domain_id, 'redi.lab', 'NS', 'ns1.redi.lab', 3600, 0, 0, 1),
(@domain_id, 'redi.lab', 'NS', 'ns2.redi.lab', 3600, 0, 0, 1),
(@domain_id, 'ns1.redi.lab', 'A', '103.149.238.98', 300, 0, 0, 1),
(@domain_id, 'ns2.redi.lab', 'A', '103.80.214.144', 300, 0, 0, 1),
(@domain_id, 'traefik-jkt.redi.lab', 'A', '100.64.0.1', 300, 0, 0, 1),
(@domain_id, 'traefik-sby.redi.lab', 'A', '100.64.0.2', 300, 0, 0, 1),
(@domain_id, 'gitlab.redi.lab', 'A', '100.64.0.3', 300, 0, 0, 1),
(@domain_id, 'portainer.redi.lab', 'A', '100.64.0.3', 300, 0, 0, 1),
(@domain_id, '*.redi.lab', 'A', '100.64.0.1', 300, 0, 0, 1);
