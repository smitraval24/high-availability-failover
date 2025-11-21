const { Pool } = require('pg');

// Use DATABASE_URL if provided (useful for CI or hosted DB), otherwise default to local Postgres
const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/coffee_dev';

// Configure connection pool with proper limits and timeouts
const pool = new Pool({
  connectionString,
  max: 20,                    // Maximum pool size
  min: 2,                     // Minimum pool size (keep connections warm)
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 10000, // Timeout waiting for connection (10s)
  maxUses: 7500,              // Recycle connections after 7500 uses
});

// Handle pool errors to prevent app crashes
pool.on('error', (err) => {
  console.error('Unexpected database pool error:', err);
  // Don't exit - let the app continue and retry
});

// Retry logic for database queries
async function query(text, params, retries = 3) {
  let lastError;

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await pool.query(text, params);
      return res;
    } catch (err) {
      lastError = err;
      console.error(`Database query failed (attempt ${attempt}/${retries}):`, err.message);

      // Don't retry on data validation errors
      if (err.code === '23505' || err.code === '23503' || err.code === '22P02') {
        throw err;
      }

      // Wait before retrying (exponential backoff)
      if (attempt < retries) {
        const waitTime = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }

  // All retries failed
  throw lastError;
}

// Test database connection on startup with retries
async function testConnection(maxRetries = 10) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await pool.query('SELECT 1');
      console.log('✓ Database connection established');
      return true;
    } catch (err) {
      console.error(`Database connection failed (attempt ${attempt}/${maxRetries}):`, err.message);
      if (attempt < maxRetries) {
        const waitTime = 2000; // Wait 2s between retries
        console.log(`Retrying in ${waitTime / 1000}s...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
  console.error('✗ Failed to connect to database after all retries');
  return false;
}

// Graceful shutdown
async function closePool() {
  try {
    await pool.end();
    console.log('Database pool closed');
  } catch (err) {
    console.error('Error closing database pool:', err);
  }
}

module.exports = { pool, query, testConnection, closePool };
