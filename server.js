require("dotenv").config();

const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");

const app = express();

app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || "127.0.0.1",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "game_tracker",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

function send(res, data, code = 200) {
  res.status(code).json({ success: true, data });
}

function err(res, e, code = 500) {
  console.error("FULL ERROR:", e);
  res.status(code).json({
    success: false,
    error: e.message || String(e)
  });
}

/* =========================
   GAMES
========================= */

// Get all games
app.get("/api/games", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        g.game_id,
        g.game_name,
        g.genre,
        g.developer_id,
        d.dev_name AS developer
      FROM GAME g
      LEFT JOIN DEVELOPER d ON g.developer_id = d.developer_id
      ORDER BY g.game_id
    `);

    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

// Get one game with full details
app.get("/api/games/:id", async (req, res) => {
  try {
    const gameId = req.params.id;

    const [gameRows] = await pool.query(
      `
      SELECT
        g.game_id,
        g.game_name,
        g.genre,
        g.developer_id,
        d.dev_name AS developer
      FROM GAME g
      LEFT JOIN DEVELOPER d ON g.developer_id = d.developer_id
      WHERE g.game_id = ?
      `,
      [gameId]
    );

    if (gameRows.length === 0) {
      return err(res, new Error("Game not found"), 404);
    }

    const [platformRows] = await pool.query(
      `
      SELECT
        p.platform_id,
        p.platform_name
      FROM GAME_PLATFORM gp
      JOIN PLATFORM p ON gp.platform_id = p.platform_id
      WHERE gp.game_id = ?
      ORDER BY p.platform_name
      `,
      [gameId]
    );

    const [priceRows] = await pool.query(
      `
      SELECT
        price_id,
        amount
      FROM PRICE
      WHERE game_id = ?
      ORDER BY price_id
      `,
      [gameId]
    );

    const [historyRows] = await pool.query(
      `
      SELECT
        pl.player_id,
        pl.player_name,
        ph.hours_played
      FROM PLAY_HISTORY ph
      JOIN PLAYER pl ON ph.player_id = pl.player_id
      WHERE ph.game_id = ?
      ORDER BY ph.hours_played DESC
      `,
      [gameId]
    );

    send(res, {
      ...gameRows[0],
      platforms: platformRows,
      prices: priceRows,
      play_history: historyRows
    });
  } catch (e) {
    err(res, e);
  }
});

// Add a game
app.post("/api/games", async (req, res) => {
  try {
    const { game_name, genre, developer_id } = req.body;

    if (!game_name || !genre || !developer_id) {
      return err(res, new Error("game_name, genre, and developer_id are required"), 400);
    }

    const [result] = await pool.query(
      `
      INSERT INTO GAME (game_name, genre, developer_id)
      VALUES (?, ?, ?)
      `,
      [game_name, genre, developer_id]
    );

    send(
      res,
      {
        game_id: result.insertId,
        game_name,
        genre,
        developer_id: Number(developer_id)
      },
      201
    );
  } catch (e) {
    err(res, e);
  }
});

// Update a game
app.put("/api/games/:id", async (req, res) => {
  try {
    const { game_name, genre, developer_id } = req.body;

    if (!game_name || !genre || !developer_id) {
      return err(res, new Error("game_name, genre, and developer_id are required"), 400);
    }

    const [result] = await pool.query(
      `
      UPDATE GAME
      SET game_name = ?, genre = ?, developer_id = ?
      WHERE game_id = ?
      `,
      [game_name, genre, developer_id, req.params.id]
    );

    if (!result.affectedRows) {
      return err(res, new Error("Game not found"), 404);
    }

    send(res, {
      game_id: Number(req.params.id),
      game_name,
      genre,
      developer_id: Number(developer_id)
    });
  } catch (e) {
    err(res, e);
  }
});

// Delete a game
app.delete("/api/games/:id", async (req, res) => {
  try {
    const [result] = await pool.query(
      `DELETE FROM GAME WHERE game_id = ?`,
      [req.params.id]
    );

    if (!result.affectedRows) {
      return err(res, new Error("Game not found"), 404);
    }

    send(res, { deleted_id: Number(req.params.id) });
  } catch (e) {
    err(res, e);
  }
});

/* =========================
   DEVELOPERS
========================= */

app.get("/api/developers", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT developer_id, dev_name
      FROM DEVELOPER
      ORDER BY developer_id
    `);
    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

/* =========================
   PLAYERS
========================= */

app.get("/api/players", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT player_id, player_name
      FROM PLAYER
      ORDER BY player_id
    `);
    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

/* =========================
   PLATFORMS
========================= */

app.get("/api/platforms", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT platform_id, platform_name
      FROM PLATFORM
      ORDER BY platform_id
    `);
    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

/* =========================
   ROOT
========================= */

app.get("/", (req, res) => {
  res.send("Game Tracker API is running");
});

const PORT = process.env.PORT || 3000;
// Get player count for each game
app.get("/api/game-player-counts", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        g.game_id,
        COUNT(ph.player_id) AS total_players
      FROM GAME g
      LEFT JOIN PLAY_HISTORY ph ON g.game_id = ph.game_id
      GROUP BY g.game_id
      ORDER BY g.game_id
    `);

    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

// Get favorite games
app.get("/api/favorites", async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        f.game_id,
        g.game_name
      FROM FAVORITES f
      JOIN GAME g ON f.game_id = g.game_id
      ORDER BY f.game_id
    `);

    send(res, rows);
  } catch (e) {
    err(res, e);
  }
});

// Add to favorites
app.post("/api/favorites", async (req, res) => {
  try {
    const { game_id } = req.body;

    if (!game_id) {
      return err(res, new Error("game_id is required"), 400);
    }

    await pool.query(
      `INSERT IGNORE INTO FAVORITES (game_id) VALUES (?)`,
      [game_id]
    );

    send(res, { game_id: Number(game_id), message: "Added to favorites" }, 201);
  } catch (e) {
    err(res, e);
  }
});

// Remove from favorites
app.delete("/api/favorites/:id", async (req, res) => {
  try {
    await pool.query(
      `DELETE FROM FAVORITES WHERE game_id = ?`,
      [req.params.id]
    );

    send(res, { deleted_id: Number(req.params.id) });
  } catch (e) {
    err(res, e);
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});