Declare @Index varchar(128)
Declare @Table varchar(128)
Select SysIndexes.Name As 'Index',SysObjects.Name As 'Table'
Into #Indexes
From SysIndexes
Inner Join SysObjects On SysObjects.id = SysIndexes.id 
Where SysIndexes.Name Is Not Null
and SysObjects.XType = 'U'
Order By SysIndexes.Name,
SysObjects.Name

While (Select Count(*) From #Indexes) > 0
Begin        
Set @Index = (Select Top 1 [Index] From #Indexes)        
Set @Table = (Select Top 1 [Table] From #Indexes)        
Exec ('Drop Index [' + @Index + '] On [' + @Table + ']')        
print ('Drop Index [' + @Index + '] On [' + @Table + ']')        
Delete From #Indexes Where [Index] = @Index and [Table] = @Table
End
Drop Table #Indexes