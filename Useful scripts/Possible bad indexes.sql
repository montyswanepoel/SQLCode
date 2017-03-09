-- Possible bad Indexes (writes > reads)
    DECLARE @dbid int
    SELECT @dbid = db_id()

    SELECT 'Table Name' = object_name(s.object_id), 'Index Name' =i.name, i.index_id,
           'Total Writes' =  user_updates, 'Total Reads' = user_seeks + user_scans + user_lookups,
            'Difference' = user_updates - (user_seeks + user_scans + user_lookups)
    FROM sys.dm_db_index_usage_stats AS s 
    INNER JOIN sys.indexes AS i
    ON s.object_id = i.object_id
    AND i.index_id = s.index_id
    WHERE objectproperty(s.object_id,'IsUserTable') = 1
    AND s.database_id = @dbid
    AND user_updates > (user_seeks + user_scans + user_lookups)
