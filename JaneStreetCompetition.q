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
//apply sort attribute on tablee t
`s#t;



//I wish to see the cumulative behavior of the asset and the corresponding features

sumTable:((sum select from t where date = 0);(sum select from t where date = 1))
`sumTable upsert (sum select from t where date = 3);
`sumTable upsert (sum select from t where date = 4);
`sumTable upsert (sum select from t where date = 5);
`sumTable upsert (sum select from t where date = 6);
`sumTable upsert (sum select from t where date = 7);
`sumTable upsert (sum select from t where date = 8);
`sumTable upsert (sum select from t where date = 9);
`sumTable upsert (sum select from t where date = 10);
`sumTable upsert (sum select from t where date = 11);
`sumTable upsert (sum select from t where date = 12);
`sumTable upsert (sum select from t where date = 13);
`sumTable upsert (sum select from t where date = 14);
`sumTable upsert (sum select from t where date = 15);
`sumTable upsert (sum select from t where date = 16);
`sumTable upsert (sum select from t where date = 17);
`sumTable upsert (sum select from t where date = 18);
`sumTable upsert (sum select from t where date = 19);
`sumTable upsert (sum select from t where date = 20);
`sumTable upsert (sum select from t where date = 21);
`sumTable upsert (sum select from t where date = 22);
`sumTable upsert (sum select from t where date = 23);
`sumTable upsert (sum select from t where date = 24);
`sumTable upsert (sum select from t where date = 25);
`sumTable upsert (sum select from t where date = 26);
`sumTable upsert (sum select from t where date = 27);
`sumTable upsert (sum select from t where date = 28);
`sumTable upsert (sum select from t where date = 29);
`sumTable upsert (sum select from t where date = 30);

desc u cor/:\:u:flip sumTable
//If we assume cumulative weight is a measure of trading activity, then features 19, 64, 41, 25, 107... correlate with vol

sum select resp_1,resp_2,resp_3,resp_4 from sumTable
//we see on average that the longer the hold the more profit. 

count select from t where resp_1 >0, resp<0
count select from t where resp_1 <0, resp>0

/
There are plenty of trades that start off negative but end positive and vis versa, almost identical counts
We will not take trades with positive resp. Instead, we take trades with positive resp_1

Rule 1: Don't take any trades with a negative return on 1st time horizon
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

//We analyze the data on a per day basis. 
delete sumresp from `t;
day0t:select from t where date=0


day0t:0!day0t //unkey
delete date, weight, ts_id  from `day0t;

update trade:0 from `day0t;
update trade: 1 from `day0t where  resp_1>0;
day0t:`trade xcols day0t

//Make decision tree to separate, no time series data leakage
d:.ut.part[`train`test!3 1;til] day0t
delete resp_1, resp_2, resp_3, resp_4, resp from `d.train
delete resp_1, resp_2, resp_3, resp_4, resp from `d.test

//random forest, number features used = sqrt n
k:20
m:.ml.bag[k;.ml.ct[(1#`maxff)!1#sqrt;::]] d.train ///make k decision trees
//random forest sqrt features p171
max avg d.test.trade = .ml.pbag[1+til k;m] d.test

//at 52.4%, Random Forests with existing data fail as a binary classifier
//Instead of predicting trade viability using features, we will use the change in features
delta0t:day0t - prev day0t
update trade:(exec trade from day0t) from `delta0t
delta0t:1_delta0t; //drop first row
delta0:.ut.part[`train`test!3 1;til] delta0t
delete resp_1, resp_2, resp_3, resp_4, resp from `delta0.train;
delete resp_1, resp_2, resp_3, resp_4, resp from `delta0.test;

//random forest, number features used = sqrt n (using delta of features)
k:20
m:.ml.bag[k;.ml.ct[(1#`maxff)!1#sqrt;::]] delta0.train ///make k decision trees
//random forest sqrt features p171
max avg delta0.test.trade = .ml.pbag[1+til k;m] delta0.test

//Running a random forest on the deltas seems to be fruitless as well. 
//For completeness, we will use adaptive boosting as well.

/partition
count each d:.ut.part[`train`test!3 1;til] day0t
delete resp_1, resp_2, resp_3, resp_4, resp from `d.train;
delete resp_1, resp_2, resp_3, resp_4, resp from `d.test;

/create decision tree stump to use as a weak classifier
stump:.ml.ct[(1#`maxd)!1#1]
-1 .ml.ptree[0] stump[::] d.train

//Our best feature is feature_39 with a 40% error rate
//We will run 20 rounds of Adaboost and store model in m
k:20
m:.ml.fab[k;stump;.ml.pdt] d.train

//This is computationally expensive. We check for converging k value before testing
P:.ml.pab[1+ til k;.ml.pdt;m] d.train
max avg d.train.trade = P

//At 58.75% accuracy on training data, it would seem adaboost is a poor fit for the feature data
P:.ml.pab[1+ til k;.ml.pdt;m] d.test
max avg d.test.trade = P

//53.82% on test data
//Let us proceed to use the deltas instead
k:20
m:.ml.fab[k;stump;.ml.pdt] delta0.train //train model
//test model on training data
P:.ml.pab[1+ til k;.ml.pdt;m] delta0.train
max avg delta0.train.trade = P

//At 55.86% accuracy on training data is very poor. Let us move on to test
P:.ml.pab[1+ til k;.ml.pdt;m] delta0.test
max avg delta0.test.trade = P
