-- Number of specific Characters
Declare @aa varchar(100)
Set @aa = 'SQL Server 2005000'
Select Len(@aa) - Len(Replace(@aa, '0', ''))

-- Number of Words 
DECLARE @String VARCHAR(4000)
SELECT @String = 'SQL Server 2005 Atif Sheikh A'

while CharIndex(' ',@String) > 1
begin
Set @String = REPLACE(@String, ' ', ' ')
end
Select @String
SELECT LEN(@String) - LEN(REPLACE(@String, ' ', '')) + 1
