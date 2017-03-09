SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:        <Luigi Marinescu and Michael Ciurescu>
-- Create date: <20091104>
-- Description:   <Split string into table, separator can be more than 1 char>
-- =============================================
CREATE FUNCTION [dbo].[fn_SplitStringToTable]
(
        @DataList NVARCHAR(MAX)
      , @Separator NVARCHAR(MAX)
)
RETURNS @ret TABLE 
(
	RowIndex INT
	, FromPos INT
	, ToPos INT
	, ItemData NVARCHAR(MAX)
)
AS
BEGIN
	DECLARE @LenSep INT
	SET @LenSep = LEN(@Separator)
-- SELECT * FROM dbo.fn_SplitStringToTable('123,43,5465,6788,1231,111', ',')
	; WITH res (RowIndex, FromPos, ToPos) AS (
		SELECT CAST(1 AS INT) AS RowIndex
			  , CAST(1 AS INT) AS FromPos
			  , CAST(CHARINDEX(@Separator, @DataList + @Separator) AS INT) AS ToPos
	    
		UNION ALL
	    
		SELECT CAST(RowIndex + 1 AS INT) AS RowIndex
			  , CAST(res.ToPos + @LenSep AS INT) AS FromPos
			  , CAST(CHARINDEX(@Separator, @DataList + @Separator, ToPos + @LenSep) AS INT) AS ToPos
		FROM res
		WHERE CHARINDEX(@Separator, @DataList + @Separator, ToPos + @LenSep) > 0
	)
	INSERT INTO @ret
	SELECT res.*, SUBSTRING(@DataList, FromPos, ToPos - FromPos) AS ItemData
	FROM res
	
	RETURN 
END

