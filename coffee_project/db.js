const { Pool } = require('pg');

// Use DATABASE_URL if provided (useful for CI or hosted DB), otherwise default to local Postgres
const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/coffee_dev';

const pool = new Pool({ connectionString });

async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

module.exports = { pool, query };
