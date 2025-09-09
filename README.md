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
```bash
select * from ItemSerialNo 
CASE VchType WHEN 1 THEN 'PreviousYears' (1 only) 
WHEN 2 THEN 'PurchaseOnly' (1 only) 
WHEN 3 THEN 'SalesReturn' (1 only) 
WHEN 5 THEN 'StockTransfer' (both -1 and 1) 
WHEN 8 THEN 'StockJournal' (both -1 and 1) 
WHEN 9 THEN 'SaleOnly' (both -1 and 1) 
WHEN 10 THEN 'PurchaseReturn' (-1 only) 
in braces 1 and -1 means value1 which can be 1 or -1 
but here is catch 
if sale with 1 is also SalesReturn, 
provide sql to check count of each
```
