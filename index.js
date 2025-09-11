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
            // .query('SELECT 1 FROM ItemSerialNo s WHERE s.VchType = 9 AND LTRIM(RTRIM(s.SerialNo)) = LTRIM(RTRIM(i.SerialNo))');
            .query(`WITH ParentGroupCTE AS (
            SELECT 
                Code, 
                Name, 
                ParentGrp,
                CASE 
                    WHEN ParentGrp = 0 THEN Name
                    ELSE (SELECT TOP 1 NameAlias 
                          FROM Help1 
                          WHERE NameOrAlias = 1 
                            AND Code = ParentGrp)
                END AS PGROP,
                COALESCE(
                    (SELECT TOP 1 NameAlias 
                     FROM Help1 
                     WHERE NameOrAlias = 1 
                       AND Code = CM1),
                    CASE 
                        WHEN ParentGrp = 0 THEN Name
                        ELSE (SELECT TOP 1 NameAlias 
                              FROM Help1 
                              WHERE NameOrAlias = 1 
                                AND Code = ParentGrp)
                    END
                ) AS BGROP
            FROM Master1
            WHERE MasterType = 5
        ),
        ItemData AS (
            SELECT
                LTRIM(RTRIM(SerialNo)) AS CleanSerialNo,
                (SELECT Name FROM Master1 WHERE Code = ItemCode) AS ITEMNAME, 
                (SELECT Name FROM Master1 WHERE Code = MCCode) AS Series,
                (SELECT Name FROM Master1 WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS GROP,
                (SELECT PGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS PGROP,
                (SELECT BGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS BGROP,
                Date,
                VchType,
                Value1 AS MainQty,   -- ? MainQty include
                -- Short name
                CASE VchType
                    WHEN 1  THEN 'Prev'
                    WHEN 2  THEN 'Pur'
                    WHEN 3  THEN 'Ret'
                    WHEN 5  THEN 'Trf'
                    WHEN 8  THEN 'Jrn'
                    WHEN 9  THEN 'Sal'
                    WHEN 10 THEN 'PRet'
                END AS LifeCyclePhaseShort,
                -- Full name
                CASE VchType
                    WHEN 1 THEN 'transfer from PreviousYears stock'
                    WHEN 2 THEN 'Purchased this year'
                    WHEN 3 THEN 'came from SalesReturn'
                    WHEN 5 THEN 'Stock Transfered from one godown to another'
                    WHEN 8 THEN 'StockJournal replace from service center (but serial number might changed)'
                    WHEN 9 THEN 'Sale this year'
                    WHEN 10 THEN 'return to whome, we purchased'
                END AS LifeCyclePhaseFull
            FROM ItemSerialNo
        ),
        Numbered AS (
            SELECT 
                d.CleanSerialNo,
                d.ITEMNAME,
                d.Series,
                d.GROP,
                d.PGROP,
                d.BGROP,
                d.Date,
                d.VchType,
                d.MainQty,
                d.LifeCyclePhaseShort,
                d.LifeCyclePhaseFull,
                ROW_NUMBER() OVER (PARTITION BY d.CleanSerialNo ORDER BY d.Date) AS PhaseNo,
                ROW_NUMBER() OVER (PARTITION BY d.CleanSerialNo ORDER BY d.Date DESC) AS ReversePhaseNo
            FROM ItemData d
        ),
        FinalStatus AS (
            SELECT 
                CleanSerialNo,
                SUM(
                    CASE 
                        WHEN VchType IN (1,2,3) THEN 1      -- Prev, Pur, Ret ? always add
                        WHEN VchType = 8 AND MainQty = 1 THEN 1  -- Jrn +1 ? add
                        WHEN VchType = 8 AND MainQty = -1 THEN -1 -- Jrn -1 ? minus
                        WHEN VchType = 9 AND MainQty = -1 THEN -1 -- Sale -1 ? minus
                        WHEN VchType = 9 AND MainQty = 1 THEN 1 -- Sale -1 ? minus
                        WHEN VchType IN (10) THEN -1     -- Sale, PRet ? minus
                        ELSE 0
                    END
                ) AS NetStock,   -- ? net stock calculation
                MAX(CASE WHEN PhaseNo = 1 THEN VchType END) AS FirstVchType,
                MAX(CASE WHEN PhaseNo = 1 THEN Date END) AS FirstDate
            FROM Numbered
            GROUP BY CleanSerialNo
        ),
        PerDayFlags AS (
            SELECT 
                CleanSerialNo,
                Date,
                MAX(CASE WHEN VchType IN (1,2) THEN 1 ELSE 0 END) AS HasPurchaseOrPrev,
                MAX(CASE WHEN VchType = 9 THEN 1 ELSE 0 END) AS HasSale
            FROM Numbered
            GROUP BY CleanSerialNo, Date
        ),
        SameDayExists AS (
            SELECT 
                CleanSerialNo,
                MAX(CASE WHEN HasPurchaseOrPrev = 1 AND HasSale = 1 THEN 1 ELSE 0 END) AS HasSameDayPurchaseAndSale
            FROM PerDayFlags
            GROUP BY CleanSerialNo
        )
        SELECT 
            n.CleanSerialNo AS SerialNo,
            MAX(n.ITEMNAME) AS ITEMNAME,
            MAX(n.Series) AS Series,
            MAX(n.GROP) AS GROP,
            MAX(n.PGROP) AS PGROP,
            MAX(n.BGROP) AS BGROP,
            MIN(n.Date) AS StartDate,
            COUNT(n.PhaseNo) AS PhaseCount,
            -- Short LifecycleStory
            STRING_AGG(
                CONVERT(VARCHAR(10), n.Date, 120) + ': ' + n.LifeCyclePhaseShort,
                CHAR(13) + CHAR(10)
            ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStoryShort,
            -- Full LifecycleStory
            STRING_AGG(
                CONVERT(VARCHAR(10), n.Date, 120) + ': ' + n.LifeCyclePhaseFull,
                CHAR(13) + CHAR(10)
            ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStoryFull,
            CASE 
                WHEN f.NetStock > 0 THEN 'In Stock'
                ELSE 'Not in Stock'
            END AS CurrentStock,   -- ? Net stock ?? final status
            CASE 
                WHEN f.FirstVchType IN (1,2) THEN 'No'
                WHEN s.HasSameDayPurchaseAndSale = 1 THEN 'No'
                ELSE 'Yes'
            END AS Suspected
        FROM Numbered n
        JOIN FinalStatus f ON n.CleanSerialNo = f.CleanSerialNo
        LEFT JOIN SameDayExists s ON n.CleanSerialNo = s.CleanSerialNo
        GROUP BY n.CleanSerialNo, f.NetStock, f.FirstVchType, s.HasSameDayPurchaseAndSale
        ORDER BY n.CleanSerialNo`);
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
