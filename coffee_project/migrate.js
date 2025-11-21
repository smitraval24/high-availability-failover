const { Pool } = require('pg');
const { pool } = require('./db');

const coffees = [
  { id: 1, name: 'Latte', price: 5 },
  { id: 2, name: 'Espresso', price: 3 },
  { id: 3, name: 'Cappuccino', price: 4 },
];

async function ensureDatabase() {
  // Connect to default 'postgres' database to create coffee_dev if needed
  const dbUrl = process.env.DATABASE_URL || 'postgresql://postgres:postgres@db:5432/postgres';
  const defaultDbUrl = dbUrl.replace(/\/[^/]+$/, '/postgres');

  const adminPool = new Pool({ connectionString: defaultDbUrl });

  try {
    // Check if coffee_dev exists
    const result = await adminPool.query(
      "SELECT 1 FROM pg_database WHERE datname = 'coffee_dev'"
    );

    if (result.rows.length === 0) {
      console.log('Creating database coffee_dev...');
      await adminPool.query('CREATE DATABASE coffee_dev');
      console.log('Database coffee_dev created');
    } else {
      console.log('Database coffee_dev already exists');
    }
  } catch (err) {
    console.error('Error checking/creating database:', err.message);
  } finally {
    await adminPool.end();
  }
}

async function migrate() {
  // First ensure the database exists
  await ensureDatabase();

  // Now run migrations on coffee_dev
  await pool.query(`
    CREATE TABLE IF NOT EXISTS coffees (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      price NUMERIC NOT NULL
    );

    CREATE TABLE IF NOT EXISTS orders (
      orderId SERIAL PRIMARY KEY,
      coffeeId INTEGER NOT NULL REFERENCES coffees(id),
      quantity INTEGER NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
    );
  `);

  // Only seed if the coffees table is empty (preserve existing data)
  const existingData = await pool.query('SELECT COUNT(*) FROM coffees');
  const rowCount = parseInt(existingData.rows[0].count, 10);

  if (rowCount === 0) {
    console.log('No existing data found. Seeding initial coffee data...');
    for (const c of coffees) {
      await pool.query(
        'INSERT INTO coffees (id, name, price) VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING',
        [c.id, c.name, c.price]
      );
    }
    console.log('Seed data inserted');
  } else {
    console.log(`Database already has ${rowCount} coffee(s). Skipping seed data to preserve existing data.`);
  }

  console.log('Postgres migration complete');
  await pool.end();
  process.exit(0);
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
