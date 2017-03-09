USE master
GO
EXEC sp_detach_db @dbname=N'yourDB';
GO

--Step 4: However you want, copy the actual yourDB_log.ldf file to whatever location you want. Say for this example, we'll move it to the root of the D drive.

--Step 5: Attach your database, and specify the new file locations.

USE master
GO
EXEC sp_attach_db @dbname = N'yourDB',
@filename1 = N'C:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\Data\yourDB_Data.mdf',
@filename2 = N'D:\yourDB_log.ldf'; 
GO