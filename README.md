# Node.js Express + MySQL Backend

This project is a simple backend using Node.js, Express, and MySQL. It demonstrates how to connect to a MySQL database and provides a test route to verify the connection.

## Setup

1. Install dependencies:
   ```bash
   npm install express mysql2
   ```
2. Configure your MySQL credentials in `db.js`.
3. Run the server:
   ```bash
   node index.js
   ```

## Test
Visit `http://localhost:3000/test-db` to check if the backend can connect to MySQL.

### Docker
```bash
cp .env.example .env
```
```bash
sudo docker compose up -d --build
sudo docker compose logs -f
```

### Login
- User: varun
- Password: varun123
```
http://localhost:3039
```

### sql 
```bash
AND LTRIM(RTRIM(SerialNo)) NOT IN (${ignoreSrSql})
```
