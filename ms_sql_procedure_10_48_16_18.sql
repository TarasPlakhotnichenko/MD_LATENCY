USE [interqort]
GO
/****** Object:  StoredProcedure [dbo].[ReturnBidOffer]    Script Date: 12/13/2012 18:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[ReturnBidOffer] 	
	@SecCode nvarchar(100),
	@Class nvarchar(100),
	@tbl int = 41
as 
begin      
      
    if (@tbl = 41)
		begin
			Select ClassCode,SecCode,bid,offer,[last],TradeDate,changetime
			FROM [QuikExport].[dbo].[Params_41]
			where SecCode =	@SecCode
				and TradeDate = convert(nvarchar(8),GETDATE(),112)
				and ClassCode = @Class
		end
		
	else
		if (@tbl = 73)
		begin
			Select ClassCode,SecCode,bid,offer,[last],TradeDate,changetime     
			FROM [QuikExport].[dbo].[Params_73]
			where SecCode =	@SecCode
				and TradeDate = convert(nvarchar(8),GETDATE(),112)
				and ClassCode = @Class
		end		
		else
			begin
				Select ClassCode,SecCode,bid,offer,[last],TradeDate,changetime     
				FROM [QuikExport].[dbo].[Params_47]
				where SecCode =	@SecCode
					and TradeDate = convert(nvarchar(8),GETDATE(),112)
					and ClassCode = @Class
			end


	

/*		
	Select ClassCode,SecCode,bid,offer,TradeDate ,*     
	FROM [QuikExport].[dbo].[Params_47]
	where SecCode =	'RIU2' and TradeDate = '20120815'
*/


end;

/*


exec [dbo].[ReturnBidOffer] 'RIU2','SPBFUT'
exec [dbo].[ReturnBidOffer] 'RIU2','SPBFUT', 47
exec [dbo].[ReturnBidOffer] 'US80585Y3080','LSE_MDIOB', 73
exec [dbo].[ReturnBidOffer] 'US3682872078','LSE_IOB', 73


**/
