const { pool } = require('./db');

const coffees = [
  { id: 1, name: 'Latte', price: 5 },
  { id: 2, name: 'Espresso', price: 3 },
  { id: 3, name: 'Cappuccino', price: 4 },
];

async function migrate() {
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

  for (const c of coffees) {
    await pool.query(
      'INSERT INTO coffees (id, name, price) VALUES ($1, $2, $3) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, price = EXCLUDED.price',
      [c.id, c.name, c.price]
    );
  }

  console.log('Postgres migration + seed complete');
  process.exit(0);
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
