WITH ParentGroupCTE AS (
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
        Value1 AS MainQty,

        -- Short Phase
        CASE 
            WHEN VchType = 9 AND Value1 = -1 THEN 'Sal(-1)'
            WHEN VchType = 9 AND Value1 = 1  THEN 'Sal(+1)'
            WHEN VchType = 8 AND Value1 = -1 THEN 'Jrn(-1)'
            WHEN VchType = 8 AND Value1 = 1  THEN 'Jrn(+1)'
            WHEN VchType = 1 THEN 'Prev'
            WHEN VchType = 2 THEN 'Pur'
            WHEN VchType = 3 THEN 'Ret'
            WHEN VchType = 5 THEN 'Trf'
            WHEN VchType = 10 THEN 'PRet'
        END AS LifeCyclePhaseShort,

        -- Full Phase
        CASE 
            WHEN VchType = 9 AND Value1 = -1 THEN 'Sale this year (outflow)'
            WHEN VchType = 9 AND Value1 = 1  THEN 'Sale Return / reversed sale (inflow)'
            WHEN VchType = 8 AND Value1 = -1 THEN 'StockJournal sent to service center (outflow)'
            WHEN VchType = 8 AND Value1 = 1  THEN 'StockJournal received back from service center (inflow)'
            WHEN VchType = 1 THEN 'transfer from PreviousYears stock'
            WHEN VchType = 2 THEN 'Purchased this year'
            WHEN VchType = 3 THEN 'came from SalesReturn'
            WHEN VchType = 5 THEN 'Stock Transfered from one godown to another'
            WHEN VchType = 10 THEN 'return to whome, we purchased'
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
        SUM(MainQty) AS NetStock,
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
),
SaleCheck AS (
    SELECT 
        CleanSerialNo,
        MAX(CASE WHEN VchType = 9 AND MainQty = -1 THEN 1 ELSE 0 END) AS HasSale,
        MAX(CASE WHEN VchType = 10 THEN 1 ELSE 0 END) AS HasPurchaseReturn,
        MAX(CASE WHEN VchType = 8 THEN 1 ELSE 0 END) AS WentToJournal
    FROM Numbered
    GROUP BY CleanSerialNo
),
SaleAfterJournal AS (
    SELECT DISTINCT n1.CleanSerialNo
    FROM Numbered n1
    JOIN Numbered n2 
      ON n1.CleanSerialNo = n2.CleanSerialNo
     AND n2.VchType = 8              -- Journal entry exists
     AND n1.VchType = 9              -- Sale
     AND n1.MainQty = -1
     AND n1.Date > n2.Date           -- Sale happened AFTER Journal
),
PurchaseSaleDates AS (
    SELECT
        CleanSerialNo,
        MIN(CASE 
                WHEN VchType IN (1,2) THEN Date
                WHEN VchType = 3 THEN Date
                WHEN VchType = 9 AND MainQty <> -1 THEN Date
            END) AS FirstPurchaseDate,
        MAX(CASE WHEN VchType = 9 AND MainQty = -1 THEN Date END) AS LastSaleDate
    FROM Numbered
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
    DATEDIFF(DAY, MIN(n.Date), GETDATE()) AS DaysSinceStart,
    COUNT(n.PhaseNo) AS PhaseCount,
    STRING_AGG(
        CONVERT(VARCHAR(10), n.Date, 120) + ': ' + n.LifeCyclePhaseShort,
        CHAR(13) + CHAR(10)
    ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStoryShort,
    STRING_AGG(
        CONVERT(VARCHAR(10), n.Date, 120) + ': ' + n.LifeCyclePhaseFull,
        CHAR(13) + CHAR(10)
    ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStoryFull,
    CASE 
        WHEN f.NetStock > 0 
             AND n.CleanSerialNo IN (${ignoreSrSql}) 
        THEN 'Ignored'
        WHEN f.NetStock > 0 THEN 'In Stock'
        ELSE 'Not in Stock'
    END AS CurrentStock,
    CASE 
        WHEN f.FirstVchType IN (1,2) THEN 'No'
        WHEN s.HasSameDayPurchaseAndSale = 1 THEN 'No'
        ELSE 'Yes'
    END AS Suspected,
    CASE 
        WHEN sc.HasSale = 1 
             AND sc.HasPurchaseReturn = 0
             AND (sc.WentToJournal = 0 OR saj.CleanSerialNo IS NOT NULL)
        THEN 'Yes'
        ELSE 'No'
    END AS ActualSale,
    ps.FirstPurchaseDate,
    ps.LastSaleDate,
    CASE 
        WHEN ps.FirstPurchaseDate IS NOT NULL 
             AND ps.LastSaleDate IS NOT NULL 
        THEN DATEDIFF(DAY, ps.FirstPurchaseDate, ps.LastSaleDate)
        ELSE -9911457143
    END AS DaysPurchaseToSale
FROM Numbered n
JOIN FinalStatus f ON n.CleanSerialNo = f.CleanSerialNo
LEFT JOIN SameDayExists s ON n.CleanSerialNo = s.CleanSerialNo
LEFT JOIN SaleCheck sc ON n.CleanSerialNo = sc.CleanSerialNo
LEFT JOIN SaleAfterJournal saj ON n.CleanSerialNo = saj.CleanSerialNo
LEFT JOIN PurchaseSaleDates ps ON n.CleanSerialNo = ps.CleanSerialNo
GROUP BY n.CleanSerialNo, f.NetStock, f.FirstVchType, s.HasSameDayPurchaseAndSale,
         sc.HasSale, sc.HasPurchaseReturn, sc.WentToJournal, saj.CleanSerialNo,
         ps.FirstPurchaseDate, ps.LastSaleDate
ORDER BY n.CleanSerialNo
