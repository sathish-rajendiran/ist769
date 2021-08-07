use [fudgemart_v3]
go
/***************************************************************************************************
	Title	:	Lab Homework2: SQL Programming
	Author	:	Sathish Kumar Rajendiran
	Course	:	IST769	M400
	Term	:	July, 2021
*****************************************************************************************************
1. Use built in SQL functions to write an SQL Select statement on 
   fudgemart_products which derives a product_category column by extracting 
   the last word in the product name.
*/

--built-in functions used 
--CHARINDEX
--REVERSE

select  product_id
      , product_department
	  , product_name
 	  , case
            when CHARINDEX(' ', product_name) = 0 then product_name
            else RIGHT(product_name, CHARINDEX(' ', REVERSE(product_name))-1)
  	    end as product_category
from dbo.fudgemart_products

/*
2. Write a user defined function called f_total_vendor_sales which calculates
the sum of the wholesale price * quantity of all products sold for that vendor. 
There should be one number associated with each vendor id, which is the input 
into the function.  Demonstrate the function works by executing an SQL select 
statement over all vendors calling the function statement. */

/***************************   UDFs Creation - Begins  *******************************************************/
----- dbo.f_total_vendor_Sales  - Creation
----- This Scalar function should return total sales for the given vendor_id
----- Input value: @vendor_id
----- Output value: total sales for all vendors

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='f_total_vendor_Sales')
BEGIN
	DROP FUNCTION f_total_vendor_Sales
END
GO

CREATE FUNCTION 
	dbo.f_total_vendor_Sales(@vendor_id int)
RETURNS money 
AS
BEGIN
	DECLARE @returnValue money  -- data type matches RETURN Value
	/*
	Get vendor_id from the function call as parameter that 
	matches the vendor_id from the products ordered and return the calculated value to variable @returnvalue.
	*/
	SELECT 
	--v.vendor_name,v.vendor_id,p.product_id,o.order_id
	--,p.product_name,p.product_wholesale_price,o.order_qty
	@returnValue = sum(isnull(p.product_wholesale_price * o.order_qty,0))
	FROM fudgemart_vendors as v
	join fudgemart_products as p  ON v.vendor_id = p.product_vendor_id
	join fudgemart_order_details as o ON o.product_id = p.product_id
	where v.vendor_id = @vendor_id
	--where v.vendor_id=3 and o.order_id=3514
	--group by v.vendor_name,v.vendor_id --,p.product_id,o.order_id
	--order by v.vendor_name

	RETURN @returnValue
END
GO

----- Validation: 
--declare @vendor_id int
--set @vendor_id = 1
Select 
vendor_name + ' has made $'
+ isnull(cast(dbo.f_total_vendor_Sales(vendor_id) as nvarchar(max)),0)
+ ' in total sales' as fudgemart_sales_by_vendor
from dbo.fudgemart_vendors 
--where vendor_id = @vendor_id
go

/***************************   UDF Creation - Ends  ******************************************************

3. Write a stored procedure called "p_write_vendor" which when given a required 
vendor name, phone and optional website, will look up the vendor by name first. 
If the vendor exists, it will update the phone and website. 
If the vendor does not exist, it will add the info to the table.  
Write code to demonstrate the procedure works by executing the procedure twice so that it adds a new vendor
and then updates that vendor’s information.

********************************  Stored Procedure Creation - Begins ***************************/
----- p_write_vendor - Creation
----- This Stored procedure update/insert data into  fudgemart_vendors
----- Input value: @vendor_name,@phone and  @website
----- Output : if @vendor_name exists then vendor detail is uptated else new vendor entry is made */

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='p_write_vendor')
BEGIN
	DROP PROCEDURE p_write_vendor
END
GO

CREATE PROCEDURE 
dbo.p_write_vendor(
                   @vendor_name varchar(50),
                   @phone varchar(20),
                   @website varchar(1000))
AS
BEGIN
	declare @vendor_id int
	IF not exists(select * from dbo.fudgemart_vendors where vendor_name = isnull(@vendor_name,'vendor with no name'))
		BEGIN
			--Now we can add the row using an INSERT Statement
			INSERT INTO dbo.fudgemart_vendors (vendor_name,vendor_phone,vendor_website)
			VALUES (isnull(@vendor_name,'vendor with no name'), isnull(@phone,'000-0000'), @website)
			-- pull the vendor id from the newly inserted record
			select @vendor_id = vendor_id from dbo.fudgemart_vendors where vendor_name = isnull(@vendor_name,'vendor with no name')
		END

	ELSE
		BEGIN
		    select @vendor_id = vendor_id from dbo.fudgemart_vendors where vendor_name = isnull(@vendor_name,'vendor with no name')
			-- now we can update the vendors detail
			UPDATE dbo.fudgemart_vendors
        	SET vendor_phone = isnull(@phone,'000-0000'),
              	vendor_website = @website
        	WHERE vendor_id = @vendor_id
		END

--Return the affected row
select * from dbo.fudgemart_vendors
where vendor_id= @vendor_id

END
GO

------Udate/Insert into p_write_vendor table
EXEC dbo.p_write_vendor @vendor_name=NULL, @phone=NULL, @website='www.syr.edu'
GO
EXEC dbo.p_write_vendor @vendor_name='daisy', @phone='792-1234', @website=NULL
GO
EXEC dbo.p_write_vendor @vendor_name='daisy', @phone='792-1234', @website='www.liver-more.edu'
GO

/********************************  Stored Procedure Creation - Ends ******************************************

4. Create a view based on the logic you completed in question 1 or 2. 
Your SQL script should be programmed so that the entire script works every time, 
dropping the view if it exists, and then re-creating it

********************************  SQL Views Creation - Begins ***************************
----- vw_product_details - Creation
----- This view returns product details. Refer #1 from excercise above */

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='vw_product_details')
	BEGIN
		DROP VIEW vw_product_details
	END
	GO

CREATE VIEW dbo.vw_product_details
AS
	select  
    	  product_id
		, product_department
		, product_name
		, case
		  when CHARINDEX(' ', product_name) = 0 then product_name
		  else RIGHT(product_name, CHARINDEX(' ', REVERSE(product_name))-1)
		  end as product_category
	from dbo.fudgemart_products
GO

----Retrive values from the vw_product_details View 
SELECT  * FROM vw_product_details
GO

----- vw_vendor_sales - Creation
----- This view returns total sales by vendors. Refer #2 from excercise above */

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='vw_vendor_sales')
	BEGIN
		DROP VIEW vw_vendor_sales
	END
	GO

CREATE VIEW dbo.vw_vendor_sales
AS
	Select 
	vendor_name + ' has made $'
	+ isnull(cast(dbo.f_total_vendor_Sales(vendor_id) as nvarchar(max)),0)
	+ ' in total sales' as fudgemart_sales_by_vendor
	from dbo.fudgemart_vendors 
GO
----Retrive values from the vw_vendor_sales View 
SELECT  *  FROM vw_vendor_sales
GO

/********************************  SQL Views Creation - Ends ***************************

5. Write a table valued function f_employee_timesheets which when provided an employee_id 
will output the employee id, name, department, payroll date, hourly rate on the timesheet, 
hours worked, and gross pay (hourly rate times hours worked)

***************************   Table Valued Function Creation - Begins  *******************************************************/
----- dbo.f_employee_timesheets  - Creation
----- This Table value function should return employee details for the given employee_id
----- Input value: @employee_id
----- Output value: table value with employee details

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='f_employee_timesheets')
BEGIN
	DROP FUNCTION f_employee_timesheets
END
GO

CREATE FUNCTION dbo.f_employee_timesheets(
  	@employee_id INT
)
RETURNS TABLE
AS
  	RETURN (
            SELECT 
			  e.employee_id
			, e.employee_lastname +', ' +e.employee_firstname as name
			, e.employee_department as department
			, cast(t.timesheet_payrolldate as date) as payrolldate
			, round(isnull(t.timesheet_hourlyrate,0),2) as timesheet_hourly_rate
			, isnull(t.timesheet_hours,0) as hours_worked
			, cast(isnull(t.timesheet_hours * t.timesheet_hourlyrate,0) as decimal(9,2)) as grosspay
            FROM dbo.fudgemart_employee_timesheets as t
            Join dbo.fudgemart_employees as e ON e.employee_id = t.timesheet_employee_id
            WHERE e.employee_id = @employee_id
	);
 GO

----- Validation: 
Select top 5 * from dbo.f_employee_timesheets(10) 
GO

/***************************   Table value function Creation - Ends  ******************************************************/
