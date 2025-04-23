const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
  user: 'tsdbadmin',
  host: 'oqgaq0awq0.eg58c9ppkd.tsdb.cloud.timescale.com',
  database: 'tsdb',
  password: 'm9na2uqvvzx61d67',
  port: 39939,
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal Server Error' });
});

// Root route
app.get('/', (req, res) => {
  res.send('Welcome to Sensor Data API!');
});

// Get all sensor data
app.get('/sensor_data', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM sensor_data');
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

// Get sensor data by farm and date
app.get('/sensor_data/:farm/:date', async (req, res) => {
  const { farm, date } = req.params;
  try {
    const result = await pool.query(
      'SELECT * FROM sensor_data WHERE farm_id = $1 AND DATE("timestamp") = $2',
      [farm, date]
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

// Create new sensor data
app.post('/sensor_data', async (req, res) => {
  const { sensor_id, value, farm_id, timestamp } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO sensor_data (sensor_id, value, farm_id, "timestamp") VALUES ($1, $2, $3, $4) RETURNING *',
      [sensor_id, value, farm_id, timestamp]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// Update sensor data by ID
app.put('/sensor_data/:id', async (req, res) => {
  const { id } = req.params;
  const { sensor_id, value, farm_id, timestamp } = req.body;
  try {
    const result = await pool.query(
      'UPDATE sensor_data SET sensor_id = $1, value = $2, farm_id = $3, "timestamp" = $4 WHERE id = $5 RETURNING *',
      [sensor_id, value, farm_id, timestamp, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sensor data not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// Delete sensor data by ID
app.delete('/sensor_data/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      'DELETE FROM sensor_data WHERE id = $1 RETURNING *',
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sensor data not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
