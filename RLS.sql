/****** Script for SelectTopNRows command from SSMS  ******/
SELECT *, FullName
  FROM WideWorldImporters.Application.People ppl
  inner join 
  WideWorldImporters.sales.Orders ord
  on ppl.PersonID = ord.ContactPersonID
  --1. for all the employees in the [WideWorldImporters].[Application].[People]
  --   create a procedure to automaticly create for each worker:
  --   a  login for each employee
  --   user for each login
  --   create a predicate function that receives first name of employee and shows their orders
  --   create a security policy
use WideWorldImporters
go
--Create a new schema
--in the newly created schema, will create a function to hold the RLS filter
--best practice as based on application permission
IF NOT EXISTS ( SELECT  *
                FROM    sys.schemas
                WHERE   name = N'Security' ) 
    EXEC('CREATE SCHEMA [Security] AUTHORIZATION [dbo]');
GO
select user_name()
go
  --predicate function -> inline function that receives the userame and returns if to filter 
  --or not the order for the employee
  --reads each row from the table and decides.
--create FUNCTION Security.fn_securitypredicate(@Username AS varchar(50))
--    RETURNS TABLE
--	WITH SCHEMABINDING
--AS
--    RETURN
--		-- Return 1 if the connection username matches the @Username parameter
--		SELECT
--			1 AS fn_securitypredicate_result 
--		WHERE
--			DATABASE_PRINCIPAL_ID() = DATABASE_PRINCIPAL_ID(@Username)
--			or
--			DATABASE_PRINCIPAL_ID() = DATABASE_PRINCIPAL_ID('dbo');
--			--@Username = session_context (N'FullName')
--GO

create function Security.fn_securitypredicate(@SalespersonPersonID as int)
    returns table
with schemabinding
as
    return select 1 as result 
    where @SalespersonPersonID in (select PersonID  
								   from [Application].People ppl 
								   inner join 
								   sales.Orders ord
								   on ppl.PersonID = ord.SalespersonPersonID
								   where substring(ppl.FullName , 1, charindex(' ',ppl.FullName)) 
								   = user_name() or user_name() = 'dbo')

GO

-- Create and enable a security policy adding the function fn_securitypredicate 
-- as a filter predicate and switching it on
-- sends to the function only the first name (before the space)
CREATE SECURITY POLICY SalesPolicyFilter
	ADD FILTER PREDICATE Security.fn_securitypredicate(SalespersonPersonID) 
	ON Sales.orders
	WITH (STATE = ON);
go


--login cursor that loops through the whole WideWorldImporters.Application.People table 
--and creates a user for each employee
--or session context for each
create proc create_NewPeopleUser 
as
begin
		Declare @fullName varchar(20), @PersonID int, @stmtS nvarchar(4000),
				@firstName varchar(20), @stmtS1 nvarchar(4000), @stmtS2 nvarchar(4000)
		Declare Mycursor cursor
		for SELECT PersonID,FullName
		  FROM [Application].People 
		open Mycursor
		Fetch next from Mycursor into @PersonID, @fullName
		while @@FETCH_STATUS=0
		begin 
		Print cast(@PersonID as char(10))+' '+ @fullName
		set @firstName = (substring(@fullName , 1, charindex(' ',@fullName)))
		--creates a global variable 'FullName' to hold selected username
		--EXEC sp_set_session_context @key = N'FullName', @value = @fullName
			--CREATE LOGIN @newUsername WITH PASSWORD = @password; 
			set @stmtS = 'CREATE LOGIN ' + quotename(@firstName,']') +
						' with password = ''''
						, CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF ' 
			print @stmtS
			exec (@stmtS)

		--creates user from next employee in table
			select @stmtS1 = 'CREATE USER '
			select @stmtS1 = @stmtS1 +  quotename(@firstName,']')
			--select @stmtS1 = @stmtS1 + ' WITHOUT LOGIN'
			select @stmtS1 = @stmtS1 + ' FOR LOGIN '
			select @stmtS1 = @stmtS1 + quotename(@firstName,']')
			print @stmtS1
			exec (@stmtS1)

		--CREATE USER @fullName WITH LOGIN
			select @stmtS2 = 'GRANT SELECT ON Sales.Orders TO '
			select @stmtS2 = @stmtS2 +  quotename(@firstName,']')
			print @stmtS2
			exec (@stmtS2)
	
		--EXECUTE AS USER = @fullName	
			select @stmtS2 = 'EXECUTE AS USER =  '
			select @stmtS2 = @stmtS2 +  quotename(@firstName,']')
			print @stmtS2
			exec (@stmtS2)
		Fetch next from Mycursor into @PersonID, @fullName
		end 
		close Mycursor
		Deallocate Mycursor
end

exec create_NewPeopleUser

--TEST
--CREATE USER Archer WITHOUT LOGIN
--GRANT SELECT ON Sales.Orders TO Archer		
EXECUTE AS USER = 'Archer'								-- Run as Airi
select user_name()
select * from Sales.Orders
select * from Application.People
REVERT	
--drop USER Archer													-- Run as dbo
GO

--clean up
drop SECURITY POLICY SalesPolicyFilter
drop FUNCTION Security.fn_securitypredicate
drop proc create_NewPeopleUser 

--procedure to DROP the USERs 
exec drop_NewPeopleUser


create proc drop_NewPeopleUser 
as
begin
		Declare @fullName varchar(20), @PersonID int, 
				@firstName varchar(20), @stmtS1 nvarchar(4000), @stmtS2 nvarchar(4000)
		Declare Mycursor cursor
		for SELECT PersonID,FullName
		  FROM [Application].People 
		open Mycursor
		Fetch next from Mycursor into @PersonID, @fullName
		while @@FETCH_STATUS=0
		begin 
		Print cast(@PersonID as char(10))+' '+ @fullName
		set @firstName = (substring(@fullName , 1, charindex(' ',@fullName)))
		
		--drops users created from table
			select @stmtS1 = 'DROP USER '
			select @stmtS1 = @stmtS1 +  quotename(@firstName,']')
			print @stmtS1
			exec (@stmtS1)

		Fetch next from Mycursor into @PersonID, @fullName
		end 
		close Mycursor
		Deallocate Mycursor
end


--2. see excelForUserArcher excel file
--TEST
CREATE USER Archer WITHOUT LOGIN
GRANT SELECT ON Sales.Orders TO Archer		
EXECUTE AS USER = 'Archer'								-- Run as Airi
select user_name()
select * from Sales.Orders
select * from Application.People
REVERT	
drop USER Archer													-- Run as dbo
GO

--3.
--create a predicate function for each supplier:
--will create a dynamic sql function to filter rows by supplierid in suppliers table
--enter supplierid into session context and check in the function
--run a number of suppliers to test

select *
from Purchasing.Suppliers

  --predicate function -> inline function that receives the userame and returns if to filter 
  --or not the order for the employee
  --reads each row from the table and decides.
--create FUNCTION Security.fn_suppiler_predicate(@Username AS varchar(50))
--    RETURNS TABLE
--	WITH SCHEMABINDING
--AS
--    RETURN
--		-- Return 1 if the connection username matches the @Username parameter
--		SELECT
--			1 AS fn_suppiler_predicate_result 
--		WHERE
--			@Username = CAST(session_context (N'SupplierID')AS int);
--GO

-- Create and enable a security policy adding the function fn_securitypredicate 
-- as a filter predicate and switching it on
-- sends to the function only the first name (before the space)
--create SECURITY POLICY SupplierPolicyFilter
--	ADD FILTER PREDICATE Security.fn_suppiler_predicate(SupplierID) 
--	ON Purchasing.Suppliers
--	WITH (STATE = on);
--go

create proc create_NewSContext_Supp_predicate 
as
begin
		Declare @Statement nvarchar(4000), @SupplierID int
		Declare Mycursor insensitive cursor
		for SELECT SupplierID
		  FROM Purchasing.Suppliers
		open Mycursor
		Fetch next from Mycursor into @SupplierID
		while @@FETCH_STATUS=0
		begin 
		Print cast(@SupplierID as char(10))

		--create dynamic predicate function for @SupplierID with @SupplierID at end of name  
		set @Statement = '
				create FUNCTION Security.fn_suppiler_pred'+CAST(@SupplierID as NVARCHAR)+
														'(@SupplierID AS varchar(50))
				RETURNS TABLE
				WITH SCHEMABINDING
				AS
				RETURN
					-- Return 1 if the connection username matches the @Username parameter
					SELECT
						1 AS fn_suppiler_predicate_result 
					WHERE
						@SupplierID = CAST(session_context (N''SupplierID'')AS int);'
		print @Statement
		exec (@Statement)

		set @Statement = ''
		--create SECURITY POLICY function for new predicate function with @SupplierID at end of name  
		set @Statement = '
				create SECURITY POLICY SupplierPolicyFilter'+CAST(@SupplierID as NVARCHAR)+'
				ADD FILTER PREDICATE Security.fn_suppiler_pred'+CAST(@SupplierID as NVARCHAR)+'(SupplierID) 
				ON Purchasing.Suppliers
				WITH (STATE = on);'
		print @Statement
		exec (@Statement)
		--creates a global variable 'FullName' to hold selected username
		EXEC sp_set_session_context @key = N'SupplierID', @value = @SupplierID, @read_only = 0;
		--gets next value from cursor (next suppliers
		Fetch next from Mycursor into @SupplierID
		end 
		close Mycursor
		Deallocate Mycursor
end

exec create_NewSContext_Supp_predicate

--test
EXEC sp_set_session_context @key = N'SupplierID', @value = 3, @read_only = 0;

select session_context(N'SupplierID')
select *
from Purchasing.Suppliers


--procedure to drop new predicates and SECURITY POLICYs
create proc drop_NewSContext_Supp_predicate 
as
begin
		Declare @Statement nvarchar(4000), @SupplierID int
		Declare Mycursor cursor
		for SELECT SupplierID
		  FROM Purchasing.Suppliers
		open Mycursor
		Fetch next from Mycursor into @SupplierID
		while @@FETCH_STATUS=0
		begin 
		Print cast(@SupplierID as char(10))

		--drop SECURITY POLICY function for new predicate function with @SupplierID at end of name  
		set @Statement = '
				drop SECURITY POLICY SupplierPolicyFilter'+CAST(@SupplierID as NVARCHAR)
		print @Statement
		exec (@Statement)
		set @Statement = ''
		--create dynamic predicate function for @SupplierID with @SupplierID at end of name  
		set @Statement = '
				drop FUNCTION Security.fn_suppiler_pred'+CAST(@SupplierID as NVARCHAR)
		print @Statement
		exec (@Statement)

		--gets next value from cursor (next suppliers
		Fetch next from Mycursor into @SupplierID
		end 
		close Mycursor
		Deallocate Mycursor
end



alter SECURITY POLICY SupplierPolicyFilter
with (state = on)

--clean up
alter SECURITY POLICY SupplierPolicyFilter
with (state = off)

drop proc drop_NewSContext_Supp_predicate

drop FUNCTION Security.fn_suppiler_predicate
drop SECURITY POLICY SupplierPolicyFilter

drop proc create_NewSContext_Supp_predicate

--4. create a logon trigger to find logins.
-- when the trigger starts, check the sys.security_predicates table
-- and find tables with RLS
-- to sen a mail to the user who logged in with a list of tables and columns with RLS
-- for each RLS to show which predicate it has.
--get end of string (columnname)
--select substring(reverse(predicate_definition) ,4 , charindex('[)]',predicate_definition))predicate_definition, predicate_type_desc from sys.security_predicates

CREATE TRIGGER [LogonPredicateTrigger] /* Creates trigger for logons */
ON ALL SERVER 
FOR LOGON
AS
 
BEGIN
DECLARE @LogonTriggerData xml,
@EventTime datetime,
@profile_name varchar(50),
@recipients varchar(50),
@subject varchar(50),
@query varchar(500)

SET @LogonTriggerData = eventdata()
set @profile_name = eventdata().value('(/EVENT_INSTANCE/LoginName)[1]', 'varchar(50)')
set @recipients=(@profile_name+'@gmail.com')
exec msdb.dbo.sp_send_dbmail 
		@profile_name,
		@recipients,
		@subject='security_predicates information e-mail',
		@query='select OBJECT_NAME(target_object_id) as tableName, predicate_definition, 
				predicate_type_desc as predicateType from sys.security_predicates'
END
GO