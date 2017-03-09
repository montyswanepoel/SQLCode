DECLARE @DisableString NVARCHAR(1000), @RebuildString NVARCHAR(1000), @TableName VARCHAR(100)

SELECT @DisableString = '', @RebuildString = '', @TableName = 'dbo.DimCustomerType'

SELECT @DisableString = @DisableString + 'ALTER INDEX [' + si.name + '] ON ' + ss.name + '.[' + so.name + '] DISABLE;' FROM sys.indexes si INNER JOIN sys.objects so ON si.object_id = so.object_id INNER JOIN sys.schemas ss ON so.schema_id = ss.schema_id WHERE so.name = @TableName
SELECT @RebuildString = @RebuildString + 'ALTER INDEX [' + si.name + '] ON ' + ss.name + '.[' + so.name + '] REBUILD;' FROM sys.indexes si INNER JOIN sys.objects so ON si.object_id = so.object_id INNER JOIN sys.schemas ss ON so.schema_id = ss.schema_id WHERE so.name = @TableName

--Disable indexes--

EXEC sp_executesql @DisableString

--Rebuild indexes--

EXEC sp_executesql @RebuildString
