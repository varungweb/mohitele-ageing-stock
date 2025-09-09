SELECT 
    CASE 
        WHEN VchType = 1 AND Value1 = 1 THEN 'PreviousYears'
        WHEN VchType = 2 AND Value1 = 1 THEN 'PurchaseOnly'
        WHEN VchType = 3 AND Value1 = 1 THEN 'SalesReturn'
        WHEN VchType = 5 AND Value1 IN (-1, 1) THEN 'StockTransfer'
        WHEN VchType = 8 AND Value1 IN (-1, 1) THEN 'StockJournal'
        WHEN VchType = 9 AND Value1 = -1 THEN 'SaleOnly(-1)'
        WHEN VchType = 9 AND Value1 = 1 THEN 'SaleOnly(+1)_AlsoSalesReturn'
        WHEN VchType = 10 AND Value1 = -1 THEN 'PurchaseReturn'
        ELSE 'Other'
    END AS Category,
    COUNT(*) AS RecordCount,
    SUM(Value1) AS NetQty
FROM ItemSerialNo
GROUP BY 
    CASE 
        WHEN VchType = 1 AND Value1 = 1 THEN 'PreviousYears'
        WHEN VchType = 2 AND Value1 = 1 THEN 'PurchaseOnly'
        WHEN VchType = 3 AND Value1 = 1 THEN 'SalesReturn'
        WHEN VchType = 5 AND Value1 IN (-1, 1) THEN 'StockTransfer'
        WHEN VchType = 8 AND Value1 IN (-1, 1) THEN 'StockJournal'
        WHEN VchType = 9 AND Value1 = -1 THEN 'SaleOnly(-1)'
        WHEN VchType = 9 AND Value1 = 1 THEN 'SaleOnly(+1)_AlsoSalesReturn'
        WHEN VchType = 10 AND Value1 = -1 THEN 'PurchaseReturn'
        ELSE 'Other'
    END
ORDER BY Category;
