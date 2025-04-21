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
  res.status(500).send('Something broke!');
});

// Root route
app.get('/', (req, res) => {
  res.send('Welcome to Sensor Data API!');
});

// Get all sensor data
app.get('/sensor-data', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM sensor_data');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Get sensor data by farm name
app.get('/sensor-data/farm/:farmName', async (req, res) => {
  const { farmName } = req.params;
  try {
    const result = await pool.query(
      `
      SELECT sd.sensor_id, sd.value, sd.timestamp, f.farm_id, f.name AS farm_name, f.location
      FROM sensor_data sd
      JOIN farms f ON sd.farm_id = f.farm_id
      WHERE f.name = $1
      `,
      [farmName]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Create new sensor data
app.post('/sensor-data', async (req, res) => {
  const { sensor_id, value, farm_id, timestamp } = req.body;
  try {
    const result = await pool.query(
      `
      INSERT INTO sensor_data (sensor_id, value, farm_id, "timestamp")
      VALUES ($1, $2, $3, $4)
      RETURNING *
      `,
      [sensor_id, value, farm_id, timestamp]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Update sensor data by sensor_id and timestamp
app.put('/sensor-data/:sensorId/:timestamp', async (req, res) => {
  const { sensorId, timestamp } = req.params;
  const { value, farm_id } = req.body;
  try {
    const result = await pool.query(
      `
      UPDATE sensor_data
      SET value = $1, farm_id = $2
      WHERE sensor_id = $3 AND "timestamp" = $4
      RETURNING *
      `,
      [value, farm_id, sensorId, timestamp]
    );
    if (result.rows.length === 0) {
      return res.status(404).send('Sensor data not found');
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Delete sensor data by sensor_id and timestamp
app.delete('/sensor-data/:sensorId/:timestamp', async (req, res) => {
  const { sensorId, timestamp } = req.params;
  try {
    const result = await pool.query(
      `
      DELETE FROM sensor_data
      WHERE sensor_id = $1 AND "timestamp" = $2
      RETURNING *
      `,
      [sensorId, timestamp]
    );
    if (result.rows.length === 0) {
      return res.status(404).send('Sensor data not found');
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
