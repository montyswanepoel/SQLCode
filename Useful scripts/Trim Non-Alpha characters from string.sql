--Select dbo.fnTrimNonAlphaCharacters('2131231Atif123123 234234Sheikh6546')

set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go 

--Select dbo.fnTrimNonAlphaCharacters('2131231Atif123123 234234Sheikh6546')
CREATE FUNCTION [dbo].[fnTrimNonAlphaCharacters]
(
 @pString varchar(max)
)
RETURNS varchar(max)
AS
BEGIN
 Declare @vRetString varchar(max)
 Set @vRetString = ''

 ;with
 wcte as (


 Select Top(len(@pString)) * 
 from (Select row_number() over (order by a.object_id) N
 from sys.columns a, sys.columns b
 ) Main
 )SELECT @vRetString = @vRetString + SUBSTRING(@pString,N,1)
 FROM wcte a 
 WHERE N <= LEN(@pString) 
 And (Ascii(SUBSTRING(@pString,N,1)) between 97 and 122
 Or Ascii(SUBSTRING(@pString,N,1)) between 65 and 90
 Or Ascii(SUBSTRING(@pString,N,1)) = 32)
 ORDER BY N


 Return @vRetString

END

