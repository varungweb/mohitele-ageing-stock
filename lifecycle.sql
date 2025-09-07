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
        d.LifeCyclePhase,
        ROW_NUMBER() OVER (PARTITION BY d.CleanSerialNo ORDER BY d.Date) AS PhaseNo
    FROM ItemData d
)
SELECT 
    n.CleanSerialNo AS SerialNo,
    MAX(n.ITEMNAME) AS ITEMNAME,
    MAX(n.Series) AS Series,
    MAX(n.GROP) AS GROP,
    MAX(n.PGROP) AS PGROP,
    MAX(n.BGROP) AS BGROP,
    STRING_AGG(
        CAST(n.PhaseNo AS VARCHAR(10)) + '. ' 
        + n.LifeCyclePhase + ' on ' + CONVERT(VARCHAR(10), n.Date, 120),
        CHAR(10)
    ) WITHIN GROUP (ORDER BY n.PhaseNo) AS LifecycleStory
FROM Numbered n
GROUP BY n.CleanSerialNo
