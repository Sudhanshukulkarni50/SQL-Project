use chinook;
select * from album;
select * from artist;
select * from customer;
select * from employee;
select * from genre;
select * from invoice;
select * from invoice_line;
select * from media_type;
select * from playlist;
select * from playlist_track;
select * from track;
use chinook;
-- Answer for Q. 1.	Does any table have missing values or duplicates? If yes how would you handle it?

-- ---------------------------------------------------------------checking for duplicates in tables ---------------------------------------------------------------------------
select count(*) from album
group by album_id having count(*)>1;
select count(*) from artist
group by artist_id having count(*)>1;
select count(*) from customer
group by customer_id having count(*)>1;
select count(*) from employee
group by employee_id having count(*)>1;
select count(*) from genre
group by genre_id having count(*)>1;
select count(*) from invoice
group by invoice_id having count(*)>1;
select count(*) from invoice_line
group by invoice_line_id having count(*)>1;
select count(*) from media_type
group by media_type_id having count(*)>1;
select count(*) from playlist
group by playlist_id having count(*)>1;
select count(*) from playlist_track
group by track_id having count(*)>1;
select count(*) from track
group by track_id having count(*)>1;

-- --------------------------------------------------------------------No Non required Duplicates found------------------------------------------------------------------------

-- ------------------------------------------------------------------------- Removing Null values ---------------------------------------------------

-- ----------------------------------------------------------------------- removing null values in customer table --------------------------------------------------------------------------------
select * from customer;
select company,state,fax,postal_code from customer;
update customer 
set 
	company = coalesce(company, 'Unknown Company'),
    state = coalesce(state, 'Unknown State'),
    fax = coalesce(fax, 'Not Provided'),
    postal_code = coalesce(postal_code, '000000');
    
    -- -----------------------------------------------------removing null values in employee table -----------------------------------------------------------------
update employee
set 
	reports_to = coalesce(reports_to,2);
    
 -- --------------------------------------------------------removing null values in employee table -----------------------------------------------------------------
update track 
set 
	composer = coalesce(composer,'Unknown Composer');
    
/*   Answer for Q.2:  Find the top-selling tracks and top artist in the USA and identify their most famous genres. */
 
select distinct  t.name as track_name, t.composer as Artist,g.name as genre from 
(select track_id, sum(quantity) as t_count from invoice_line
group by track_id
order by t_count desc 
limit 5) as ls
join track t 
on ls.track_id = t.track_id
join invoice_line il 
on ls.track_id = il.track_id
join invoice i 
on il.invoice_id = i.invoice_id
join genre g 
on t.genre_id = g.genre_id
where i.billing_country  = 'USA';

-- Answer for Q.4.Calculate the total revenue and number of invoices for each country, state, and city:------------------------------------------------------

call total_revenue_for_country_state_city;

-- Answer for  Q. 5.	Find the top 5 customers by total revenue in each country --------------------------------------------------------------------------------------

with billing_customers as (select billing_country, customer_id, sum(total) 
as total_revenue from invoice
group by billing_country, customer_id
)
, ranked_customers as (select billing_country, customer_id, total_revenue, 
row_number() over(partition by billing_country
order by total_revenue desc) as rnk from billing_customers)
select billing_country, customer_id, total_revenue from ranked_customers
where rnk<=5
order by billing_country, rnk;


--  Answer for  Q.6	Identify the top-selling track for each customer  ---------------------------------------------------------------------------------------

with top_ids AS (select i.customer_id, SUM(il.quantity * il.unit_price) AS total_price
    from invoice i
    join invoice_line il ON i.invoice_id = il.invoice_id
    group by i.customer_id
),
top_person as (select customer_id, total_price, row_number() over (partition by customer_id order by total_price desc) as rnk
    from top_ids
),
customer_track_spending as ( select tp.customer_id,t.name as track_name,
        sum(il.quantity * il.unit_price) AS total_spent,
        row_number() over (partition by tp.customer_id order by SUM(il.quantity * il.unit_price) desc) as track_rnk
    from top_person tp
    join invoice i ON tp.customer_id = i.customer_id
    join invoice_line il ON i.invoice_id = il.invoice_id
    join track t ON il.track_id = t.track_id
    where tp.rnk = 1
    group by tp.customer_id, t.name
)
select concat(c.first_name,' ',c.last_name) as cust_name,ts.customer_id, ts.track_name, ts.total_spent
from  customer_track_spending ts
join customer c ON ts.customer_id = c.customer_id
where  ts.track_rnk = 1
order by ts.total_spent desc;

-- Answer for Q.7  What is the customer churn rate?  ----------------------------------------------------------------------------------------------------------

with observation_period as (select distinct customer_id from invoice 
where invoice_date between '2017-01-03 00:00:00'and '2020-12-30 00:00:00'),
churn_period as (select distinct customer_id from invoice
where invoice_date between '2020-01-01 00:00:00' and '2020-12-31 23:59:59'),
churned_customers as (select customer_id from observation_period
 where customer_id not in (select customer_id from churn_period ))
select ((select count(distinct customer_id) from churned_customers)/
(select count(distinct customer_id) from observation_period))*100 as Churn_Rate;

-- Answer for Q.9  Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists. ----------------------

with sales_by_genre as (select distinct g.genre_id, g.name, sum(il.quantity*il.unit_price) as total_price from genre g 
join track t 
on g.genre_id = t.genre_id 
join invoice_line il
on t.track_id = il.track_id
join invoice i 
on il.invoice_id = i.invoice_id
join customer c 
on i.customer_id = c.customer_id
where i.billing_country= 'USA'
group by g.name,g.genre_id
order by g.genre_id)
select genre_id, name as genre_name, 
round((total_price/(select sum(total_price) as total_sales from sales_by_genre))*100,2)
 as genre_percentage from sales_by_genre 
group by genre_id,name 
order by genre_id;

-- Answer for Q.9  Find customers who have purchased tracks from at least 3 different genres -------------------------------------------------------------------

select c.customer_id, concat(c.first_name,' ',c.last_name) as cust_name, 
count(distinct g.genre_id) as genre_count from customer c
join invoice i
on c.customer_id = i.customer_id
join invoice_line il 
on i.invoice_id = il.invoice_id 
join track t 
on il.track_id = t.track_id 
join genre g 
on t.genre_id = g.genre_id
group by c.customer_id, cust_name
having genre_count>3;

-- Q.10  Answer for Rank genres based on their sales performance in the USA-----------------------------------------------------------------------------------------

with genre_sales as (select  distinct g.genre_id, g.name, 
sum(il.quantity*il.unit_price) over(partition by g.genre_id ) as amount  from genre g 
join track t 
on g.genre_id = t.genre_id
join invoice_line il 
on t.track_id = il.track_id
join invoice i
on il.invoice_id = i.invoice_id
join customer c 
on i.customer_id = c.customer_id 
where i.billing_country = 'USA')
select genre_id, name as genre_name, dense_rank() over(order by amount desc) as 'rank' from genre_sales;

-- Answer for Q.11	Identify customers who have not made a purchase in the last 3 months------------------------------------------------------

select distinct c.customer_id, concat(c.first_name,' ',c.last_name) as cust_name ,
i.invoice_date from customer c
join invoice i 
on c.customer_id = i.customer_id 
where c.customer_id not in 
(select c.customer_id from customer c
join invoice i 
on c.customer_id = i.customer_id 
where i.invoice_date between '2020-10-01 00:00:00' and '2020-12-31 23:59:59')
order by i.invoice_date;

-- --------------------------------------------------------Subjective Questions ---------------------------------------------------------------

/* ----------------------Answer for Q.1 	Recommend the three albums from the new record label that should be prioritised  -------------------------------------------
											for advertising and promotion in the USA based on genre sales analysis.*/
                        
with recommended_albums as (
select a.album_id, a.title , g.name, sum(il.quantity*il.unit_price) as total_amount from album a 
join track t 
on a.album_id = t.album_id
join invoice_line il 
on t.track_id = il.track_id
join genre g 
on t.genre_id = g.genre_id
group by a.album_id, a.title, g.name
order by total_amount desc
)
select album_id, title as album_name, name as genre_name from recommended_albums
limit 3;

/* Answer for Q.2	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.--------------------------------*/

with genresales as (
    select i.billing_country,g.name as genre_name,sum(il.quantity * t.unit_price) as total_sales,
        row_number() over(partition by i.billing_country order by sum(il.quantity * t.unit_price) desc)
        as rnk from invoice_line il
    join track t
    on il.track_id = t.track_id
    join genre g 
    on t.genre_id = g.genre_id
    join invoice i 
    on il.invoice_id = i.invoice_id
    where i.billing_country != 'usa'
    group by i.billing_country, g.name
)
select billing_country,genre_name,total_sales from genresales 
where rnk <= 2;

/* Answer for Q.3.	Customer Purchasing Behavior Analysis: How do the purchasing habits 
(frequency, basket size, spending amount) of long-term customers differ from those of new customers? 
What insights can these patterns provide about customer loyalty and retention strategies?   */

 -- --------------------------------------average and total amount spent by each old customer------------------------------------------------------------------

select c.customer_id, concat(c.first_name,c.last_name) as cust_name,
 sum(i.total) as total_amount, round(avg(i.total),2) 
 as avg_amount from customer c 
join invoice i 
on c.customer_id = i.customer_id 
where c.customer_id not in 
(select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
group by c.customer_id, cust_name
order by c.customer_id;
 -- -------------------------------------------------average and total amount spent by each new customer---------------------------------------------------------

select c.customer_id, concat(c.first_name,c.last_name) as cust_name, 
sum(i.total) as total_amount, round(avg(i.total),2) as avg_amount from customer c 
join invoice i 
on c.customer_id = i.customer_id 
where c.customer_id  in
 (select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
group by c.customer_id, cust_name
order by c.customer_id;


-- ---------------------------------------------------------total items purchased  by old_customer---------------------------------------------------------------------
select c.customer_id, concat(c.first_name,c.last_name) as cust_name, 
sum(il.quantity) as purchased_items from customer c
join invoice i 
on c.customer_id = i.customer_id 
join invoice_line il 
on i.invoice_id = il.invoice_id 
where c.customer_id not in 
(select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
group by c.customer_id,cust_name
order by c.customer_id ;

-- ----------------------------------------------------total items purchased  by new customer-------------------------------------------------------------------------

select c.customer_id, concat(c.first_name,c.last_name) as cust_name, 
sum(il.quantity) as purchased_items from customer c
join invoice i 
on c.customer_id = i.customer_id 
join invoice_line il 
on i.invoice_id = il.invoice_id 
where c.customer_id  in
 (select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
group by c.customer_id,cust_name
order by c.customer_id ;

-- --------------------------------------------------------top tracks of old customer -----------------------------------------------------------------------------------
with top_tracks as (select distinct c.customer_id, t.track_id,t.name,
sum(il.quantity*il.unit_price) over(partition by t.track_id ) as total_price from customer c 
join invoice i 
on c.customer_id = i.customer_id
join invoice_line il 
on i.invoice_id = il.invoice_id
join track t 
on il.track_id = t.track_id
where c.customer_id not in 
(select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
 ),
track_rank as (select customer_id,track_id,name,
row_number() over(partition by customer_id order by total_price desc) as rnk from top_tracks)
select customer_id, track_id,name as track_name from track_rank
where rnk = 1;

--  -----------------------------------------------top tracks of neww_customer -----------------------------------------------------------------------------------

with top_tracks as (select distinct c.customer_id, t.track_id,t.name,
sum(il.quantity*il.unit_price) over(partition by t.track_id ) as total_price from customer c 
join invoice i 
on c.customer_id = i.customer_id
join invoice_line il 
on i.invoice_id = il.invoice_id
join track t 
on il.track_id = t.track_id
where c.customer_id  in 
(select customer_id from invoice where invoice_date between '2020-09-30' and '2020-12-31') 
 ),
track_rank as (select customer_id,track_id,name,
row_number() over(partition by customer_id order by total_price desc) as rnk from top_tracks)
select customer_id, track_id,name as track_name from track_rank
where rnk = 1;



/* Answer for Q.4.	Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? 
How can this information guide product recommendations and cross-selling initiatives?  */

-- ----------------------------------------------------Tracks that are bought together frequently -- ------------------------------------------------------------------------

select il1.track_id as track_1, t1.name as track_name_1, 
il2.track_id as track_2, t2.name as track_name_2,count(*) as purchase_count from invoice_line il1 
join invoice_line il2 
on il1.invoice_id = il2.invoice_id and il1.track_id<il2.track_id
join track t1 
on il1.track_id = t1.track_id 
join track t2 
on il2.track_id = t2.track_id
group by il1.track_id, t1.name, il2.track_id,t2.name
order by purchase_count desc;

-- ----------------------------------albums bought together frequently  -- -----------------------------------------------------------------------------------
select a1.album_id,a1.title, a2.album_id, a2.title, count(*) 
as purchase_count from invoice_line il1 
join invoice_line il2 
on il1.invoice_id = il2.invoice_id and il1.track_id<il2.track_id
join track t1 
on il1.track_id = t1.track_id
join track t2 
on il2.track_id = t2.track_id 
join album a1 
on t1.album_id = a1.album_id
join album a2 
on t2.album_id = a2.album_id
group by a1.album_id,a1.title,a2.album_id,a2.title
order by purchase_count desc;


 
 /*  Answer for Q.5.	Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations?
		How might these correlate with local demographic or economic factors?*/
        
-- ------------------- total sales and purchases by region -- -----------------------------------------------------------------------------------
select c.country, concat(c.first_name,' ',c.last_name) as cust_name,
 count(i.invoice_id) as purchase_count,
sum(il.quantity*il.unit_price) as total_sales from customer c
join invoice i 
on c.customer_id = i.customer_id
join invoice_line il 
on il.invoice_id = i.invoice_id
group by c.country,cust_name;
-- ----------------------------------------------------------------Churn Rate by region ------------------------------------------------------------------------
with churned_customers as
 (select billing_country,customer_id from invoice where invoice_date between '2020-01-01' and '2020-12-31'),
total_customers as (select distinct customer_id from invoice where 
invoice_date between '2017-01-03' and '2020-12-31')
select cc.billing_country, count(distinct cc.customer_id)*100/count(tc.customer_id) as 
churn_rate from churned_customers cc 
join total_customers tc 
on cc.customer_id = tc.customer_id
group by cc.billing_country;

/*  Answer for Q.6.	Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), 
which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?*/

-- top country,states and cities where customers are more likely to churn or pose a higher risk of reduced spending
call total_expenditure_by_region;
-- top tracks albums and genres that customers are more likely to churn or pose a higher risk of reduced spending
call expenditure_by_audio;



/* 7.	Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of
 different customer segments?This could inform targeted marketing and loyalty program strategies.
 Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?  */
 
-- ----------------------------------------------List of customers with predicted CLV   -----------------------------------------------------------------------------------
with customer_info as (select c.customer_id, concat(c.first_name,' ',c.last_name) as cust_name,min(i.invoice_date) as first_purchase_date, max(invoice_date) as last_purchase_date,
timestampdiff(year,min(i.invoice_date),max(i.invoice_date)) as customer_tenure_in_yrs,
 sum(il.quantity*il.unit_price) as total_revenue, avg(il.quantity*il.unit_price) as avg_revenue,
count(i.invoice_id) as total_purchases from customer c 
join invoice i 
on c.customer_id = i.customer_id 
join invoice_line il 
on i.invoice_id = il.invoice_id
group by c.customer_id,cust_name)

select customer_id,cust_name,round(avg_revenue*total_purchases*customer_tenure_in_yrs,2) as Predicted_CLV from customer_info
group by customer_id,cust_name
order by customer_id;

-- -----------------------------list of customers who have not made any purchase >=200 days  ---------------------------------------------------------------------------

select customer_id,cust_name, timestampdiff(day,last_purchase_date,'2020-12-31') as days_since_last_purchase
from (select c.customer_id, concat(c.first_name,' ',c.last_name) as cust_name, max(i.invoice_date) as last_purchase_date from customer c 
join invoice i 
on c.customer_id = i.customer_id
group by c.customer_id,cust_name) as ls
having days_since_last_purchase>200
order by customer_id;

/* Answer for Q.10.	How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?*/
alter table album
add column ReleaseYear int ;

select * from album;
/* Answer for Q.11.	Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. 
They want to know the average total amount spent by customers from each country, along with the number of
 customers and the average number of tracks purchased per customer. Write an SQL query to provide this information. */
 
select c.country, count(distinct c.customer_id) as customer_count, round(avg(total_spent),2) as avg_total_spent, round(avg(total_tracks)) as avg_tracks_per_customer from customer c
join 
(select i.customer_id, sum(il.quantity*il.unit_price) as total_spent,
sum(il.quantity) as total_tracks from invoice i 
join invoice_line il 
on i.invoice_id = il.invoice_id
group by i.customer_id ) t
on c.customer_id = t.customer_id
group by c.country;










