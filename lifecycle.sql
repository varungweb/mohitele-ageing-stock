WITH ParentGroupCTE AS (
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
),
ItemData AS (
    SELECT
        SerialNo,
        ROW_NUMBER() OVER (ORDER BY VchType, VchNo) AS SerialNumber,
        (SELECT Name FROM Master1 WHERE Code = ItemCode) AS ITEMNAME, 
        (SELECT Name FROM Master1 WHERE Code = MCCode) AS Series,
        (SELECT Name FROM Master1 WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS GROP,
        (SELECT PGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS PGROP,
        (SELECT BGROP FROM ParentGroupCTE WHERE Code = (SELECT ParentGrp FROM Master1 WHERE Code = ItemCode)) AS BGROP,
        VchType,
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
        LTRIM(RTRIM(SerialNo)) As CleanSerialNo,
        Date,
        VchNo,
        VchCode,
        VchItemSN,
        GridSN,
        D1,
        MonthVal,
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
)
SELECT 
    i.SerialNumber,
    i.ITEMNAME,
    i.Series,
    i.GROP,
    i.PGROP,
    i.BGROP,
    i.VchType,
    i.VchTypeName,
    i.MainQty,
    i.AltQty,
    i.CleanSerialNo AS SerialNo,
    i.Date,
    i.VchNo,
    i.VchCode,
    i.VchItemSN,
    i.GridSN,
    i.D1,
    i.MonthVal,
    -- full lifecycle in one column
    lc.FullLifeCycle
FROM ItemData i
OUTER APPLY (
    SELECT STRING_AGG(LifeCyclePhase, ' -> ') 
    FROM ItemData d 
    WHERE d.CleanSerialNo = i.CleanSerialNo
) lc(FullLifeCycle)
