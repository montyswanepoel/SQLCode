Select Top 10 mid.database_id, mid.object_id, mid.statement as table_name, mig.index_handle as index_handle
      from 
      (
      select 
      (user_seeks+user_scans) * avg_total_user_cost * (avg_user_impact * 0.01) as index_advantage, migs.*
      from sys.dm_db_missing_index_group_stats migs
      ) as migs_adv,
      sys.dm_db_missing_index_groups mig,
      sys.dm_db_missing_index_details mid
      where
      migs_adv.group_handle = mig.index_group_handle and
      mig.index_handle = mid.index_handle
      order by migs_adv.index_advantage DESC

--Please use to find the columns that should be included in the indexes.



--we can run queries like 

SELECT * FROM sys.dm_db_missing_index_details where index_handle = 555 

--to find the columns on which we need to create the indexes.