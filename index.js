const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
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
  password: 'osqs4wah0lvh7ag3',
  port: 39939,
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal Server Error' });
});

// User Registration - POST /register
app.post('/register', async (req, res) => {
  const { email, password, username } = req.body;

  if (!email || !password || !username) {
    return res.status(400).json({ 
      success: false,
      message: 'Email, username, and password are required' 
    });
  }

  try {
    // Check if user exists
    const userExists = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR username = $2',
      [email, username]
    );

    if (userExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'User already exists with this email or username'
      });
    }

    // Hash password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create new user
    const newUser = await pool.query(
      `INSERT INTO users (email, username, password_hash)
       VALUES ($1, $2, $3)
       RETURNING user_id, email, username`,
      [email, username, hashedPassword]
    );

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: newUser.rows[0]
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Error during registration'
    });
  }
});

// User Login - POST /login
app.post('/login', async (req, res) => {
  const { emailOrUsername, password } = req.body;

  if (!emailOrUsername || !password) {
    return res.status(400).json({ 
      success: false,
      message: 'Email/Username and password are required' 
    });
  }

  try {
    // Find user by email or username
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR username = $1',
      [emailOrUsername]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    const user = result.rows[0];
    
    // Verify password
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Successful login
    res.json({
      success: true,
      message: 'Login successful',
      user: {
        userId: user.user_id,
        email: user.email,
        username: user.username
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during login'
    });
  }
});

// Sensor data route - GET /sensor_data
app.get('/sensor_data', async (req, res) => {
  try {
    let { farm_id, date } = req.query;

    if (!farm_id) {
      return res.status(400).json({
        success: false,
        message: 'farm_id query parameter is required'
      });
    }

    // Get latest date if none provided
    if (!date) {
      const latestDateResult = await pool.query(
        "SELECT MAX(DATE(timestamp)) AS latest_date FROM sensor_data WHERE farm_id = $1",
        [farm_id]
      );
      date = latestDateResult.rows[0]?.latest_date;
      
      if (!date) {
        return res.json({
          success: true,
          data: []
        });
      }
    }

    // Fetch sensor data
    const sensorDataResult = await pool.query(
      `SELECT * FROM sensor_data 
       WHERE farm_id = $1 AND DATE(timestamp) = $2`,
      [farm_id, date]
    );

    res.json({
      success: true,
      data: sensorDataResult.rows
    });

  } catch (error) {
    console.error('Sensor data error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor data'
    });
  }
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Sensor Data API is running'
  });
});

// Start server
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});