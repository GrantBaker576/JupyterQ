\c 100 100
\cd C:\q\w32\

/ Import Python libraries
\l p.q
/import several ml libraries
\l quantQ\lib\quantQjupyterq.q
\l mlnotebooks\utils\graphics.q
\l automl\automl.q


\l ml\ml.q

\l mlnotebooks\utils\graphics.q
\l mlnotebooks\utils\util.q
/Fun Q ml library
\l funq\funqJQ.q
/graphing 
\l embedPy\examples\importmatplotlib.q
plt:.matplotlib.pyplot[]


//A True/false table is given for our 130 features
features:("SSSSSSSSSSSSSSSSSSSSSSSSSSSSSS";enlist",") 0: `:C:/MLProjects/JaneStreetMarketPrediction/features.csv
features:(select feature from features) ,'(flip 1_flip features = `TRUE)
`feature xkey `features 
features:"f"$features
show 10#features

//1 for true, 0 for false

//load 500 days of trade data
t:("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";enlist",") 0: `:C:/MLProjects/JaneStreetMarketPrediction/train.csv

//key the table based on date
`date xkey `t
//apply sort attribute on table t
`s#t;



count select from t where resp_4 >0, resp<0
count select from t where resp_4 >0, resp>0

count select from t where resp_4 <0, resp<0
count select from t where resp_4 <0, resp>0

/
There is a high likelihood of

Rule 1: Optimize for resp_4
Rule 2: Don't take trades with weight above X
Rule 3: End model uses online learning
Rule 4: Be prepared for regime change (Identify the change itself, warning signs, and effects)
Rule 5: Feature Engineer lagging indicators

update sumresp:sums resp_1 from `t
plt.xlabel"Date";
plt.ylabel"Price change";
plt.title"Asset Price (cumulative resp_1)";
plt.grid 1b;
plt.scatter[exec sumresp from t;  exec date from t]
plt.show[];

//we see the asset appreciate over time, making most trades profitable
//we will likely see very similar trading days. We will try to cluster trading days together later on
delete sumresp from `t;

//We analyze the data on a per day basis. 

day0t:select from t where date=0
day0t:0!day0t //unkey
delete date, weight, ts_id  from `day0t;
update trade:0 from `day0t;
update trade: 1 from `day0t where  resp>0;
day0t:`trade xcols day0t

//Partition data into training and testing, no time series data leakage
d:.ut.part[`train`test!3 1;til] "f"$day0t
//fill nulls
d.train:0f^d.train
d.test:0f^d.test
delete resp_1, resp_2, resp_3, resp_4, resp from `d.train
delete resp_1, resp_2, resp_3, resp_4, resp from `d.test

y:first get first `Y`X set' 0 1 cut value flip d`train
yt:first get first `Yt`Xt set' 0 1 cut value flip d`test



zsf:.ml.zscoref each X
X:zsf @' X
Xt:zsf @' Xt

//unregularized
show THETA:enlist theta:(1+count X)#0f
THETA:1#.fmincg.fmincg[2000;.ml.logcostgrad[();Y;X];THETA 0]
avg yt=first "i"$.ml.plog[Xt] THETA

//We will now regularize
f:.ml.logcost[();Yt;Xt]1#.fmincg.fmincg[;;THETA 0]::
l2:.ut.sseq[.05;0;.55]
e:(f[1000] .ml.logcostgrad[;Y;X] .ml.l2@) each l2

//Find optimal l2 regularization
.ml.imin l2!e

//0.55 is the optimal l2 regularization parameter
THETA:1#.fmincg.fmincg[1000;.ml.logcostgrad[.ml.l2[0.55];Y;X]; THETA 0]

.ut.rnd[0.01] p0:first .ml.plog[Xt] THETA

"i"$p0
avg yt="i"$p0

// 53.75% accuracy on test data is not good. 
testTable0:1397#t
update test0:p0>0.5 from `testTable0
select avg resp from testTable0 where test0=1

select avg resp from testTable0
select avg resp from testTable0 where test0=0
(exec avg resp from testTable0 where test0=0)%(exec avg resp from testTable0)

//A 270% increase in return over random selection is great, though we have to reverse the intent of the algo
//Instead of predicting trades using features, we will use the change in features
delta0t:day0t - prev day0t
delta0:0f^delta0t
update trade:(exec trade from day0t) from `delta0t
delta0t:1_delta0t; //drop first row
delta0:.ut.part[`train`test!3 1;til] "f"$delta0t
delete resp_1, resp_2, resp_3, resp_4, resp from `delta0.train;
delete resp_1, resp_2, resp_3, resp_4, resp from `delta0.test;
delta0.train:0f^delta0.train
delta0.test:0f^delta0.test

y:first get first `Y`X set' 0 1 cut value flip delta0.train
yt:first get first `Yt`Xt set' 0 1 cut value flip delta0.test

zsf:.ml.zscoref each X
X:zsf @' X
Xt:zsf @' Xt

show THETA:enlist theta:(1+count X)#0f
f:.ml.logcost[();Yt;Xt]1#.fmincg.fmincg[;;THETA 0]::
l2:.ut.sseq[.05;0;.55]
e:(f[1000] .ml.logcostgrad[;Y;X] .ml.l2@) each l2

//Find optimal l2 regularization
show l2reg:.ml.imin l2!e

//0.55 is still the optimal l2 regularization parameter
THETA:1#.fmincg.fmincg[1000;.ml.logcostgrad[.ml.l2[l2reg];Y;X]; THETA 0]
.ut.rnd[0.01] p:first .ml.plog[Xt] THETA
"i"$p
avg yt="i"$p

//60% accuracy is not a bad score as a trade selector
//We can still see if the predicted trades have 
p:0,p //replace initial row

count p>.5

testTable:1398#t
update test:p>0.5 from `testTable

select avg resp from testTable where test=1

select avg resp from testTable
select avg resp from testTable where test=0
(exec avg resp from testTable where test=0)%(exec avg resp from testTable)

//Interestingly, when we inverse the intent of the algo we do quite well, 4x better in fact.
//selection via feature deltas is significantly better than using features
//Below is the  best possibl score
select avg resp from testTable where resp>0

//These are just the THETAs for a single day. We make the assumption that each day has different trading dynamics
//We now must test our THETAs over a period of dates
//Perhaps there are similar trading days which we can cluster

//create day1t table
day1t:select from t where date=1
day1t:0!day1t //unkey
delete date, weight, ts_id  from `day1t;
update trade:0 from `day1t;
update trade: 1 from `day1t where  resp>0;
day1t:`trade xcols day1t

//create delta1t table
delta1t:day1t - prev day1t
update trade:(exec trade from day1t) from `delta1t
delta1t:1_delta1t; //drop first row
delta1:0f^delta1t
delete resp_1, resp_2, resp_3, resp_4, resp from `delta1;
delta1:0f^delta1


y:first get first `Y`X set' 0 1 cut value flip delta1
zsf:.ml.zscoref each X
X:zsf @' X



.ut.rnd[0.01] p1:first .ml.plog[X] THETA
"i"$p1
avg y="i"$p1

p1:0,p1 //replace initial row
count p1
count select from t where date=1

testTable1:select from t where date =1
update test:p1>0.5 from `testTable1

select avg resp from testTable1 where test=1

select avg resp from testTable1
select avg resp from testTable1 where test=0
abs((exec avg resp from testTable1 where test=0)%(exec avg resp from testTable1))

//Even on a different day, we still have positive results (108% increase), though the THETAs likely would need to be adjusted.
//We can either find new THETAs across a larger set of dates and apply to the table, or find new THETAs every so often
//It is unlikely there is some static set of THETAs which will give us what we want, but it doesn't hurt to try

//We will start out by applying current THETAs to first 30 days to see how alpha deteriorates over time
/create table
t30:select from t where date<31
t30:0!t30 //unkey
delete date, weight, ts_id  from `t30;
update trade:0 from `t30;
update trade: 1 from `t30 where  resp>0;
t30:`trade xcols t30

/create delta table

delta30t:t30 - prev t30
update trade:(exec trade from t30) from `delta30t
delta30t:1_delta30t; //drop first row
delta30:0f^delta30t
delete resp_1, resp_2, resp_3, resp_4, resp from `delta30;
delta30:0f^delta30

y:first get first `Y`X set' 0 1 cut value flip delta30
zsf:.ml.zscoref each X
X:zsf @' X


.ut.rnd[0.01] p30:first .ml.plog[X] THETA
"i"$p30
avg y="i"$p30

p30:0,p30 //replace initial row
count p30
count select from t30 

update test:p30>0.5 from `t30

update date:(count t30)#(exec date from t) from `t30;

select avg resp by date from t30 where test=0
