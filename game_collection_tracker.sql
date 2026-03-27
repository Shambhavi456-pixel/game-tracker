-- =============================================================
--  GAME COLLECTION TRACKER
--  Course  : Database Management Systems
--  Student : Shambhavi Singh (24051432)
--  KIIT University | 2025-2026
--  Database: MySQL
-- =============================================================

-- -------------------------------------------------------------
-- STEP 0: Create & select the database
-- -------------------------------------------------------------
DROP DATABASE IF EXISTS game_tracker;
CREATE DATABASE game_tracker;
USE game_tracker;

-- =============================================================
--  SECTION 1: DDL – CREATE TABLES
-- =============================================================

CREATE TABLE DEVELOPER (
    developer_id INT          PRIMARY KEY AUTO_INCREMENT,
    dev_name     VARCHAR(100) NOT NULL
);

CREATE TABLE GAME (
    game_id      INT          PRIMARY KEY AUTO_INCREMENT,
    game_name    VARCHAR(150) NOT NULL,
    genre        VARCHAR(50),
    developer_id INT,
    FOREIGN KEY (developer_id) REFERENCES DEVELOPER(developer_id)
        ON DELETE SET NULL
);

CREATE TABLE PLAYER (
    player_id   INT          PRIMARY KEY AUTO_INCREMENT,
    player_name VARCHAR(100) NOT NULL
);

CREATE TABLE PLATFORM (
    platform_id   INT         PRIMARY KEY AUTO_INCREMENT,
    platform_name VARCHAR(50) NOT NULL
);

-- Junction table: resolves M:N between GAME and PLATFORM
CREATE TABLE GAME_PLATFORM (
    game_id     INT NOT NULL,
    platform_id INT NOT NULL,
    PRIMARY KEY (game_id, platform_id),
    FOREIGN KEY (game_id)     REFERENCES GAME(game_id)     ON DELETE CASCADE,
    FOREIGN KEY (platform_id) REFERENCES PLATFORM(platform_id) ON DELETE CASCADE
);

CREATE TABLE PRICE (
    price_id INT            PRIMARY KEY AUTO_INCREMENT,
    game_id  INT            NOT NULL,
    amount   DECIMAL(8, 2)  NOT NULL,
    FOREIGN KEY (game_id) REFERENCES GAME(game_id) ON DELETE CASCADE
);

-- Weak entity: PLAY_HISTORY identified by (player_id, game_id)
CREATE TABLE PLAY_HISTORY (
    player_id    INT NOT NULL,
    game_id      INT NOT NULL,
    hours_played INT DEFAULT 0,
    PRIMARY KEY (player_id, game_id),
    FOREIGN KEY (player_id) REFERENCES PLAYER(player_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id)   REFERENCES GAME(game_id)     ON DELETE CASCADE
);

-- =============================================================
--  SECTION 2: DML – INSERT SAMPLE DATA
-- =============================================================

INSERT INTO DEVELOPER (dev_name) VALUES
    ('CD Projekt Red'),
    ('Naughty Dog'),
    ('FromSoftware'),
    ('Rockstar Games'),
    ('Nintendo');

INSERT INTO GAME (game_name, genre, developer_id) VALUES
    ('The Witcher 3',      'RPG',        1),
    ('The Last of Us',     'Action',     2),
    ('Elden Ring',         'RPG',        3),
    ('GTA V',              'Open World', 4),
    ('The Legend of Zelda: BOTW', 'Adventure', 5);

INSERT INTO PLAYER (player_name) VALUES
    ('Shambhavi'),
    ('Raj'),
    ('Ananya'),
    ('Dev'),
    ('Priya');

INSERT INTO PLATFORM (platform_name) VALUES
    ('PC'),
    ('PlayStation 5'),
    ('Xbox Series X'),
    ('Nintendo Switch');

INSERT INTO GAME_PLATFORM (game_id, platform_id) VALUES
    (1, 1), (1, 2),          -- Witcher 3: PC, PS5
    (2, 2), (2, 3),          -- Last of Us: PS5, Xbox
    (3, 1), (3, 2),          -- Elden Ring: PC, PS5
    (4, 1), (4, 2), (4, 3),  -- GTA V: PC, PS5, Xbox
    (5, 4);                  -- Zelda: Switch only

INSERT INTO PRICE (game_id, amount) VALUES
    (1, 29.99),
    (2, 19.99),
    (3, 59.99),
    (4, 14.99),
    (5, 49.99);

INSERT INTO PLAY_HISTORY (player_id, game_id, hours_played) VALUES
    (1, 1, 120),
    (1, 3,  45),
    (2, 2,  80),
    (2, 4,  60),
    (3, 3,  30),
    (3, 5,  95),
    (4, 1,  15),
    (4, 4, 200),
    (5, 2,  50),
    (5, 5,  40);

-- =============================================================
--  SECTION 3: DML – SELECT QUERIES
-- =============================================================

-- Query 1: All games with their developer name
SELECT
    g.game_id,
    g.game_name,
    g.genre,
    d.dev_name AS developer
FROM GAME g
JOIN DEVELOPER d ON g.developer_id = d.developer_id
ORDER BY g.game_name;

-- Query 2: All platforms each game is available on
SELECT
    g.game_name,
    p.platform_name
FROM GAME_PLATFORM gp
JOIN GAME     g ON gp.game_id     = g.game_id
JOIN PLATFORM p ON gp.platform_id = p.platform_id
ORDER BY g.game_name, p.platform_name;

-- Query 3: Price of each game
SELECT
    g.game_name,
    CONCAT('$', FORMAT(pr.amount, 2)) AS price
FROM PRICE pr
JOIN GAME g ON pr.game_id = g.game_id
ORDER BY pr.amount DESC;

-- Query 4: Total hours played per player (leaderboard)
SELECT
    pl.player_name,
    SUM(ph.hours_played) AS total_hours
FROM PLAY_HISTORY ph
JOIN PLAYER pl ON ph.player_id = pl.player_id
GROUP BY pl.player_name
ORDER BY total_hours DESC;

-- Query 5: Play history for a specific player
SELECT
    pl.player_name,
    g.game_name,
    ph.hours_played
FROM PLAY_HISTORY ph
JOIN PLAYER pl ON ph.player_id = pl.player_id
JOIN GAME   g  ON ph.game_id   = g.game_id
WHERE pl.player_name = 'Shambhavi'
ORDER BY ph.hours_played DESC;

-- Query 6: Most played game overall
SELECT
    g.game_name,
    SUM(ph.hours_played) AS total_hours_all_players
FROM PLAY_HISTORY ph
JOIN GAME g ON ph.game_id = g.game_id
GROUP BY g.game_name
ORDER BY total_hours_all_players DESC
LIMIT 1;

-- Query 7: Games with no play history (never played)
SELECT g.game_name
FROM GAME g
LEFT JOIN PLAY_HISTORY ph ON g.game_id = ph.game_id
WHERE ph.game_id IS NULL;

-- Query 8: Average price of all games
SELECT
    CONCAT('$', FORMAT(AVG(amount), 2)) AS avg_price
FROM PRICE;

-- =============================================================
--  SECTION 4: VIEWS
-- =============================================================

-- View 1: Game catalogue (game + developer + price)
CREATE OR REPLACE VIEW vw_game_catalogue AS
SELECT
    g.game_id,
    g.game_name,
    g.genre,
    d.dev_name     AS developer,
    pr.amount      AS price_usd
FROM GAME g
JOIN DEVELOPER d ON g.developer_id  = d.developer_id
JOIN PRICE     pr ON g.game_id      = pr.game_id;

-- View 2: Player stats summary
CREATE OR REPLACE VIEW vw_player_stats AS
SELECT
    pl.player_id,
    pl.player_name,
    COUNT(ph.game_id)        AS games_played,
    SUM(ph.hours_played)     AS total_hours,
    MAX(ph.hours_played)     AS most_hours_single_game
FROM PLAYER pl
LEFT JOIN PLAY_HISTORY ph ON pl.player_id = ph.player_id
GROUP BY pl.player_id, pl.player_name;

-- Use the views
SELECT * FROM vw_game_catalogue   ORDER BY price_usd DESC;
SELECT * FROM vw_player_stats     ORDER BY total_hours DESC;

-- =============================================================
--  END OF SCRIPT
-- =============================================================
