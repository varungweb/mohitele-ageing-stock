// db.js
const sql = require("mssql");

const config = {
  user: 'sa',
password: 'Busy@123',
server: 'vps.q2w.in',
database: 'BusyComp0001_db12025',
port: 14331,
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


