2-9+

purchaseOnly-saleOnly + saleReturn - purchaseReturn

StockJournal, StockTransfer

10
,9,8,5,3,2,1


CurrentStock =
-------------------
+ purchaseOnly

+ StockTransfer(+1)
+ StockJournal(+1)
+ saleReturn

- saleOnly
- purchaseReturn
- StockJournal(-1)
- StockTransfer(-1)




STOCKTRANSFER(5) = 1090 (479)
STOCKJOURNAL(8) = 14


ALL = 6992
DISTINCT = 3637
PURCHASEONLY(2) = 2722 (2721)
SALERETURN(3) = 12
STOCKTRANSFER(5)(+1) = 545(479)
STOCKJOURNAL(8)(+1) = 7
SALEONLY(9) = 3091 (3061)
PURCHASERETURN(10) = 63

STOCKTRANSFER(5)(-1) = 545(479)
STOCKJOURNAL(8)(-1) = 7


CurrentStock = 2+5+8+3 - 9 - 10 - 8(-1) - 5(-1)


2721 + 545 + 7 + 12 - 3091 - 63 - 7 - 545

1001 + 2721 + 12 - 3091 - 63 = 580 - x




