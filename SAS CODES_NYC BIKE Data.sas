SAS® Code
/* Import csv files by month */
%Macro loop;
%LOCAL I;
%LET I = 201601;/* %TO 201612 %by 1; /* Update here when new datasets become available*/
filename bike&I '\\cdc.gov\private\L317\icj2\SAS\SASGF_symposium\Data\&I.-citibike-tripdata.csv';*/
data citibike12;
%let _EFIERR_ = 0; /* SET THE ERROR DETECTION MACRO VARIABLE */
infile '/gpfs/sasdata1/bikeride\&I-citibike-tripdata.csv' delimiter = ','
missover dsd lrecl=32767 firstobs=2;
	informat tripduration BEST32.;
	informat starttime ANYDTDTM40.;
	informat endtime ANYDTDTM40.;
	informat start_station_id BEST32.;
	informat start_station_name $29.;
	informat start_station_latitude BEST32.; 
	informat start_station_longitude BEST32.;
	informat end_station_id BEST32.;
	informat end_station_name $29.;
	informat end_station_latitude BEST32.;
	informat end_station_longitude BEST32.;
	informat bikeid BEST32.;
	informat usertype $10.;
	informat birth_year BEST32.;
	informat gender BEST32.;

	format tripduration BEST12.;
	format starttime datetime.;
	format endtime datetime.;
	format start_station_id BEST12.;
	format start_station_name $29.;
	format start_station_latitude BEST12.;
	format start_station_longitude BEST12.;
	format end_station_id BEST12.;
	format end_station_name $29.;
	format end_station_latitude BEST12.;
	format end_station_longitude BEST12.;
	format bikeid BEST12.;
	format usertype $10.;
	format birth_year BEST12.;
	format gender BEST12.;

	input tripduration starttime endtime start_station_id start_station_name $
		start_station_latitude start_station_longitude end_station_id end_station_name $ end_station_latitude
		end_station_longitude bikeid usertype $ birth_year gender;

	if _ERROR_ then call symput('_EFIERR_',1); /* set ERROR detection macro variable */
	run;

/*%END;
%MEND LOOP;
%LOOP;
QUIT;*/ 

Proc contents data=citibike01;
run; 

/*Combining all months of data*/
Data allbike2016;
set CITIBIKE01 CITIBIKE02 CITIBIKE03 CITIBIKE04 CITIBIKE05 CITIBIKE06 CITIBIKE07
	CITIBIKE08 CITIBIKE09 CITIBIKE10 CITIBIKE11 CITIBIKE12;
run;

/*Checking contents*/
Proc contents data=allbike2016;
run;

/*Checking some frequencies*/
Proc freq data=allbike2016;
tables usertype gender;
run;

Proc univariate data=allbike2016;
var tripduration;
histogram;
run;

/*Create some formats*/
Proc format;
	value dow 1 = "Sunday"
				  2 = "Monday"
				  3 = "Tuesday"
				  4 = "Wednesday"
				  5 = "Thursday"
				  6 = "Friday"
				  7 = "Saturday";
	value mth   1 = "January"
				  2 = "February"
				  3 = "March"
				  4 = "April"
				  5 = "May"
				  6 = "June"
				  7 = "July"
				  8 = "August"
				  9 = "September"
				  10 = "October"
				  11 = "November"
				  12 = "December";
	value gender 		  0 = "Unknown"
				  1 = "Male"
 				  2 = "Female";
 	value yn	  0= 'No'
 				  1= 'Yes';
 	value rush	  1='AM rush hour'
 				  2='PM rush hour'
 				  0='Not rush hour';
run;


/*Creating some analysis variables*/
Data allbike2016_a;
set allbike2016;
age = 2016 - birth_year;
start_date = datepart(starttime);
start_time = timepart(starttime);
end_date = datepart(endtime);
end_time = timepart(endtime);
weekday = weekday(start_date);
month = month(start_date);
format start_date end_date mmddyy10. start_time end_time time8. weekday dow. month mth. gender gender.;
run;

/*Check distributions of complete dataset*/
Proc freq data=allbike2016_a;
tables weekday month gender usertype*weekday;
run;

/*Take 10% sample for use in Kennesaw SAS grid*/
Proc Surveyselect data=allbike2016_a out= allbike2016_samp method=srs samprate=0.1;
run;

/* Check distributions of sample data same as full dataset*/
Proc freq data=allbike2016_samp;
table weekday month gender;

/* SAS grid administrator put the 10% sample onto the grid */

/* Importing NYC weathe datafile */
PROC IMPORT OUT= work.weather DATAFILE= "/gpfs/user_home/shebbar/sasuser.v94/weather.csv"
            DBMS=csv REPLACE;
            RUN; 


data work.bike;
set bikeride.citibike2016_samp;
run;


data bike;
set bike;
date_part = datepart(starttime);
time_part= timepart(starttime);
format date_part date9.;
hour=hour(time_part);
run;


/*Merging bike trip data with weather data by day */
PROC SQL;
CREATE TABLE merged1 AS
SELECT *
FROM bike, weather
WHERE bike.date_part=weather.date1 ;
QUIT;


proc sql;
create table ntrip as
SELECT count(*),tripduration , starttime , endtime , start_station_id , start_station_name , start_station_latitude , start_station_longitude , end_station_id , end_station_name , end_station_latitude , end_station_longitude , bikeid , usertype , birth_year , gender , age , start_date , start_time , end_date , end_time , weekday , 'month'n , date_part , VAR1 , STATION , STATION_NAME , 'DATE'n , PRCP , SNWD , SNOW , TMAX , TMIN , AWND , 'day'n , Month_num , Date1
FROM merged1
GROUP BY date1;
quit;

data ntrip;
set ntrip;
rename _TEMG001=no_of_trips;
run;

data bikeride.ntrip;
set ntrip;
run;
run;

libname bike '/gpfs/sasdata1/bikeride';

/* Create hour of day var (HoD), workday( 1= yes, 0 = no), rush hour (rush, 1= am, 2 = pm, 0 = no)*/
Data bike.ntrip_new1;
set bike.ntrip;
HoD = hour(start_time);
if weekday in (2,3,4,5,6) then workday = 1;
else workday = 0;
if HoD in (7,8,9) and workday = 1 then rush = 1;
else if HoD in (16,17,18,19) and workday =1 then rush = 2;
else rush = 0;
run;

/* NYC Bike Share Usage-When & Who?*/
ods graphics / reset imagemap;
title 'NYC Bike Share Usage-When & Who?';
proc sgpanel data=BIKERIDE.NTRIP_NEW1;
   where usertype ="Subscriber" | usertype ="Customer";
  panelby usertype / layout=columnlattice 
                 colheaderpos=bottom rows=1 novarname;
  vbar weekday/ response=no_of_trips group=usertype groupdisplay=cluster clusterwidth=0.8;
  colaxis display=ALL ;
  rowaxis grid;
run;
ods graphics / reset;

/* NYC Bike Share Usage-HourofDay*/
ods graphics / width=25cm height=10cm imagename="test200";
title 'NYC Bike Share Usage-HourofDay';
proc sgpanel data=BIKERIDE.NTRIP_NEW1;
   where usertype ="Subscriber" | usertype ="Customer";
  panelby usertype / layout=columnlattice 
                 colheaderpos=bottom rows=1 novarname;
  vbar HoD/ response=no_of_trips group=usertype groupdisplay=cluster clusterwidth=0.8;
   colaxis display=ALL ;
  rowaxis grid;
run;
ods graphics / reset;

/* NYC Bike Share Usage-month*/
ods graphics / width=25cm height=10cm imagename="test200";
title 'NYC Bike Share Usage-month';
proc sgpanel data=BIKERIDE.NTRIP_NEW1;
   where usertype ="Subscriber" | usertype ="Customer";
  panelby usertype / layout=columnlattice 
                 colheaderpos=bottom rows=1 novarname;
  vbar month/ response=no_of_trips group=usertype groupdisplay=cluster clusterwidth=0.8;
     colaxis display=ALL ;
  rowaxis grid;
run;
ods graphics / reset;

/* Creating Duration categorical variable to analyse over specified time intervals */
data NTRIP_NEW;
set BIKERIDE.NTRIP_NEW1;
tripdurationinminutes=round(tripduration/60,1);
run;

/*Applying format for trip duation*/
proc format;
value mytripduration
0 - 5 = '0-5'
6 - 10 = '6 - 10'
11 - 15 = '11 - 15'
16 - 30 = '16 - 30'
31 - 60 = '31 - 60'
61-high = '60+'
;
run;

data NTRIP_NEW1;
set NTRIP_NEW;
format tripdurationinminutes mytripduration.;
run;

/*NYC Bike Share Usage-Duration over specified intervals*/
ods graphics / width=25cm height=10cm imagename="test200";
title 'NYC Bike Share Usage-Duration';
proc sgpanel data=WORK.NTRIP_NEW1;
   where usertype ="Customer" | usertype ="Subscriber";
  panelby usertype / layout=columnlattice 
                 colheaderpos=bottom rows=1 novarname;
vbar tripdurationinminutes /group=usertype;
  colaxis display=ALL ;
  rowaxis grid label="Number of Rides";
run;
ods graphics / reset;

/*creating most popular routes*/
data bike.test2;
  set BIKERIDE.NTRIP_NEW1;
  Route= catx("  -  ", of start_station_name end_station_name);
run;
proc print data = bike.test2(obs=20);
run;
/*separating dataset for Customers and Subscribers*/
proc sql;
create table bike.bike_data_Subscriber
as 
select * from bike.test2 where usertype='Subscriber';
run;

proc sql;
create table bike.bike_data_Customer
as 
select * from bike.test2 where usertype='Customer';
run;
 

/*144980 distinct routes available out of 1384566.*/
 proc sql;
SELECT count(DISTINCT Route) as distinct_route FROM bike.bike_data_Subscriber;
run;

 proc sql;
 create table bike.bike_analysis_Subscriber as
select Route, count(Route) as CountOfRoute from bike.bike_data_Subscriber group by Route;
run;

proc sort data=bike.bike_analysis_Subscriber out=bike.bike_analysis_Subscriber_sort;
by descending CountOfRoute; 
run;

proc print data=bike.bike_analysis_Subscriber_sort(obs=20);
run;

proc sql;
 create table bike.bike_analysis_Customer as
select Route, count(Route) as CountOfRoute from bike.bike_data_Customer group by Route;
run;

proc sort data=bike.bike_analysis_Customer out=bike.bike_analysis_Customer_sort;
by descending CountOfRoute; 
run;

proc print data=bike.bike_analysis_Customer_sort(obs=20);
run;

data NTRIP_NEW5;
set NTRIP_NEW1;
format month mth. weekday dow. start_date end_date mmddyy10. start_time end_time time8.;
run;

proc contents data=NTRIP_NEW1;
run;

proc contents data=NTRIP_NEW5;
run;

proc sql;
select count (*) as nooftrips,start_date,usertype from ntrip_new5 group by start_date,usertype;
run;

/*Creating no of trips/day variable separately for customers and subscribers */
proc sql;
create table bikeride.bike_data_Final1 as 
select count (*) as nooftrips_Subscriber,* from ntrip_new5 where usertype='Subscriber' group by start_date,usertype ;
run;
/*151105*/
proc sql;
create table bikeride.bike_data_Final2 as 
select count (*) as nooftrips_Customer,* from ntrip_new5 where usertype='Customer' group by start_date,usertype ;
run;

/*merging both datasets to get all the variables including newly created 2 variables*/

data bikeride.bike_data_Final;
set bikeride.bike_data_Final1 bikeride.bike_data_Final2;
by start_date;
run;
/*
 Time Series data preparation
 This is the code that I have taken from sas studio
 *
 */

ods noproctitle;

proc sort data=BIKERIDE.BIKE_DATA_FINAL1 out=Work.preProcessedData;
	by start_date;
run;

proc timedata data=Work.preProcessedData seasonality=7 out=WORK._tsoutput;
	id start_date interval=day setmissing=missing;
	var nooftrips_Subscriber / accumulate=average transform=none;
run;

data WORK.Time_Series_Data_Prep_Sub(rename=());
	set WORK._tsoutput;
run;

proc print data=WORK.Time_Series_Data_Prep_Sub(obs=10);
	title "Subset of WORK.Time_Series_Data_Prep_Sub";
run;

title;

proc delete data=Work.preProcessedData;
run;

proc delete data=WORK._tsoutput;
run;

/*Time Series Exploration*/

ods noproctitle;
ods graphics / imagemap=on;

proc sort data=WORK.TIME_SERIES_DATA_PREP_SUB out=Work.preProcessedData;
	by start_date;
run;

proc timeseries data=Work.preProcessedData seasonality=7 plots=(series corr);
	id start_date interval=day;
	var nooftrips_Subscriber / accumulate=none transform=none dif=0 sdif=0;
run;

proc delete data=Work.preProcessedData;
run;

/*Creating timeseries plot with temperature into account*/

proc sgplot data=bikeride.bike_data_Final;
   series x=start_date y=TMAX/ legendlabel="MAX temperature";
   series x=start_date y=No_of_trips / y2axis legendlabel="Rides per Day";
   yaxis label="MAXTemperature";
   y2axis label="Rides per Day";
run;

/*splitting dataset by cluster*/
data bikeride.cluster1;
set bikeride.clustered;
if _SEGMENT_=1
then output;
run;


data bikeride.cluster2;
set bikeride.clustered;
if _SEGMENT_=2
then output;
run;


data bikeride.cluster3;
set bikeride.clustered;
if _SEGMENT_=3
then output;
run;

data bikeride.cluster4;
set bikeride.clustered;
if _SEGMENT_=4
then output;
run;

/*graph subset data for optgraph*/

%MACRO optclus;
%do i=1 %to 4;
data bikeride.optclus&i(keep=from to);
      set bikeride.cluster&i(rename=(start_station_id=from end_station_id=to));
       run;
%end;
%mend;    

%optclus;   

/*to find centrality*/
%macro central;
%do i=1 %to 4;
proc optgraph
graph_direction = directed
data_links = bikeride.optclus&i
out_nodes = bikeride.NodeSetOut&i;
centrality
degree = both;
run;
%end;
%mend;

%central;

/*merging centrality output with the other variables*/
PROC SQL;
CREATE TABLE bikeride.inter AS
SELECT start_station_id , start_station_name , start_station_latitude , start_station_longitude FROM BIKERIDE.NTRIP_NEW1;
RUN;
QUIT;

PROC SORT DATA=bikeride.inter
 OUT=bikeride.inter1
 NODUPRECS ;
 BY start_station_id ;
RUN ;

data bikeride.inter1;
set bikeride.inter1;
rename start_station_id=node;
run;


%macro combine;
%do i=1 %to 4;
proc sort data=bikeride.nodesetout&i;
by node;
run;
data bikeride.merged&i;
merge bikeride.inter1 bikeride.nodesetout&i;
by node;
run;
%end;
%mend;

%combine;

