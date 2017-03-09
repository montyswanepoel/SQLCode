use [master];
go


set nocount on;

declare @dbid int;
declare @objectid int;
declare @indexid int;
declare @rowid int;
declare @sql nvarchar(max);
declare @temp table
(
    [rowid] int not null identity primary key clustered,
    [databaseid] int not null,
    [objectid] int not null,
    [indexid] int not null,
    [userseeks] bigint not null,
    [userscans] bigint not null,
    [userlookups] bigint not null,
    [userupdates] bigint not null,
    [lastuserupdate] datetime null,
    [lastuserseek] datetime null,
    [lastuserscan] datetime null,
    [lastuserlookup] datetime null
);
declare @indexes table
(
    rowid int not null identity primary key clustered,
    dbname sysname not null,
    tablename sysname not null,
    indexname sysname not null,
    databaseid int not null,
    objectid int not null,
    indexid int not null
);

insert into @temp
select top 10
    [database_id],
    [object_id],
    [index_id],
    [user_seeks],
    [user_scans],
    [user_lookups],
    [user_updates],
    [last_user_update],
    [last_user_seek],
    [last_user_scan],
    [last_user_lookup]
from
    sys.dm_db_index_usage_stats
where
    [user_updates] > 10 * ([user_seeks] + [user_scans]) 
and [index_id] > 1
and database_id not in (1, 2, 3, 4)
order by
    [user_updates] / ([user_seeks] + [user_scans] + 1) desc;

--select * from @temp;

select
    @dbid = databaseid,
    @objectid = objectid,
    @indexid = indexid,
    @rowid = rowid
from
    @temp
where
    rowid = 1
    
while @@rowcount <> 0 begin

    set @sql =  N'use [' + db_name(@dbid) + N']; select db_name(' + cast(@dbid as  nvarchar(10)) + '), o.[name], i.[name], @dbid, @objectid, @indexid from sys.sysindexes i
    inner join sys.sysobjects as o on (i.[id] = o.[id])
    where o.id = ' + cast(@objectid as nvarchar(10)) + N' and i.indid = ' + cast(@indexid as nvarchar(10))
    
    insert into @indexes
    exec master.sys.sp_executesql @stmt = @sql, @params = N'@dbid int, @objectid int, @indexid int',
    @dbid = @dbid, @objectid = @objectid, @indexid = @indexid;

    select top 1
        @dbid = databaseid,
        @objectid = objectid,
        @indexid = indexid,
        @rowid = rowid
    from
        @temp
    where
        rowid > @rowid
end

select
	i.dbname as [DBName],
	i.tablename as [TableName],
	i.indexname as [IndexName],
	t.userupdates as [Updates],
	t.lastuserupdate as [LastUpdate],
	t.userseeks as [Seeks],
	t.userscans as [Scans],
	t.userlookups as [Lookups],
	t.lastuserseek as [LastSeek],
	t.lastuserscan as [LastScan],
	t.lastuserlookup as [LastLookup]
from
	@indexes as i
inner join
	@temp as t on ( t.[databaseid] = i.[databaseid]
				and t.[objectid] = i.[objectid]
				and t.[indexid] = i.[indexid]);
go


-- CHECK SERVER UPTIME

declare @crdate datetime, @hr varchar(50), @min varchar(5), @print nvarchar(max)
select @crdate = crdate
from sys.sysdatabases where name=N'tempdb'

set @hr = (datediff(mi, @crdate, getdate())) / 60
if @hr = 0
    set @min = (datediff (mi, @crdate, getdate()))
else
    set @min = (datediff (mi, @crdate, getdate())) - ((datediff(mi, @crdate,getdate())) / 60) * 60
select @print = 'ServerName: ' + convert(varchar(20),serverproperty('servername')) + char(10) +
'ServerStartTime: ' + (select convert(varchar(30), @crdate, 121)) + char(10) + 'ServerUptime: ' + @hr + ' hours & '+ @min + ' minutes' 
print @print
    
go



--set nocount on
--declare @crdate datetime, @hr varchar(50), @min varchar(5)
--select @crdate=crdate from sys.sysdatabases where name='tempdb'
--print 'server start time: ' + convert(nvarchar(30), @crdate, 121)
--select @hr=(datediff ( mi, @crdate,getdate()))/60
--if ((datediff ( mi, @crdate,getdate()))/60)=0
--select @min=(datediff ( mi, @crdate,getdate()))
--else
--select @min=(datediff ( mi, @crdate,getdate()))-((datediff( mi, @crdate,getdate()))/60)*60
--print 'sql server "' + convert(varchar(20),serverproperty('servername'))+'" is online for the past '+@hr+' hours & '+@min+' minutes'
--if not exists (select 1 from master.dbo.sysprocesses where program_name = N'sqlagent - generic refresher')
--begin
--print 'sql server is running but sql server agent <<not>> running'
--end
--else begin
--print 'both sql server and sql server agent are running'
--end
