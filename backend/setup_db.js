const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// On shared hosting (Namecheap cPanel), the DB already exists and is pre-created
// by the hosting panel — we connect directly to it, not as root.
async function setup() {
  try {
    const connection = await mysql.createConnection({
      host:               process.env.DB_HOST || 'localhost',
      user:               process.env.DB_USER || 'nayshzoc_naysa_user',
      password:           process.env.DB_PASS || '',
      database:           process.env.DB_NAME || 'nayshzoc_nasa_db',
      multipleStatements: true
    });

    console.log(`Connected to MySQL → ${process.env.DB_NAME || 'nayshzoc_nasa_db'}`);

    let schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');

    // On cPanel shared hosting we can't CREATE DATABASE (already exists),
    // so strip those two lines before running.
    schema = schema
      .replace(/CREATE DATABASE IF NOT EXISTS[^;]+;/gi, '')
      .replace(/USE [^;]+;/gi, '');

    await connection.query(schema);
    console.log('✅ All tables created and seed data inserted successfully.');

    await connection.end();
  } catch (error) {
    console.error('❌ Setup failed:', error.message || error);
    process.exit(1);
  }
}

setup();
