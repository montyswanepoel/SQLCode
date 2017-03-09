create view [dbo].[vw_index_usage] 
as
 with CTE(tablename, indexname, indextype, indexusage, filegroupname, MB, cols, included, user_hits, user_seeks, user_scans
 , user_lookups, user_updates, stats_date, SQLCmd)
 as
 (
  select object_name(a.object_id) "tablename"
  , c.name "indexname"
  , c.type_desc "indextype"
  , case c.is_unique 
     when 1 then 
      case is_primary_key 
 when 1 then 
 'Primary Key' 
 else
 'Unique' 
 end 
 else 
 case c.is_unique_constraint 
 when 1 then 
 'Unique Constraint' 
 else
 'Performance'
 end 
 end "IndexUsage"
 , FILEGROUP_NAME(c.data_space_id) "FileGroupName"
 , (select ceiling(used/128) from sysindexes b where b.name=c.name and c.index_id = b.indid and b.[id]=c.[object_id]) "MB"
 , (select count(*) from sys.index_columns d where a.object_id = d.object_id and a.index_id = d.index_id and d.is_included_column = 0) "cols"
 , (select count(*) from sys.index_columns d where a.object_id = d.object_id and a.index_id = d.index_id and d.is_included_column = 1) "included"
 , (a.user_seeks + a.user_scans + a.user_lookups) "user_hits"
 , a.user_seeks
 , a.user_scans
 , a.user_lookups
 , a.user_updates 
 , a.last_user_update "stats_date"
 , case 
 when is_unique_constraint = 0 and is_unique = 0 and is_primary_key = 0 
 then 'alter index [' + c.name + '] on [' + object_name(a.object_id) + '] disable;' 
 end "SQLCmd"
 from sys.dm_db_index_usage_stats a
 join sys.indexes as c
 on a.object_id = c.object_id 
 and a.index_id = c.index_id
 where a.object_id > 1000 -- exclude system tables
 and c.type <> 0 -- exclude HEAPs
 and c.is_disabled = 0 -- only active indexes
 and a.database_id = DB_ID() -- for current database only
 )
 select tablename
 , indexname
 , indextype
 , indexusage
 , filegroupname
 , MB
 , cols
 , included
 , round(cast(user_seeks as real) / coalesce(nullif(user_hits,0),1) * 100,0) as "perc_seeks"
 , round(cast(user_scans as real) / coalesce(nullif(user_hits,0),1) * 100,0) as "perc_scans"
 , round(cast(user_lookups as real) / coalesce(nullif(user_hits,0),1) * 100,0) as "perc_lookups"
 , user_hits
 , user_updates
 , case 
 when user_hits = 0 
 then - user_updates
 else round(cast(user_seeks + user_scans*.8 + user_lookups*1.2 AS REAL) / cast(coalesce(nullif(user_updates,0),1) as REAL), 4)
 end "ratio"
 , (user_updates - user_hits) / COALESCE(NULLIF(MB,0),1) as "pressure"
 , stats_date
 , SQLCmd
 from cte
go






