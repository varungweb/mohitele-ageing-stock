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
        CASE VchType
            WHEN 1 THEN 'transfer from PreviousYears stock'
            WHEN 2 THEN 'Purchased this year'
            WHEN 3 THEN 'came from SalesReturn'
            WHEN 5 THEN 'Stock Transfered from one godown to another'
            WHEN 8 THEN 'StockJournal replace from service center(but serial number might changed)'
            WHEN 9 THEN 'Sale this year'
            WHEN 10 THEN 'return to whome, we purchased'
        END AS LifeCyclePhase
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
        d.LifeCyclePhase,
        ROW_NUMBER() OVER (PARTITION BY d.CleanSerialNo ORDER BY d.Date) AS PhaseNo,
        ROW_NUMBER() OVER (PARTITION BY d.CleanSerialNo ORDER BY d.Date DESC) AS ReversePhaseNo
    FROM ItemData d
),
FinalStatus AS (
    SELECT 
        CleanSerialNo,
        MAX(CASE WHEN ReversePhaseNo = 1 THEN LifeCyclePhase END) AS LastPhase,
        MAX(CASE WHEN ReversePhaseNo = 1 THEN VchType END) AS LastVchType
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
    COUNT(n.PhaseNo) AS PhaseCount,   
    STRING_AGG(
        CAST(n.PhaseNo AS VARCHAR(10)) + '. ' 
        + n.LifeCyclePhase + ' on ' + CONVERT(VARCHAR(10), n.Date, 120),
        CHAR(10)
    ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStory,
    CASE 
        WHEN f.LastVchType IN (9, 10) THEN 'Not in Stock'
        ELSE 'In Stock'
    END AS CurrentStock   -- ✅ New column
FROM Numbered n
JOIN FinalStatus f ON n.CleanSerialNo = f.CleanSerialNo
GROUP BY n.CleanSerialNo, f.LastVchType;
