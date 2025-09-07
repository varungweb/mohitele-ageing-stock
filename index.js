const express = require('express');
const { sql, pool, poolConnect } = require('./db');

const app = express();
const PORT = 3000;

app.get('/api/stock-ageing', async (req, res) => {
    try {
        const pool = await require('./db').connectDB();
        const sql = require('./db').sql;
        // Read ignoreSr.txt and prepare comma-separated values for SQL NOT IN clause
        let ignoreSrList = [];
        if (fs.existsSync(ignoreSrPath)) {
            const fileContent = fs.readFileSync(ignoreSrPath, 'utf-8');
            ignoreSrList = fileContent
            .split(/\r?\n/)
            .map(line => line.trim())
            .filter(line => line.length > 0)
            .map(sr => `'${sr.replace(/'/g, "''")}'`);
        }
        const ignoreSrSql = ignoreSrList.length ? ignoreSrList.join(',') : "''";

        const result = await pool
            .request()
            .input("id", sql.Int, 1)
            .query(`WITH ParentGroupCTE AS (
        SELECT 
        Code, 
        Name, 
        ParentGrp,
        -- PGROP logic
        CASE 
            WHEN ParentGrp = 0 THEN Name
            ELSE 
            (SELECT TOP 1 NameAlias 
             FROM Help1 
             WHERE NameOrAlias = 1 
               AND Code = ParentGrp)
        END AS PGROP,
        -- BGROP logic
        COALESCE(
            (SELECT TOP 1 NameAlias 
             FROM Help1 
             WHERE NameOrAlias = 1 
               AND Code = CM1),
            CASE 
            WHEN ParentGrp = 0 THEN Name
            ELSE 
                (SELECT TOP 1 NameAlias 
                 FROM Help1 
                 WHERE NameOrAlias = 1 
                   AND Code = ParentGrp)
            END
        ) AS BGROP
        FROM Master1
        WHERE MasterType = 5
    )

    SELECT
    ROW_NUMBER() OVER (ORDER BY VchType, VchNo) AS SerialNumber,
        (SELECT Name FROM Master1 WHERE Code = ItemCode) AS ITEMNAME, 
        (SELECT Name FROM Master1 WHERE Code = MCCode) AS Series,
        (SELECT Name FROM Master1 WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS GROP,
        (SELECT PGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS PGROP,
        (SELECT BGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS BGROP,VchType,
        CASE VchType
        WHEN 1 THEN 'PreviousYears'
        WHEN 2 THEN 'PurchaseOnly'
        WHEN 3 THEN 'SalesReturn'
        WHEN 5 THEN 'StockTransfer'
        WHEN 8 THEN 'StockJournal'
        WHEN 9 THEN 'SaleOnly'
        WHEN 10 THEN 'PurchaseReturn'
        ELSE CAST(VchType AS VARCHAR)
        END AS VchTypeName,
        Value1 AS MainQty, 
        Value2 AS AltQty, 
        LTRIM(RTRIM(SerialNo)) As SerialNo,
        Date,
        VchNo,
        VchCode,
        VchItemSN,
        GridSN,
        D1,
        MonthVal
    FROM 
        ItemSerialNo 
    WHERE 
        VchType IN (1) 
        AND LTRIM(RTRIM(SerialNo)) NOT IN (${ignoreSrSql})
    ORDER BY 
        VchType
    `);
        res.json(result.recordset);
    } catch (err) {
        console.error("Query error: ", err);
        res.status(500).json({ error: err.message });
    }
});

const path = require('path');
const fs = require('fs');
const ignoreSrPath = require('path').join(__dirname, 'ignoreSr.txt');
app.use(express.static(path.join(__dirname, 'frontend')));

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Frontend available at http://localhost:${PORT}/index.html`);
});
