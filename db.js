// db.js
const sql = require("mssql");

const config = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_DATABASE,
  port: parseInt(process.env.DB_PORT, 10),
  options: {
    encrypt: false, // set true if using Azure SQL
    trustServerCertificate: true, // needed for local dev/self-signed certs
  },
};


async function connectDB() {
  try {
    let pool = await sql.connect(config);
    console.log("✅ Connected to MSSQL");
    return pool;
  } catch (err) {
    console.error("❌ Database connection failed: ", err);
    throw err;
  }
}

module.exports = { sql, connectDB };


