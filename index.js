const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const cors = require('cors');

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Database configuration

 const pool = new Pool({
      user: 'president',
      host: '192.168.101.5',
      database: 'postgres',
      password: 'president123',
      port: 5431,
      connectionTimeoutMillis: 30000, 
      idleTimeoutMillis: 120000, 
      max: 20, 
  });

// const pool = new Pool({
//   user: 'tsdbadmin',
//   host: 'oqgaq0awq0.eg58c9ppkd.tsdb.cloud.timescale.com',
//   database: 'tsdb',
//   password: 'k10onp6321hhiqtn',
//   port: 39939,
//   connectionTimeoutMillis: 30000,
//   idleTimeoutMillis: 120000,
//   max: 20,
// });

// Test database connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error acquiring database client', err.stack);
    return;
  }
  client.query('SELECT NOW()', (err, result) => {
    release();
    if (err) {
      console.error('Error executing database test query', err.stack);
      return;
    }
    console.log('Database connected successfully at:', result.rows[0].now);
  });
});

// User Registration
app.post('/register', async (req, res) => {
  const { email, password, username } = req.body;

  if (!email || !password || !username) {
    return res.status(400).json({
      success: false,
      message: 'Email, username, and password are required',
    });
  }

  try {
    const userExists = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR name = $2',
      [email, username]
    );

    if (userExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'User already exists with this email or username',
      });
    }

    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    const newUser = await pool.query(
      `INSERT INTO users (email, name, password)
       VALUES ($1, $2, $3)
       RETURNING name, email`,
      [email, username, hashedPassword]
    );

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: newUser.rows[0],
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Error during registration',
    });
  }
});

// User Login
app.post('/login', async (req, res) => {
  const { emailOrUsername, password } = req.body;

  if (!emailOrUsername || !password) {
    return res.status(400).json({
      success: false,
      message: 'Email/Username and password are required',
    });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR name = $1',
      [emailOrUsername]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    const user = result.rows[0];
    const isValid = await bcrypt.compare(password, user.password);
    
    if (!isValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    res.json({
      success: true,
      message: 'Login successful',
      user: {
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during login',
    });
  }
});

// Password Reset Request
app.post('/request-password-reset', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ 
      success: false, 
      message: 'Email is required' 
    });
  }

  try {
    const userResult = await pool.query(
      'SELECT id, email FROM users WHERE email = $1', 
      [email]
    );

    if (userResult.rows.length === 0) {
      return res.status(200).json({ 
        success: true, 
        message: 'If an account exists with this email, a reset link has been sent' 
      });
    }

    const user = userResult.rows[0];
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour
    
    await pool.query(
      'UPDATE users SET reset_token = $1, reset_token_expiry = $2 WHERE id = $3',
      [resetToken, resetTokenExpiry, user.id]
    );

    console.log(`Password reset token for ${email}: ${resetToken}`);

    res.status(200).json({ 
      success: true, 
      message: 'If an account exists with this email, a reset link has been sent',
      token: resetToken // For testing only
    });

  } catch (error) {
    console.error('Password reset request error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error processing password reset request' 
    });
  }
});

// Password Reset
app.post('/reset-password', async (req, res) => {
  const { token, newPassword } = req.body;

  if (!token || !newPassword) {
    return res.status(400).json({ 
      success: false, 
      message: 'Token and new password are required' 
    });
  }

  try {
    const userResult = await pool.query(
      'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expiry > NOW()',
      [token]
    );

    if (userResult.rows.length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid or expired token' 
      });
    }

    const user = userResult.rows[0];
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
    
    await pool.query(
      'UPDATE users SET password = $1, reset_token = NULL, reset_token_expiry = NULL WHERE id = $2',
      [hashedPassword, user.id]
    );

    res.status(200).json({ 
      success: true, 
      message: 'Password updated successfully' 
    });

  } catch (error) {
    console.error('Password reset error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error resetting password' 
    });
  }
});

// Validate Reset Token
app.get('/validate-reset-token', async (req, res) => {
  const { token } = req.query;

  if (!token) {
    return res.status(400).json({ 
      success: false, 
      message: 'Token is required' 
    });
  }

  try {
    const result = await pool.query(
      'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expiry > NOW()',
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({ 
        success: false, 
        valid: false,
        message: 'Invalid or expired token' 
      });
    }

    res.status(200).json({ 
      success: true, 
      valid: true,
      message: 'Token is valid' 
    });

  } catch (error) {
    console.error('Token validation error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error validating token' 
    });
  }
});

// Sensor Data Endpoints
app.get('/sensor_data', async (req, res) => {
  try {
    const { farm_id, start_date, end_date, sensor_id } = req.query;

    if (!farm_id) {
      return res.status(400).json({
        success: false,
        message: 'farm_id query parameter is required',
      });
    }

    let query = `SELECT * FROM sensor_data WHERE farm_id = $1`;
    const queryParams = [farm_id];
    let paramIndex = 2;

    if (start_date && end_date) {
      query += ` AND timestamp >= $${paramIndex} AND timestamp <= $${paramIndex + 1}`;
      queryParams.push(start_date, end_date);
      paramIndex += 2;
    } else if (start_date) {
      query += ` AND timestamp >= $${paramIndex}`;
      queryParams.push(start_date);
      paramIndex++;
    } else if (end_date) {
      query += ` AND timestamp <= $${paramIndex}`;
      queryParams.push(end_date);
      paramIndex++;
    }

    if (sensor_id) {
      query += ` AND sensor_id = $${paramIndex}`;
      queryParams.push(sensor_id);
    }

    query += ` ORDER BY timestamp ASC;`;

    const sensorDataResult = await pool.query(query, queryParams);

    res.json({
      success: true,
      data: sensorDataResult.rows,
    });
  } catch (error) {
    console.error('Sensor data error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor data',
    });
  }
});

app.get('/latest_sensor_data', async (req, res) => {
  try {
    const { farm_id } = req.query;

    if (!farm_id) {
      return res.status(400).json({
        success: false,
        message: 'farm_id query parameter is required',
      });
    }

    const query = `
      SELECT DISTINCT ON (sensor_id) *
      FROM sensor_data
      WHERE farm_id = $1
      ORDER BY sensor_id, timestamp DESC;
    `;
    const queryParams = [farm_id];

    const latestDataResult = await pool.query(query, queryParams);

    res.json({
      success: true,
      data: latestDataResult.rows,
    });

  } catch (error) {
    console.error('Latest sensor data error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching latest sensor data',
    });
  }
});

app.get('/sensors', async (req, res) => {
  try {
    const { farm_id } = req.query;

    if (!farm_id) {
      return res.status(400).json({
        success: false,
        message: 'farm_id query parameter is required',
      });
    }

    const query = `
      SELECT DISTINCT sensor_id, name
      FROM sensor_data
      WHERE farm_id = $1
      ORDER BY sensor_id;
    `;
    const queryParams = [farm_id];

    const sensorsResult = await pool.query(query, queryParams);

    res.json({
      success: true,
      data: sensorsResult.rows,
    });

  } catch (error) {
    console.error('Error fetching sensor list:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor list',
    });
  }
});


app.get('/gnss_devices', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT gnss_id FROM gnss ORDER BY gnss_id'
    );
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching GNSS devices:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching GNSS devices'
    });
  }
});

app.get('/gnss_sensor_data', async (req, res) => {
  try {
    const { gnss_id, sensor_id, start_date, end_date } = req.query;

    if (!gnss_id) {
      return res.status(400).json({
        success: false,
        message: 'gnss_id parameter is required'
      });
    }

    let query = `
      SELECT 
        id,
        gnss_id,
        sensor_id,
        value,
        timestamp
      FROM sensor_data
      WHERE gnss_id = $1
    `;
    const params = [gnss_id];
    let paramIndex = 2;

    if (sensor_id) {
      query += ` AND sensor_id = $${paramIndex}`;
      params.push(sensor_id);
      paramIndex++;
    }

    if (start_date && end_date) {
      query += ` AND timestamp BETWEEN $${paramIndex} AND $${paramIndex + 1}`;
      params.push(start_date, end_date);
      paramIndex += 2;
    }

    query += ' ORDER BY timestamp ASC';

    const result = await pool.query(query, params);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('GNSS sensor data error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching GNSS sensor data'
    });
  }
});

app.get('/gnss_latest_data', async (req, res) => {
  try {
    const { gnss_id } = req.query;

    if (!gnss_id) {
      return res.status(400).json({
        success: false,
        message: 'gnss_id parameter is required'
      });
    }

    const query = `
      SELECT DISTINCT ON (sensor_id) *
      FROM gnss
      WHERE gnss_id = $1
      ORDER BY sensor_id, timestamp DESC
    `;

    const result = await pool.query(query, [gnss_id]);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('GNSS latest data error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching latest GNSS data'
    });
  }
});

app.get('/gnss_sensors', async (req, res) => {
  try {
    const { gnss_id } = req.query;

    if (!gnss_id) {
      return res.status(400).json({
        success: false,
        message: 'gnss_id parameter is required'
      });
    }

    const query = `
      SELECT DISTINCT sensor_id
      FROM sensor_data
      WHERE gnss_id = $1
      ORDER BY sensor_id
    `;

    const result = await pool.query(query, [gnss_id]);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('GNSS sensors error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching GNSS sensors'
    });
  }
});


// Root endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Sensor Data API is running',
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err.stack);
  res.status(500).json({ 
    success: false, 
    message: 'Internal Server Error' 
  });
});

// Start server
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});