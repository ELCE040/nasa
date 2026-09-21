const mysql = require('mysql2/promise');
require('dotenv').config();

async function migrate() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASS || '',
    database: process.env.DB_NAME || 'nayshzoc_nasa_db',
  });
  
  try {
    await pool.query('ALTER TABLE match_events ADD COLUMN assistName VARCHAR(255), ADD COLUMN isPenalty TINYINT(1) DEFAULT 0');
    console.log('match_events migration successful');
  } catch(e) { console.log('match_events err:', e.message); }
  
  try {
    await pool.query('ALTER TABLE matches ADD COLUMN phase VARCHAR(50) DEFAULT \'First Half\'');
    console.log('matches migration successful');
  } catch(e) { console.log('matches err:', e.message); }

  try {
    await pool.query('ALTER TABLE players ADD COLUMN imageUrl TEXT DEFAULT NULL');
    console.log('players image migration successful');
  } catch(e) { console.log('players image err:', e.message); }

  try {
    await pool.query("ALTER TABLE leagues ADD COLUMN format VARCHAR(50) DEFAULT 'league'");
    console.log('leagues format migration successful');
  } catch(e) { console.log('leagues format err:', e.message); }

  try {
    await pool.query("ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League Match', ADD COLUMN groupName VARCHAR(50) DEFAULT NULL");
    console.log('matches stage/groupName migration successful');
  } catch(e) { console.log('matches stage/groupName err:', e.message); }

  try {
    await pool.query("ALTER TABLE teams ADD COLUMN groupName VARCHAR(50) DEFAULT NULL");
    console.log('teams groupName migration successful');
  } catch(e) { console.log('teams groupName err:', e.message); }
  
  process.exit(0);
}

migrate();
