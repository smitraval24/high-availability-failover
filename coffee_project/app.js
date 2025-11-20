// app.js

const express = require('express');
const { query, pool } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// BREAKING CHANGE: Force health check failure for rollback testing
// This middleware intentionally breaks the root endpoint to test automatic rollback
app.use((req, res, next) => {
  if (req.path === '/' || req.path === '/index.html') {
    console.error('SIMULATED FAILURE: Returning 503 to trigger rollback');
    return res.status(503).json({ 
      error: 'Service temporarily unavailable', 
      message: 'This is a simulated failure to test automatic rollback'
    });
  }
  next();
});

app.use(express.static('public'));

// Endpoint to fetch available coffees
app.get('/coffees', async (req, res) => {
  try {
    const result = await query('SELECT id, name, price FROM coffees ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Endpoint to place an order
app.post('/order', async (req, res) => {
  const { coffeeId, quantity } = req.body;

  try {
    const coffeeRes = await query('SELECT id, name, price FROM coffees WHERE id = $1', [coffeeId]);
    const coffee = coffeeRes.rows[0];

    if (!coffee) return res.status(400).json({ error: 'Invalid coffee ID' });

    const insertRes = await query(
      'INSERT INTO orders (coffeeId, quantity) VALUES ($1, $2) RETURNING orderId, created_at',
      [coffeeId, quantity]
    );

    const orderInfo = insertRes.rows[0];

    const order = {
      orderId: orderInfo.orderid || orderInfo.orderId,
      coffeeName: coffee.name,
      quantity,
      total: Number(coffee.price) * quantity,
      created_at: orderInfo.created_at
    };

    res.status(201).json(order);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Endpoint to fetch all orders
app.get('/orders', async (req, res) => {
  try {
    const result = await query(
      `SELECT o.orderId, c.name as coffeeName, o.quantity, (c.price * o.quantity) as total, o.created_at
       FROM orders o
       JOIN coffees c ON o.coffeeId = c.id
       ORDER BY o.orderId`
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Endpoint to update coffee price
app.put('/coffees/:id/price', async (req, res) => {
  const { id } = req.params;
  const { price } = req.body;

  if (!price || isNaN(price) || price <= 0) {
    return res.status(400).json({ error: 'Invalid price. Must be a positive number.' });
  }

  try {
    const result = await query(
      'UPDATE coffees SET price = $1 WHERE id = $2 RETURNING id, name, price',
      [price, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Coffee not found' });
    }

    res.json({ 
      message: 'Price updated successfully', 
      coffee: result.rows[0] 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server started on http://localhost:${PORT}`);
  });
}

module.exports = app;
