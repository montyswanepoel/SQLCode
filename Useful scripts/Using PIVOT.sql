CREATE TABLE #Sales(BillNo varchar(10),SaleDate datetime,Store varchar(20),billAmt float)
INSERT INTO #Sales SELECT 'IN001','10/Jan/2010','Store1',100
INSERT INTO #Sales SELECT 'IN002','12/Jan/2010','Store1',100
INSERT INTO #Sales SELECT 'IN003','10/Jan/2010','Store1',125
INSERT INTO #Sales SELECT 'IN004','10/Jan/2010','Store2',100
INSERT INTO #Sales SELECT 'IN005','11/Jan/2010','Store1',100
INSERT INTO #Sales SELECT 'IN006','7/Jan/2010','Store3',100
INSERT INTO #Sales SELECT 'IN007','10/Jan/2010','Store3',100
INSERT INTO #Sales SELECT 'IN008','5/Jan/2010','Store1',100
INSERT INTO #Sales SELECT 'IN009','11/Jan/2010','Store1',100
INSERT INTO #Sales SELECT 'IN0010','7/Jan/2010','Store3',100

select SaleDate,Store,sum(billAmt) totalSale from #Sales group by SaleDate,Store

select SaleDate, [Store1] as 'Store1 Sale', [Store2] as 'Store2 Sale', [Store3] as 'Store3 Sale'

from
(
select * from #Sales
) salesdata
PIVOT
(
sum(billAmt)

for store in ([Store1],[Store2],[Store3]) )as xx
drop table #sales


