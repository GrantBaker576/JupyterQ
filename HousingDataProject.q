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



//Import testing data table
show 20#tTest:("FFSFFSSSSSSSSSSSSFFFFSSSSSFSSSSSSSFSFFFSSSSFFFFFFFFFFSFSFSSFSFFSSSFFFFFFSSSFFFSS";enlist",") 0: `:C:/MLProjects/HousePrices/test.csv

//import training data 
show 20#t:("FFSFFSSSSSSSSSSSSFFFFSSSSSFSSSSSSSFSFFFSSSSFFFFFFFFFFSFSFSSFSFFSSSFFFFFFSSSFFFSSF";enlist",") 0: `:C:/MLProjects/HousePrices/train.csv

/Data Exploration for null values
/nulltablefunction:{![x;();0b;( cols x)!((count cols x)#0N)]}

nullExplore:flip `columnName`nullCount!(key;value)@\:sum null t
select from nullExplore where nullCount >0

/First, we deal with Masonry Veneer nulls, replace with 0

select MasVnrType, MasVnrArea from t where MasVnrArea = 0N

t: update MasVnrArea:0.0 from t where MasVnrType =`NA

nullExplore:flip `columnName`nullCount!(key;value)@\:sum null t
select from nullExplore where nullCount >0


/LotFrontage has many nulls, lets explore lot data
//avg sale price for null group
select avg SalePrice from t where LotFrontage  = 0N
5#select LotFrontage, LotArea, LotConfig, LotShape from t where LotFrontage  = 0N
//avg sale price for not null group
select avg SalePrice from t where (LotFrontage  = 0N)=0b
5#select LotFrontage, LotArea, LotConfig, LotShape from t where (LotFrontage  = 0N)=0b

/explore possible pattern for LotFrontage nulls
avg select LotArea from t 
med select LotArea from t
avg select SalePrice from t
"Where LotFrontage has missing values:"
avg select LotArea from t where LotFrontage = 0N
med select LotArea from t where LotFrontage = 0N
avg select SalePrice from t where LotFrontage = 0N

/LotFrontage nulls have no effect on avg SalePrice, though 30% increase on LotArea avg, 10% on LotArea med
/Replace null values with median
medfrontage:med exec LotFrontage from t
t:update medfrontage^LotFrontage from t

/explore garage data

select avg SalePrice from t where GarageType = `NA
5#select GarageType, GarageFinish, GarageCars, GarageArea, GarageQual, GarageCond from t where GarageYrBlt  = 0N

select avg SalePrice from t where (GarageType = `NA)=0b
5#select GarageType, GarageFinish, GarageCars, GarageArea, GarageQual, GarageCond from t where (GarageYrBlt  = 0N)=0b

//GarageType nulls = no garage, clearly have a depressing effect on sale price.
//we fill with 1910, some of oldest 
update GarageYrBlt:1910f from `t where GarageYrBlt = 0n

/
Feature Engineering:
I need to replace categorical variables with "dummy variables" 0 and 1, ordinal variables with a scale
Note: ordinal variables will have an equal distance imposed on them, though this is likely appropriate for most variables

Related Info:
GARAGE INFO: GarageType, GarageFinish, GarageCars, GarageArea, GarageQual, GarageCond, GarageYrBlt  
BASEMENT INFO: BsmtFinSF1,BsmtFinSF2,BsmtUnfSF,TotalBsmtSF,BsmtFullBath,BsmtHalfBath,
BsmtQual,BsmtCond,BsmtExposure,BsmtFinType1,BsmtFinType2 
\
categoricalColumns:`MSSubClass`MSZoning`Street`Alley`LotShape`LandContour`Utilities`LotConfig`LandSlope`Neighborhood`Condition1`Condition2`BldgType`HouseStyle`RoofStyle`RoofMatl`Exterior1st`Exterior2nd`MasVnrType`Foundation`Heating`CentralAir`Electrical`GarageType`GarageFinish`PavedDrive`MiscFeature`SaleType`SaleCondition
ordinalColumns:`OverallQual`OverallCond`ExterQual`ExterCond`BsmtQual`BsmtCond`BsmtExposure`BsmtFinType1`BsmtFinType2`HeatingQC`KitchenQual`Functional`FireplaceQu`GarageQual`GarageCond`PoolQC`Fence
continuousColumns:`SalePrice`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`LowQualFinSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`Bedroom`Kitchen`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`OpenPorchSF`EnclosedPorch`3SsnPorch`ScreenPorch`PoolArea`MiscVal`MoSold`YrSold
//BsmtQual,BsmtCond,BsmtExposure,BsmtFinType1,BsmtFinType2 have 0 (no basement) as lowest rank, this will mess with our equidistance scale measure
//FireplaceQu,GarageQual,GarageCond,PoolQC,Fence also has 0 rank for none
//Binary Categorical needs 1 dummy column instead of 2
binaryColumn:`CentralAir
//AdditiveCategory: flat value the misc feature adds to house. Perhaps subtract from Sale Price and delete?
AdditiveColumn:`MiscVal
uselessColumn:`MoSold
otherColumn:`Id
//`YrSold`SaleCondition deserves more digging into
//Possible feature engineering:YearBuilt YearRemodAdd | BsmtFinSF1 BsmtFinSF2 BsmtUnfSF TotalBsmtSF | all the square feet types | Fireplaces FireplaceQu | PoolArea  PoolQC | SalePrice YrSold
//`Functional has the potential to throw everything off, especially if house is: Salvage Only 
//check columns are correct
(count cols t) ~ (count categoricalColumns) + (count ordinalColumns) + (count continuousColumns) + (count otherColumn)

//MiscFeature and MiscVal are easy to deal with. We subtract MiscValue from SalePrice and delete both columns
t:update SalePrice:SalePrice-MiscVal from t
t:delete MiscFeature,MiscVal from t

select SalePrice by Functional from t 
//examine Sev
//We add a 0.5 penalty to Basement SF, add to GrLivArea for PPSF
select PPSF:SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Sev
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional = `Sev, (GrLivArea+TotalBsmtSF*0.5) <3390,(GrLivArea+TotalBsmtSF*0.5) >2390
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional= `Typ,  (GrLivArea+TotalBsmtSF*0.5) <3190,(GrLivArea+TotalBsmtSF*0.5) >2590
//examine Maj2
select PPSF: SalePrice%(GrLivArea+TotalBsmtSF*0.5), (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Maj2 
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where (GrLivArea+TotalBsmtSF*0.5) <1750,(GrLivArea+TotalBsmtSF*0.5) >1350 , Functional =`Typ
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where (GrLivArea+TotalBsmtSF*0.5) <2471,(GrLivArea+TotalBsmtSF*0.5) >1871 , Functional =`Typ
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where (GrLivArea+TotalBsmtSF*0.5) <2388,(GrLivArea+TotalBsmtSF*0.5) >1788 , Functional =`Typ
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where (GrLivArea+TotalBsmtSF*0.5) <1064,(GrLivArea+TotalBsmtSF*0.5) >664 , Functional =`Typ
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where (GrLivArea+TotalBsmtSF*0.5) <1733,(GrLivArea+TotalBsmtSF*0.5) >1333 , Functional =`Typ
//examine Maj1, Mod, Min1, Min2
select Maj1PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Maj1
select ModPPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Mod
select Min2PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Min2
select Min1PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Min1
select TypPPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t where Functional =`Typ

//By examining Functional variable, we see this has a consistent %based penalty on SalePrice 
//We have no Salvage only data, but get penalty coefficients Sev=.50, Maj2=.60, Maj1=.72, Mod=.79, Min2=.79, Min1=.78

//By examining the Functional variable, we see this has a consistent %based penalty on SalePrice 
//We estimate penalty coefficients Sev=.5, Maj2=.60, Maj1=.72, Mod=.79, Min2=.79, Min1=.83, Typ=1
//This shows us the danger of equidistance scaling of ordinal data.
//We have no Salvage only data, but estimmate .35 as a coefficient and normalize all data to Typical
functionalDict:(`Sal`Sev`Maj2`Maj1`Mod`Min2`Min1`Typ)!(0.35,0.5,0.60,0.72,0.79,0.79,0.83,1)
t:update Functional:functionalDict(Functional) from t
10#select SalePrice from t where Functional<>1
t:update SalePrice:SalePrice%Functional from t
10#select SalePrice from t where Functional<>1
t:delete Functional from t
count cols t

//We Now look at MoSold, YrSold. We combine the two for a new feature: DateSold
t:update DateSold:(`month$(12*-2000+ exec YrSold from t)+-1+exec MoSold from t) from t
5#select YrSold,MoSold,DateSold from t
t:delete YrSold,MoSold from t

//examine ordinary housing market, SalePrice < $350,000 by year
select PPSF: avg SalePrice%GrLivArea, avg  GrLivArea, avg SalePrice from t where SalePrice <350000, DateSold>2006.01m, DateSold<2006.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg  SalePrice from t where SalePrice <350000, DateSold>2007.01m, DateSold<2007.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice <350000, DateSold>2008.01m, DateSold<2008.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice <350000, DateSold>2009.01m, DateSold<2009.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice <350000, DateSold>2010.01m, DateSold<2010.12m
//examine Luxury housing market, SalePrice > $350,000 by year
"Luxury"
select PPSF: avg SalePrice%GrLivArea, avg  GrLivArea, avg SalePrice from t where SalePrice >350000, DateSold>2006.01m, DateSold<2006.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg  SalePrice from t where SalePrice >350000, DateSold>2007.01m, DateSold<2007.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice >350000, DateSold>2008.01m, DateSold<2008.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice >350000, DateSold>2009.01m, DateSold<2009.12m
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea, avg SalePrice from t where SalePrice >350000, DateSold>2010.01m, DateSold<2010.12m

//We conclude that DateSold has no meaningful contribution to the data
t:delete DateSold from t

//Next we explore SaleCondition
select avg SalePrice,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea by SaleCondition from t  
flip select from t where SaleCondition = `AdjLand
select avg SalePrice,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where BldgType = `Duplex
select avg SalePrice,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where BldgType = `1Fam
select avg SalePrice,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where Neighborhood = `Edwards
select avg SalePrice,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t 

//Explore SaleCondition=`Partial by controlling for Yearbuilt
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg YearBuilt from t where SaleCondition=`Partial
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg YearBuilt from t where SaleCondition=`Normal, YearBuilt>1997



//Partial is associated with New Homes, explaining the premium. SaleType=`New and Yearbuilt will add our premiums for us
//AdjLand is associated with Neighborhood=Edwards, BldgType=Duplex,so no penalty
//Alloca is associated with Duplexes, which as a lower price per square foot, so no penalty
// Abnorm1, Family are associated with buying property cheaply, so we apply penalties.
SaleConditionDict:(`Abnorml`AdjLand`Alloca`Family`Normal`Partial)!(0.88,1,1,0.87,1,1)

t:update SaleCondition:SaleConditionDict(exec SaleCondition from t) from t
10#select SalePrice,SaleCondition from t where SaleCondition<>1
t:update SalePrice:SalePrice%SaleCondition from t
10#select SalePrice from t where SaleCondition<>1
t:delete SaleCondition from t
count cols t

//Investigate YearBuilt, YearRemodAdd
plt.xlabel"Remodel Date";
plt.ylabel"SalePrice";
plt.title"Remodel";
plt.grid 1b;
plt.scatter[exec YearRemodAdd from t where YearRemodAdd<>YearBuilt;  exec SalePrice from t where YearRemodAdd<>YearBuilt]
plt.show[];
select avg YearRemodAdd, avg SalePrice, PPSF: avg SalePrice%GrLivArea from t where YearRemodAdd<>YearBuilt

plt.xlabel"YearBuilt";
plt.ylabel"SalePrice";
plt.title"No Remodel";
plt.grid 1b;
plt.scatter[exec YearBuilt from t where YearRemodAdd=YearBuilt; exec SalePrice from t where YearRemodAdd=YearBuilt]
plt.show[];
select avg YearRemodAdd, avg SalePrice, PPSF: avg SalePrice%GrLivArea from t where YearRemodAdd=YearBuilt

plt.xlabel"Year Built";
plt.ylabel"PPSF Both";
plt.title"PPSF no remodel";
plt.grid 1b;
plt.scatter[raze exec YearBuilt from t where YearRemodAdd=YearBuilt; raze exec PPSF:SalePrice%GrLivArea from t where YearRemodAdd=YearBuilt]
plt.show[];


plt.xlabel"YearRemodAdd";
plt.ylabel"PPSF Both";
plt.title"PPSF Remodel";
plt.grid 1b;
plt.scatter[raze exec YearRemodAdd from t where YearRemodAdd<>YearBuilt;  raze exec PPSF:SalePrice%GrLivArea from t where YearRemodAdd<>YearBuilt]
plt.show[];


//YearRemodAdd censors YearBuilt where houses are built before 1950


//We now explore garage data
//GARAGE INFO: GarageType, GarageFinish, GarageCars, GarageArea, GarageQual, GarageCond, GarageYrBlt  
plt.xlabel"Garage Year Built";
plt.ylabel"SalePrice";
plt.title"Garage Year Built";
plt.grid 1b;
plt.scatter[exec GarageYrBlt from t; exec SalePrice from t]
plt.show[];

plt.xlabel"None               One               Two               Three               Four";
plt.ylabel"SalePrice";
plt.title"Garage Cars";
plt.boxplot[(exec SalePrice from t where GarageCars=0;exec SalePrice from t where GarageCars=1;exec SalePrice from t where GarageCars=2;exec SalePrice from t where GarageCars=3;exec SalePrice from t where GarageCars=4)]
plt.show[];

plt.xlabel"   NA       Detchd      CarPort      BuiltIn    Basment     Attchd     2Types";
plt.ylabel"SalePrice";
plt.title"Garage Type";
plt.boxplot[(exec SalePrice from t where GarageType=`NA;exec SalePrice from t where GarageType=`Detchd;exec SalePrice from t where GarageType=`CarPort;exec SalePrice from t where GarageType=`BuiltIn;exec SalePrice from t where GarageType=`Basment;exec SalePrice from t where GarageType=`Attchd;exec SalePrice from t where GarageType=`2Types)]
plt.show[];

plt.xlabel"NA                       Unf                       RFn                       Fin";
plt.ylabel"SalePrice";
plt.title"Garage Finish";
plt.grid 1b;
plt.boxplot[(exec SalePrice from t where GarageFinish=`NA;exec SalePrice from t where GarageFinish=`Unf;exec SalePrice from t where GarageFinish=`RFn;exec SalePrice from t where GarageFinish=`Fin)]
plt.show[];

plt.xlabel"NA               Po               Fa               TA               Gd               Ex";
plt.ylabel"SalePrice";
plt.title"Garage Condition";
plt.grid 1b;
plt.boxplot[(exec SalePrice from t where GarageCond=`NA;exec SalePrice from t where GarageCond=`Po;exec SalePrice from t where GarageCond=`Fa;exec SalePrice from t where GarageCond=`TA;exec SalePrice from t where GarageCond=`Gd;exec SalePrice from t where GarageCond=`Ex)]
plt.show[];

plt.xlabel"NA               Po               Fa               TA               Gd               Ex";
plt.ylabel"SalePrice";
plt.title"Garage Quality";
plt.grid 1b;
plt.boxplot[(exec SalePrice from t where GarageQual=`NA;exec SalePrice from t where GarageQual=`Po;exec SalePrice from t where GarageQual=`Fa;exec SalePrice from t where GarageQual=`TA;exec SalePrice from t where GarageQual=`Gd;exec SalePrice from t where GarageQual=`Ex)]
plt.show[];

plt.xlabel"Garage Area";
plt.ylabel"SalePrice";
plt.title"Garage Area";
plt.grid 1b;
plt.scatter[exec GarageArea from t;exec SalePrice from t]
plt.show[];

//GarageCond and GarageQual are ordinal, but dip towards the end. I will cluster and hot encode the variables
update GarageCondGood:1 from `t where (GarageCond=`TA)or (GarageCond=`Ex)or (GarageCond=`Gd)
update GarageCondGood:0 from `t where (GarageCond=`Fa) or (GarageCond=`NA)or (GarageCond=`Po)
delete GarageCond from `t

update GarageQualGood:1 from `t where (GarageQual=`TA)or (GarageQual=`Ex)or (GarageQual=`Gd)
update GarageQualGood:0 from `t where (GarageQual=`Fa) or (GarageQual=`NA)or (GarageQual=`Po)
delete GarageQual from `t



plt.xlabel"Garage Quality";
plt.ylabel"SalePrice";
plt.title"Garage Quality";
plt.boxplot[(exec SalePrice from t where GarageQualGood=0;exec SalePrice from t where GarageQualGood=1)]
plt.show[];

plt.xlabel"Garage Condition";
plt.ylabel"SalePrice";
plt.title"Garage Condition";
plt.boxplot[(exec SalePrice from t where GarageCondGood=0;exec SalePrice from t where GarageCondGood=1)]
plt.show[];

//Granted, this binning shows SalePrice of homes with no garage packed in with the poor Garages. 
//We will split housing data into Garage/No Garage later

//Check Utilities
select Utilities from t where Utilities <> `AllPub
flip select from t where Utilities <> `AllPub
select PPSF:SalePrice%GrLivArea from t where Utilities <> `AllPub
select PPSF:avg SalePrice % GrLivArea from t 


//Since Utilities only has one deviant which seemingly has no effect on Price Per Square Foot, we delete the category
t:delete Utilities from t
flip select from t where Street <>`Pave
select PPSF:avg SalePrice%GrLivArea from t where Street <>`Pave
select PPSF:avg SalePrice%GrLivArea from t where Street =`Pave
select PPSF:avg SalePrice%GrLivArea from t where YearRemodAdd <1970

//Although houses with Gravel streets have a lower PPSF, they have an underlying variable of being old. We will delete Street
t:delete Street from t

//explore BedroomAbvGr 
plt.xlabel"BedroomAbvGr";
plt.ylabel"SalePrice";
plt.title"BedroomAbvGr";
plt.grid 1b;
plt.scatter[exec BedroomAbvGr from t;exec SalePrice from t]
plt.show[];


//explore Porch data
//select statement doesn't like 3SsnPorch because it begins with a number
/(`OpenPorchSF`EnclosedPorch`3SsnPorch`ScreenPorch)#t
plt.xlabel"OpenPorchSF";
plt.ylabel"SalePrice";
plt.title"OpenPorchSF";
plt.grid 1b;
plt.scatter[exec OpenPorchSF from t;exec SalePrice from t]
plt.show[];

plt.xlabel"EnclosedPorch";
plt.ylabel"SalePrice";
plt.title"EnclosedPorch";
plt.grid 1b;
plt.scatter[exec EnclosedPorch from t;exec SalePrice from t]
plt.show[];

plt.xlabel"3SsnPorch";
plt.ylabel"SalePrice";
plt.title"3SsnPorch";
plt.grid 1b;
plt.scatter[(flip (`3SsnPorch`ScreenPorch)#t)(`3SsnPorch); exec SalePrice from t]
plt.show[];

plt.xlabel"ScreenPorch";
plt.ylabel"SalePrice";
plt.title"ScreenPorch";
plt.grid 1b;
plt.scatter[exec ScreenPorch from t;exec SalePrice from t]
plt.show[];

//We sum all the porch data together for a new variable

t:update PorchSQFT:sum(exec OpenPorchSF from t;exec EnclosedPorch from t;(flip (`3SsnPorch`ScreenPorch)#t)(`3SsnPorch);exec ScreenPorch from t) from t
plt.xlabel"PorchSQFT";
plt.ylabel"SalePrice";
plt.title"Total Porch SQFT";
plt.grid 1b;
plt.scatter[exec PorchSQFT from t;exec SalePrice from t]
plt.show[];

t:flip (flip t)_(`3SsnPorch)
t:delete ScreenPorch,EnclosedPorch,OpenPorchSF from t
count select from t where PorchSQFT<>0


//explore 1st and 2nd floor data 

plt.xlabel"1st floor SF";
plt.ylabel"SalePrice";
plt.title"1st floor SF";
plt.grid 1b;
plt.scatter[t[`1stFlrSF];exec SalePrice from t]
plt.show[];

plt.xlabel"2nd floor SF";
plt.ylabel"SalePrice";
plt.title"2nd floor SF";
plt.grid 1b;
plt.scatter[t[`2ndFlrSF];exec SalePrice from t]
plt.show[];

((exec LowQualFinSF from t)+(t[`2ndFlrSF]+t[`1stFlrSF])) ~ (exec GrLivArea from t)
//LowQualFinSF + 2ndFlrSF + 1stFlrSF = GrLivArea


plt.xlabel"LowQualFinSF";
plt.ylabel"SalePrice";
plt.title"Low Qual Finished SF (all floors)";
plt.grid 1b;
plt.scatter[exec LowQualFinSF from t ;exec SalePrice from t]
plt.show[];

plt.xlabel"Total Finished SF";
plt.ylabel"SalePrice";
plt.title"Total Finished SF";
plt.grid 1b;
plt.scatter[t[`2ndFlrSF] +t[`1stFlrSF] ;exec SalePrice from t]
plt.show[];

plt.xlabel"Total GrLivArea SF";
plt.ylabel"SalePrice";
plt.title"Total GrLivArea SF";
plt.grid 1b;
plt.scatter[exec GrLivArea from t ;exec SalePrice from t]
plt.show[];



//the premium on space on second floor is likely caused by lurking varibles, such as location
//Due to the high number of 0s, 2ndFlrSF may be misleading
//LowQualFinSF does not have correlation with Price, I will delete
//because GrLivArea is simply addition of two columns, we may consider deleting after data analysis

/update GrLivArea: GrLivArea - LowQualFinSF from `t;
delete LowQualFinSF from `t


//zoom in on the two bottom outliers
flip select from t where GrLivArea > 4000,SalePrice<300000

//On paper, these should be very expensive houses. We will delete the outliers
delete from `t where  Id =524
delete from `t where  Id =1299
count t

//explore House Style, Neighborhood
plt.ylabel"SalePrice";
plt.xlabel"1Story     1.5Fin    1.5Unf    2Story    2.5Fin    2.5Unf    SFoyer    SLvl";
plt.title"House Style";
plt.boxplot[(exec SalePrice from t where HouseStyle=`1Story;exec SalePrice from t where HouseStyle=`1.5Fin;exec SalePrice from t where HouseStyle=`1.5Unf;exec SalePrice from t where HouseStyle=`2Story;exec SalePrice from t where HouseStyle=`2.5Fin;exec SalePrice from t where HouseStyle=`2.5Unf;exec SalePrice from t where HouseStyle=`SFoyer;exec SalePrice from t where HouseStyle=`SLvl)]
plt.show[];

plt.ylabel"PPSF";
plt.xlabel"1Story     1.5Fin    1.5Unf    2Story    2.5Fin    2.5Unf    SFoyer    SLvl";
plt.title"Price Per Square Foot";
plt.boxplot[(exec SalePrice%GrLivArea from t where HouseStyle=`1Story;exec SalePrice%GrLivArea from t where HouseStyle=`1.5Fin;exec SalePrice%GrLivArea from t where HouseStyle=`1.5Unf;exec SalePrice%GrLivArea from t where HouseStyle=`2Story;exec SalePrice%GrLivArea from t where HouseStyle=`2.5Fin;exec SalePrice%GrLivArea from t where HouseStyle=`2.5Unf;exec SalePrice%GrLivArea from t where HouseStyle=`SFoyer;exec SalePrice%GrLivArea from t where HouseStyle=`SLvl)]
plt.show[];
select Total:(count Id) by HouseStyle from t
select PPSF: avg SalePrice%GrLivArea, avg GrLivArea by HouseStyle from t



//We will cluster lower observation columns based on PPSF
//1.5Unf, 2.5Fin, 2.5Unf joins 2Story, 
update HouseStyle:`2Story from `t where HouseStyle=`1.5Unf
update HouseStyle:`2Story from `t where HouseStyle=`2.5Fin
update HouseStyle:`2Story from `t where HouseStyle=`2.5Unf

//Neighborhood data 
`SalePrice xasc select avg SalePrice,PPSF: avg SalePrice%GrLivArea  by Neighborhood from t


plt.ylabel"SalePrice";
plt.xlabel"";
plt.title"Price by Neighborhood";
plt.boxplot[(exec SalePrice from t where Neighborhood=`MeadowV;exec SalePrice from t where Neighborhood=`IDOTRR;exec SalePrice from t where Neighborhood=`BrDale;exec SalePrice from t where Neighborhood=`BrkSide;exec SalePrice from t where Neighborhood=`Edwards;exec SalePrice from t where Neighborhood=`OldTown;exec SalePrice from t where Neighborhood=`Blueste;exec SalePrice from t where Neighborhood=`NPkVill;exec SalePrice from t where Neighborhood=`Sawyer;exec SalePrice from t where Neighborhood=`NAmes;exec SalePrice from t where Neighborhood=`SWISU;exec SalePrice from t where Neighborhood=`Mitchel;exec SalePrice from t where Neighborhood=`SawyerW;exec SalePrice from t where Neighborhood=`Gilbert;exec SalePrice from t where Neighborhood=`Blmngtn;exec SalePrice from t where Neighborhood=`NWAmes;exec SalePrice from t where Neighborhood=`CollgCr;exec SalePrice from t where Neighborhood=`Crawfor;exec SalePrice from t where Neighborhood=`Somerst;exec SalePrice from t where Neighborhood=`ClearCr;exec SalePrice from t where Neighborhood=`Veenker;exec SalePrice from t where Neighborhood=`Timber;exec SalePrice from t where Neighborhood=`NridgHt;exec SalePrice from t where Neighborhood=`StoneBr;exec SalePrice from t where Neighborhood=`NoRidge)]
plt.show[];

`Total xasc select Total:(count Id) by Neighborhood from t


//Cluster the groups where number  of observations is too low
//(Blueste,OldTown)(NPkVill,Sawyer)(Veenker,Timber)(BrDale,IDOTRR)(Blmngtn,CollgCr)
//(MeadowV,IDOTRR)(SWISU,NAmes)(StoneBr,NridgHt)(ClearCr,Somerst)
update Neighborhood:`OldTown from `t where Neighborhood=`Blueste
update Neighborhood:`Sawyer from `t where Neighborhood=`NPkVill;
update Neighborhood:`Timber from `t where Neighborhood=`Veenker;
update Neighborhood:`IDOTRR from `t where Neighborhood=`BrDale;
update Neighborhood:`CollgCr from `t where Neighborhood=`Blmngtn;
update Neighborhood:`IDOTRR from `t where Neighborhood=`MeadowV;
update Neighborhood:`NAmes from `t where Neighborhood=`SWISU;
update Neighborhood:`NridgHt from `t where Neighborhood=`StoneBr;
update Neighborhood:`Somerst from `t where Neighborhood=`ClearCr;



`SalePrice xasc select avg SalePrice,PPSF: avg SalePrice%GrLivArea  by Neighborhood from t


plt.ylabel"SalePrice";
plt.xlabel"";
plt.title"Price by Neighborhood";
plt.boxplot[(exec SalePrice from t where Neighborhood=`IDOTRR;exec SalePrice from t where Neighborhood=`BrkSide;exec SalePrice from t where Neighborhood=`Edwards;exec SalePrice from t where Neighborhood=`OldTown;exec SalePrice from t where Neighborhood=`Sawyer;exec SalePrice from t where Neighborhood=`NAmes;exec SalePrice from t where Neighborhood=`Mitchel;exec SalePrice from t where Neighborhood=`SawyerW;exec SalePrice from t where Neighborhood=`Gilbert;exec SalePrice from t where Neighborhood=`NWAmes;exec SalePrice from t where Neighborhood=`CollgCr;exec SalePrice from t where Neighborhood=`Crawfor;exec SalePrice from t where Neighborhood=`Somerst;exec SalePrice from t where Neighborhood=`Timber;exec SalePrice from t where Neighborhood=`NridgHt;exec SalePrice from t where Neighborhood=`NoRidge)]
plt.show[];

plt.ylabel"PPSF";
plt.xlabel"";
plt.title"PPSF by Neighborhood";
plt.boxplot[(exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`IDOTRR;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`BrkSide;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Edwards;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`OldTown;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Sawyer;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`NAmes;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Mitchel;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`SawyerW;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Gilbert;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`NWAmes;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`CollgCr;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Crawfor;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Somerst;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`Timber;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`NridgHt;exec SalePrice%((.5 * TotalBsmtSF) + GrLivArea + (.2 * GarageArea)) from t where Neighborhood=`NoRidge)]
plt.show[];


`Total xasc select Total:(count Id) by Neighborhood from t

//explore Basement data
//BsmtFinSF1,BsmtFinSF2,BsmtUnfSF,TotalBsmtSF,BsmtFullBath,BsmtHalfBath, 
//BsmtQual,BsmtCond,BsmtExposure,BsmtFinType1,BsmtFinType2 
`BsmtFinType1 xasc select avg SalePrice by BsmtFinType1 from t

plt.ylabel"SalePrice";
plt.xlabel"NA           Unf          LwQ          Rec          BLQ          ALQ          GLQ";
plt.title"BsmtFinType1";
plt.boxplot[(exec SalePrice from t where BsmtFinType1=`NA;exec SalePrice from t where BsmtFinType1=`Unf;exec SalePrice from t where BsmtFinType1=`LwQ;exec SalePrice from t where BsmtFinType1=`Rec;exec SalePrice from t where BsmtFinType1=`BLQ;exec SalePrice from t where BsmtFinType1=`ALQ;exec SalePrice from t where BsmtFinType1=`GLQ)]
plt.show[];


plt.ylabel"SalePrice";
plt.xlabel"NA           Unf          LwQ          Rec          BLQ          ALQ          GLQ";
plt.title"BsmtFinType2";
plt.boxplot[(exec SalePrice from t where BsmtFinType2=`NA;exec SalePrice from t where BsmtFinType2=`Unf;exec SalePrice from t where BsmtFinType2=`LwQ;exec SalePrice from t where BsmtFinType2=`Rec;exec SalePrice from t where BsmtFinType2=`BLQ;exec SalePrice from t where BsmtFinType2=`ALQ;exec SalePrice from t where BsmtFinType2=`GLQ)]
plt.show[];
//Clearly BsmtFinType1,BsmtFinType2 is not properly distance ordinal data, we will hot encode later


//examine BsmtFinSF1,BsmtFinSF2

plt.xlabel"BsmtFinSF1";
plt.ylabel"SalePrice";
plt.title"BsmtFinSF1";
plt.grid 1b;
plt.scatter[exec BsmtFinSF1 from t;exec SalePrice from t]
plt.show[];

plt.xlabel"BsmtFinSF2";
plt.ylabel"SalePrice";
plt.title"BsmtFinSF2";
plt.grid 1b;
plt.scatter[exec BsmtFinSF2 from t;exec SalePrice from t]
plt.show[];

plt.xlabel"BsmtFinSF1";
plt.ylabel"SalePrice";
plt.title"Total Finished SF";
plt.grid 1b;
plt.scatter[exec BsmtFinSF1+BsmtFinSF2 from t;exec SalePrice from t]
plt.show[];


plt.xlabel"BsmtUnfSF";
plt.ylabel"SalePrice";
plt.title"Basement Unfinished SF";
plt.grid 1b;
plt.scatter[exec BsmtUnfSF from t;exec SalePrice from t]
plt.show[];

plt.xlabel"TotalBsmtSF";
plt.ylabel"SalePrice";
plt.title"Total Basement SF";
plt.grid 1b;
plt.scatter[exec TotalBsmtSF from t;exec SalePrice from t]
plt.show[];

//Basement SF is kept out of GrLivArea, but still adds value

plt.xlabel"total SF with 0.5 basement penalty";
plt.ylabel"SalePrice";
plt.title"SalePrice by total SF, .5 basement penalty";
plt.grid 1b;
plt.scatter[(0.5 * exec TotalBsmtSF from t)+(exec GrLivArea from t);exec SalePrice from t]
plt.show[];

basementPenalty:0.5
plt.xlabel"Total SF with 0.5 basement penalty";
plt.ylabel"PPSF";
plt.title"PPSF, .5 basement penalty";
plt.grid 1b;

plt.scatter[(basementPenalty * exec TotalBsmtSF from t)+(exec GrLivArea from t);(exec SalePrice%((basementPenalty * TotalBsmtSF)+(GrLivArea)) from t)]
plt.show[];

//We are looking for a circle in the last scatterplot. After adjusting for quality, hyperparameters, should be close
//We can come back later. We have a similar problem for garage, 2nd story, porch, etc. 


//Investigate LandSlope:
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg SalePrice,  avg LotArea by LandSlope from t
select from t where LandSlope=`Sev
select LotArea,Neighborhood,(GrLivArea+TotalBsmtSF*0.5),SalePrice , SalePrice%(GrLivArea+TotalBsmtSF*0.5)from t where LandSlope=`Sev

//apparenty LandSlope is tied to LotArea, Neighborhood.

//Look at Roof Material
`Total xasc select Total:(count Id) by RoofMatl from t
select PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg(GrLivArea+TotalBsmtSF*0.5),avg SalePrice by RoofMatl from t 
//there are definate benefits to Membran, Metal, possibly WdShingl, with a discount for Roll
//investigate houses similar to one with Membran:
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5),avg SalePrice from t where Neighborhood = `Somerst ,(GrLivArea+TotalBsmtSF*0.5) <2355,(GrLivArea+TotalBsmtSF*0.5) >1755 , RoofMatl =`CompShg


//Investigate Membrane Roof House
flip select from t where RoofMatl = `Membran
select avg LotArea from t
//Membran SQFT is explained by lot area, no premium, we cluster that with CompShg 
update RoofMatl:`CompShg from `t where RoofMatl=`Membran 

//investigate Metal Roof House
flip select from t where RoofMatl = `Metal
//twice the LotArea, in a nice Neighborhood
select PPSF: SalePrice%(GrLivArea+TotalBsmtSF*0.5),  (GrLivArea+TotalBsmtSF*0.5),  SalePrice , LotArea from t where OverallQual>4,OverallQual<8,(GrLivArea+TotalBsmtSF*0.5) <1757,(GrLivArea+TotalBsmtSF*0.5) >1157 , Neighborhood=`Somerst,RoofMatl =`CompShg

//Investigate Roll Roof House
//Discounts: RoofMatl=Roll :57/70
flip select from t where RoofMatl = `Roll
select PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg  (GrLivArea+TotalBsmtSF*0.5),avg   SalePrice , avg LotArea from t where OverallQual>3,OverallQual<7,(GrLivArea+TotalBsmtSF*0.5) <2684,(GrLivArea+TotalBsmtSF*0.5) >2084 , Neighborhood=`NAmes,RoofMatl =`CompShg


//premiums:RoofMatl=Metal : 123/104 = 1.18
//Discounts: RoofMatl=Roll :57/70=0.81
//We scale everything to same roof material and delete the column
select SalePrice from t where RoofMatl=`Metal
t:update SalePrice:SalePrice%1.18 from t where RoofMatl=`Metal
select SalePrice from t where RoofMatl=`Metal

select SalePrice from t where RoofMatl=`Roll
t:update SalePrice:SalePrice%0.81 from t where RoofMatl=`Roll
select SalePrice from t where RoofMatl=`Roll

t:delete RoofMatl from t
count cols t


//Explore Exterior1st and Exterior2nd

plt.ylabel"SalePrice";
plt.xlabel"Exterior1st";
plt.title"Exterior1st";
plt.boxplot[(exec SalePrice from t where Exterior1st=`AsbShng;exec SalePrice from t where Exterior1st=`AsphShn;exec SalePrice from t where Exterior1st=`BrkComm;exec SalePrice from t where Exterior1st=`BrkFace;exec SalePrice from t where Exterior1st=`CBlock;exec SalePrice from t where Exterior1st=`CemntBd;exec SalePrice from t where Exterior1st=`HdBoard;exec SalePrice from t where Exterior1st=`ImStucc;exec SalePrice from t where Exterior1st=`MetalSd;exec SalePrice from t where Exterior1st=`Other;exec SalePrice from t where Exterior1st=`Plywood;exec SalePrice from t where Exterior1st=`PreCast;exec SalePrice from t where Exterior1st=`Stone;exec SalePrice from t where Exterior1st=`Stucco;exec SalePrice from t where Exterior1st=`VinylSd;exec SalePrice from t where Exterior1st=`WdShing)]
plt.show[];

select PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg (GrLivArea+TotalBsmtSF*0.5),avg SalePrice by Exterior1st from t 

plt.ylabel"SalePrice";
plt.xlabel"Exterior2nd";
plt.title"Exterior2nd";
plt.boxplot[(exec SalePrice from t where Exterior2nd=`AsbShng;exec SalePrice from t where Exterior2nd=`AsphShn;exec SalePrice from t where Exterior2nd=`BrkComm;exec SalePrice from t where Exterior2nd=`BrkFace;exec SalePrice from t where Exterior2nd=`CBlock;exec SalePrice from t where Exterior2nd=`CemntBd;exec SalePrice from t where Exterior2nd=`HdBoard;exec SalePrice from t where Exterior2nd=`ImStucc;exec SalePrice from t where Exterior2nd=`MetalSd;exec SalePrice from t where Exterior2nd=`Other;exec SalePrice from t where Exterior2nd=`Plywood;exec SalePrice from t where Exterior2nd=`PreCast;exec SalePrice from t where Exterior2nd=`Stone;exec SalePrice from t where Exterior2nd=`Stucco;exec SalePrice from t where Exterior2nd=`VinylSd;exec SalePrice from t where Exterior2nd=`WdShing)]
plt.show[];

select PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5),avg (GrLivArea+TotalBsmtSF*0.5),avg SalePrice by Exterior2nd from t 

//Intuitively, there is a premium on having 2 different coverings on the exterior
//Notice, the name "WdShing" on External1st does not match "Wd Shng" on Exterior2nd
//however, which second covering does not likely matter. We can replace Exterior2nd with a binary variable
count select Exterior2nd from t where Exterior2nd<>Exterior1st //214
count raze(value -1#select Id by Exterior2nd from t)[`Id] 
//38 "Wd Shng" on Exterior2nd
select Id, Exterior2nd from t where Exterior1st = `WdShing
/duplicates are Id 12, 54, 128, 174,  176, 394, 414, 444, 563, 572, 750, 803, 873, 1029, 1113, 1385, 1400, 1401
update Exterior2:1 from `t where Exterior2nd<>Exterior1st
update Exterior2:0 from `t where Exterior2nd=Exterior1st

{[x]update Exterior2:0 from `t where Id=x} each (12 54 128 174  176 394 414 444 563 572 750 803 873 1029 1113 1385 1400 1401)
10#select Id, Exterior1st, Exterior2nd from t where Exterior2=1
//More duplicates from mispellings:Id 24 76 109 190 197 262 279 305 306 317 345 350 358 378 400 411 422 435 475 490 491 516 523 592 615 619 645 650 651 674 725 731 794 818 826 876 916 974 981 984 995 1001 1008 1039 1040 1047 1061 1069 1087 1182 1218 1220 1289 1292 1368 1375 1406 1450 1452 1458
{[x]update Exterior2:0 from `t where Id=x} each 24 76 109 190 197 262 279 305 306 317 345 350 358 378 400 411 422 435 475 490 491 516 523 592 615 619 645 650 651 674 725 731 794 818 826 876 916 974 981 984 995 1001 1008 1039 1040 1047 1061 1069 1087 1182 1218 1220 1289 1292 1368 1375 1406 1450 1452 1458
delete Exterior2nd from `t
update Exterior2nd:Exterior2 from `t
delete Exterior2 from `t
count select Exterior2nd from t where Exterior2nd=0
count select Exterior2nd from t where Exterior2nd=1

//Explore MasVnrArea
plt.xlabel"MasvnrArea";
plt.ylabel"SalePrice";
plt.title"MasvnrArea";
plt.grid 1b;
plt.scatter[exec MasVnrArea from t;exec SalePrice from t]
plt.show[];

//size is a lurking variable, with MasVnrType as the quality factor.
//Explore MasVnrType
plt.xlabel"MasvnrArea";
plt.ylabel"SalePrice";
plt.title"MasVnrType=BrkCmn";
plt.grid 1b;
plt.scatter[exec MasVnrArea from t where MasVnrType=`BrkCmn;exec SalePrice from t where MasVnrType=`BrkCmn]
plt.show[];

plt.xlabel"MasvnrArea";
plt.ylabel"SalePrice";
plt.title"MasVnrType=BrkFace";
plt.grid 1b;
plt.scatter[exec MasVnrArea from t where MasVnrType=`BrkFace;exec SalePrice from t where MasVnrType=`BrkFace]
plt.show[];

plt.xlabel"MasvnrArea";
plt.ylabel"SalePrice";
plt.title"MasVnrType=None";
plt.grid 1b;
plt.scatter[exec MasVnrArea from t where MasVnrType=`None;exec SalePrice from t where MasVnrType=`None]
plt.show[];

plt.xlabel"MasvnrArea";
plt.ylabel"SalePrice";
plt.title"MasVnrType=Stone";
plt.grid 1b;
plt.scatter[exec MasVnrArea from t where MasVnrType=`Stone;exec SalePrice from t where MasVnrType=`Stone]
plt.show[];


//Investigate PoolArea, PoolQC
plt.xlabel"Pool Area";
plt.ylabel"SalePrice";
plt.title"PoolArea";
plt.grid 1b;
plt.scatter[exec PoolArea from t;exec SalePrice from t ]
plt.show[];

plt.xlabel"Fa                                  Gd                                  Ex";
plt.ylabel"PoolQC";
plt.title"Garage Cars";
plt.boxplot[(exec SalePrice from t where PoolQC=`Fa;exec SalePrice from t where PoolQC=`Gd;exec SalePrice from t where PoolQC=`Ex)]
plt.show[];
//how manyof each PoolQC
select total:count Id  by PoolQC from t

//No correlation between Pool Area and SalePrice, we create a binary variable
//Not enough data for PoolQC to matter, we remove
update PoolArea:1.0 from `t where PoolArea<>0
delete PoolQC from `t

//Explore Condition1, Condition2
select avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5) from t
select total:count Id  by Condition1 from t
select avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5)  by Condition1 from t

select total:count Id  by Condition2 from t
select avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5)  by Condition2 from t
//normalize acccording to Condition1, 2


select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where Condition1=`Artery 
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg (GrLivArea+TotalBsmtSF*0.5), avg OverallQual from t where YearBuilt <1950 
//Artery condition coincides with old housing, low quality. We give 0.95 multiplier
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where Condition1=`Feedr 
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg OverallQual, avg YearBuilt from t where YearBuilt < 1960, YearBuilt > 1940
//Similar as Artery, give 0.95 multiplier
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where Condition1=`PosA 
flip select from t where  Condition1 = `PosA
//  7/8 these houses are in NAmes Neighborhood
select PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where Condition1=`Norm, Neighborhood=`NAmes, OverallQual>5, YearBuilt>1960
count select from t where Condition1=`Norm, Neighborhood=`NAmes, OverallQual>5, YearBuilt>1960
//By comparing applies to apples, there seems to be no premium on PosA. Multiplier = 1
select avg GrLivArea ,avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where  GrLivArea>1500,YearBuilt >1955, Condition1=`PosN 
select avg GrLivArea,avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg YearBuilt,  avg OverallQual, avg OverallCond from t where  GrLivArea>1500,YearBuilt >1955, Condition1=`Norm 
count select from t where GrLivArea>1500,YearBuilt >1955, Condition1=`PosN 
count select from t where GrLivArea>1500,YearBuilt >1955, Condition1=`Norm
//Counterintuitively, there seems to be a discount, although the sample size is 12 and too small to draw conclusions. 
//Multiplier will be 1.0

//Condition1
DictCondition1:(`Artery`Feedr`Norm`RRNn`RRAn`PosN`PosA`RRNe`RRAe)!(0.95,0.95,1,1,1,1,1,1,1)
update ScaleCondition1:DictCondition1(exec Condition1 from t) from `t
10#select SalePrice,ScaleCondition1 from t where ScaleCondition1<>1.0
update SalePrice:SalePrice%ScaleCondition1 from `t
10#select SalePrice from t where ScaleCondition1<>1
delete ScaleCondition1 from `t
delete Condition1 from `t

//Condition2
DictCondition2:(`Artery`Feedr`Norm`RRNn`RRAn`PosN`PosA`RRNe`RRAe)!(0.95,0.95,1,1,1,1,1,1,1)
update ScaleCondition2:DictCondition2(exec Condition2 from t) from `t
10#select SalePrice,ScaleCondition2 from t where ScaleCondition2<>1.0
update SalePrice:SalePrice%ScaleCondition2 from `t
10#select SalePrice from t where ScaleCondition2<>1
delete ScaleCondition2 from `t
delete Condition2 from `t

//explore Fence
plt.xlabel"   NA               MnWw              GdWo            MnPrv            GdPrv";
plt.ylabel"SalePrice";
plt.title"Fence";
plt.grid 1b;
plt.boxplot[(exec SalePrice from t where Fence=`NA;exec SalePrice from t where Fence=`MnWw;exec SalePrice from t where Fence=`GdWo;exec SalePrice from t where Fence=`MnPrv;exec SalePrice from t where Fence=`GdPrv)]
plt.show[];
select total:count Id  by Fence from t

//keep as ordinal

//Put CentralAir into binary
//need a function
.gmb.preprocessing.binaryScale:{[table;binaryList]
    //table -- table with only orindinal columns
    //binaryList -- binary list (any data type) of the binary features in desired order from 0 to 1
    //returns table with binary columns changed to 0 and 1
    uniqueList:distinct binaryList; //sanity check
    binaryDictionary:uniqueList!(0 1);
    :{@[x;y;:;z[x[y]]]}[table;;binaryDictionary]cols table;
 };
update CentralAir:(raze value flip .gmb.preprocessing.binaryScale[select CentralAir from t;`N`Y]) from `t



//Explore Heating

select total:count Id,PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg OverallCond, avg GrLivArea by Heating from t
//let's cluster into GasA and not GasA. There appears to be a premium on GasA, discount on everything else.
update HeatingType:1.0 from `t where Heating = `GasA
update HeatingType:0.0 from `t where Heating <> `GasA
delete Heating from `t
update Heating:HeatingType from `t
delete HeatingType from `t


//Explore Electrical
plt.xlabel" Mix               FuseP               FuseF               FuseA               SBrkr";
plt.ylabel"SalePrice";
plt.title"Electrical";
plt.grid 1b;
plt.boxplot[(exec SalePrice from t where Electrical=`Mix;exec SalePrice from t where Electrical=`FuseP;exec SalePrice from t where Electrical=`FuseF;exec SalePrice from t where Electrical=`FuseA;exec SalePrice from t where Electrical=`SBrkr)]
plt.show[];
`PPSF xasc select total:count Id, avg YearBuilt, avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg OverallCond, avg GrLivArea by Electrical from t
select PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5) from t where YearBuilt>2005
//The `NA house is a new house, no premium or discount
//`Mix is an old house, no premium or discount
//We cluster FuseP into FuseF and Mix,NA,FuseA together, make it ordinal
update Electrical:`FuseF from `t where Electrical = `FuseP
update Electrical:`FuseA from `t where Electrical = `NA
update Electrical:`FuseA from `t where Electrical = `Mix

//Explore SaleType
plt.xlabel"WD     CWD    VWD    New     COD    Con   ConLw   ConLI   ConLD   Oth";
plt.ylabel"SalePrice";
plt.title"Sale Type";
plt.boxplot[(exec SalePrice from t where SaleType=`WD;exec SalePrice from t where SaleType=`CWD;exec SalePrice from t where SaleType=`VWD;exec SalePrice from t where SaleType=`New;exec SalePrice from t where SaleType=`COD;exec SalePrice from t where SaleType=`Con;exec SalePrice from t where SaleType=`ConLw;exec SalePrice from t where SaleType=`ConLI;exec SalePrice from t where SaleType=`ConLD;exec SalePrice from t where SaleType=`Oth)]
plt.show[];
`PPSF xasc select total:count Id, avg YearBuilt, avg SalePrice, PPSF:avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg OverallCond, avg GrLivArea by SaleType from t
//There is a premium on New
//Some have low observations. We cluster some together (WD, CWD, Con) (ConLW,ConLI,ConLD,Oth)
update SaleType:`WD from `t where SaleType = `CWD
update SaleType:`WD from `t where SaleType = `Con
update SaleType:`ConLw from `t where SaleType = `ConLI
update SaleType:`ConLw from `t where SaleType = `ConLD
update SaleType:`ConLw from `t where SaleType = `Oth



plt.xlabel"Weighted LivArea,BsmtSF,GarageArea";
plt.ylabel"Weighted PPSF";
plt.title"PPSF";
plt.grid 1b;

plt.scatter[exec (GrLivArea+(TotalBsmtSF*0.5)+(GarageArea*0.2)) from t; exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t]
plt.show[];
//delete outliers
flip select from t where (SalePrice%(GrLivArea+(TotalBsmtSF*0.5)+(GarageArea*0.2)))<41,(SalePrice%(GrLivArea+(TotalBsmtSF*0.5)+(GarageArea*0.2)))>40
delete from `t where (SalePrice%(GrLivArea+(TotalBsmtSF*0.5)+(GarageArea*0.2)))<40
delete from `t where (SalePrice%(GrLivArea+(TotalBsmtSF*0.5)+(GarageArea*0.2)))>150

//check PPSF  by OverallQual
plt.xlabel"OverallQual";
plt.ylabel"PPSF";
plt.title"OverallQual";
plt.grid 1b;
plt.boxplot[(exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=1;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=2;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=3;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=4;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=5;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=6;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=7;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=8;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=9;exec SalePrice%((GarageArea*0.2)+GrLivArea+TotalBsmtSF*0.5) from t where OverallQual=10)]
plt.show[];



//low number of observations, bucket it
update OverallQual:3f from `t where  OverallQual=1
update OverallQual:3f from `t where  OverallQual=2

/explore houses with no Garage
select avg SalePrice, avg OverallQual, PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where GarageArea = 0
select avg SalePrice, avg OverallQual,  PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where GarageArea > 0,OverallQual<6
select avg SalePrice, avg OverallQual,  PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5), avg GrLivArea from t where GarageArea > 0
select Percentage:(count Id)%81 by Neighborhood from t where GarageArea = 0
select Percentage:(count Id)%1458 ,PPSF: avg SalePrice%(GrLivArea+TotalBsmtSF*0.5) by Neighborhood from t 

//OverallQual and OverallCond are already scaled numerically. The rest must be rescaled as well. We need a function 
.gmb.preprocessing.ordinalScale:{[table;ordinalList]
    //table -- table with only orindinal columns
    //ordinalList -- list of the ordinal features in order from lowest rank to highest
    //returns table with ordinal columns scaled 0 to max rank
    uniqueList:distinct ordinalList; //sanity check
    scaleDictionary:uniqueList!til count uniqueList;
    :{@[x;y;:;z[x[y]]]}[table;;scaleDictionary]cols table;
 };

ordinalRescaledTable:.gmb.preprocessing.ordinalScale[select ExterQual, ExterCond, BsmtQual, BsmtCond, HeatingQC, KitchenQual, FireplaceQu from t;`NA`Po`Fa`TA`Gd`Ex]
ordinalRescaledTable: update BsmtExposure: (raze value (flip .gmb.preprocessing.ordinalScale[select  BsmtExposure from t;`NA`No`Mn`Av`Gd])) from ordinalRescaledTable
ordinalRescaledTable: update Fence: (raze value (flip .gmb.preprocessing.ordinalScale[select Fence from t;`NA`MnWw`GdWo`MnPrv`GdPrv])) from ordinalRescaledTable
ordinalRescaledTable: update OverallQual: (exec OverallQual from t) from ordinalRescaledTable
ordinalRescaledTable: update OverallCond: (exec OverallCond from t) from ordinalRescaledTable
ordinalRescaledTable: update Electrical: (raze value (flip .gmb.preprocessing.ordinalScale[select Electrical from t;`FuseF`FuseA`SBrkr])) from ordinalRescaledTable
-8#flip ordinalRescaledTable



//Time to  use one hot encoding to create binary columns representing the categorical variables
//we use the following function:
.gmb.preprocessing.oneHotEncoder:{[table]
    //Create Dummy variables out of categorical:
    //table--takes only table with only categorical variables(symbols), cannot start with number
    table:`$string table; //converts table to string, then symbol. Helps feed numerical categorical variables 
    n:count table; // count rows
    p:count cols table; //count columns
    //adds name of column to table entries
    newCols:`$(raze string (count table)#/:cols table) ,'(raze value flip string table); //nondistict list of newColumns
    distinctEntries:count each distinct each table[cols table]; //list of distinct entries per column
    /take:distinctEntries*count table 
    shape:(sum distinctEntries ; count table);
    table:flip (cols table)!((count cols table)#shape#newCols);
    //section creates comparative table for boolean later
    uniqueColumnList:distinct newCols;
    //create and populate a table with dummy values and dummy variables
    dummytable:flip uniqueColumnList!(flip (count table)#(enlist (count uniqueColumnList)#`sym)); //dummytable filled with `sym
    dummytable2:0#dummytable;
    //populate dummytable entries with its own column names
    dummytable:{@[x;y;:;y]}/[dummytable;cols dummytable];
    colsTable:cols table; //list of categorical variables
    distinctEntries:count each distinct each table[cols table]; //list of distinct entries per variable
    take:distinctEntries*count table; // list, unique entries for each column * number of rows
    shape:(sum distinctEntries ; count table); //number of columns, rows for final table
    dummytable2:(dummytable2 upsert (flip (shape)#raze(take # ' value flip table)));
    completeDisjunctiveTable:1*dummytable=dummytable2;
    relativeFrequencyTable:completeDisjunctiveTable%(n*p);
    columnProfileTable:completeDisjunctiveTable%\:(sum completeDisjunctiveTable)[cols completeDisjunctiveTable];
    rowProfileTable:completeDisjunctiveTable%(count cols table);
    :(`CDT`RFT`CPT`RPT)!(completeDisjunctiveTable;relativeFrequencyTable;columnProfileTable;rowProfileTable);
    };


//Unfortunately, we cannnot have k variables for hot encoder, or else our matrix will have lower rank than # columns
//due to linear dependance of columns. We need a similar function to create k-1 dummy variables
.gmb.preprocessing.oneHotEncoderKMinusOne:{[table]
    //Create k-1 Dummy variables per column out of categorical table
    //table--takes only table with only categorical variables(symbols), cannot start with number
    table:`$string table; //converts table to string, then symbol. Helps feed numerical categorical variables 
    n:count table; // count rows
    p:count cols table; //count columns
    //adds name of column to table entries
    newCols:asc `$(raze string (count table)#/:cols table) ,'(raze value flip string table); //nondistict list of newColumns
    distinctEntries:count each distinct each table[cols table]; //list of distinct entries per column
    /take:distinctEntries*count table 
    shape:(sum distinctEntries ; count table);
    table:flip (cols table)!((count cols table)#shape#newCols);
    //section creates comparative table for boolean later
    uniqueColumnList:distinct newCols;
    //create and populate a table with dummy values and dummy variables
    dummytable:flip uniqueColumnList!(flip (count table)#(enlist (count uniqueColumnList)#`sym)); //dummytable filled with `sym
    dummytable2:0#dummytable;
    //populate dummytable entries with its own column names
    dummytable:{@[x;y;:;y]}/[dummytable;cols dummytable];
    colsTable:cols table; //list of categorical variables
    distinctEntries:count each distinct each table[cols table]; //list of distinct entries per variable
    take:distinctEntries*count table; // list, unique entries for each column * number of rows
    shape:(sum distinctEntries ; count table); //number of columns, rows for final table
    dummytable2:(dummytable2 upsert (flip (shape)#raze(take # ' value flip table)));
    completeDisjunctiveTable:1*dummytable=dummytable2;
    //start deleting k-1 columns
    distinctEntries[0]:distinctEntries[0]-1;
    distinctEntries:(+\)distinctEntries;
    colsSuperfluous:(raze cols completeDisjunctiveTable)[distinctEntries];
    completeDisjunctiveTable:![completeDisjunctiveTable;();0b; colsSuperfluous];
    :completeDisjunctiveTable;
    };
     
categoricalTable:select MSSubClass,MSZoning,Alley,LotShape,LandContour,LotConfig,LandSlope,Neighborhood,BldgType,HouseStyle,RoofStyle,Exterior1st,MasVnrType,Foundation,GarageType,GarageFinish,PavedDrive,SaleType,BsmtFinType1,BsmtFinType2 from t

categoricalTable:.gmb.preprocessing.oneHotEncoderKMinusOne[categoricalTable]
//Delete categories with low observations
delete Exterior1stAsphShn from `categoricalTable
delete Exterior1stImStucc from `categoricalTable
delete Exterior1stCBlock from `categoricalTable
delete Exterior1stBrkComm  from `categoricalTable
delete Exterior1stStone from `categoricalTable
delete LotConfigFR3        from `categoricalTable
delete MSSubClass40        from `categoricalTable
delete FoundationStone     from `categoricalTable
delete GarageType2Types    from `categoricalTable
delete RoofStyleMansard    from `categoricalTable
delete MasVnrTypeNA        from `categoricalTable
delete GarageTypeCarPort   from `categoricalTable
delete LotShapeIR3         from `categoricalTable
delete MSSubClass180       from `categoricalTable
delete RoofStyleGambrel    from `categoricalTable
delete MSSubClass45        from `categoricalTable



//Add `CentralAir`PoolArea`GarageCondGood`GarageQualGood`Exterior2nd`Heating, already hot encoded
5#categoricalTable:categoricalTable,'(select CentralAir,PoolArea,GarageCondGood,GarageQualGood,Exterior2nd,Heating from t)
count cols categoricalTable

//we have 109(plus 6 already encoded) columns representing the categorical columns, from 20 originally
//We have categoricalTable(129 cols), ordinalRescaledTable(12 cols), and t(65 cols)
//We need to create a new table with updated columns
delete  ExterQual, ExterCond,BsmtQual, BsmtCond,HeatingQC,KitchenQual,FireplaceQu,BsmtExposure,Fence,OverallQual,OverallCond,Electrical from `t;
t:t,'ordinalRescaledTable
count cols t
//Delete columns to be replaced by categoricalTable
delete MSSubClass,MSZoning,Alley,LotShape,LandContour,LotConfig,LandSlope,Neighborhood,BldgType,HouseStyle,RoofStyle,Exterior1st,MasVnrType,Foundation,GarageType,GarageFinish,PavedDrive,SaleType,BsmtFinType1,BsmtFinType2,CentralAir,PoolArea,GarageCondGood,GarageQualGood,Exterior2nd,Heating from `t
count cols t

// Normalize(by min max):`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`BedroomAbvGr`KitchenAbvGr`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`PorchSQFT`ExterQual`ExterCond`BsmtQual`BsmtCond`HeatingQC`KitchenQual`FireplaceQu`BsmtExposure`Fence`OverallQual`OverallCond`Electrical
//We won't normalize //nvm `SalePrice, we log it.

minMaxTable:flip (`SalePrice`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`BedroomAbvGr`KitchenAbvGr`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`PorchSQFT`ExterQual`ExterCond`BsmtQual`BsmtCond`HeatingQC`KitchenQual`FireplaceQu`BsmtExposure`Fence`OverallQual`OverallCond`Electrical)!({.ml.minmax[t[x]]}each `SalePrice`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`BedroomAbvGr`KitchenAbvGr`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`PorchSQFT`ExterQual`ExterCond`BsmtQual`BsmtCond`HeatingQC`KitchenQual`FireplaceQu`BsmtExposure`Fence`OverallQual`OverallCond`Electrical)
nonNormTable:flip (`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`BedroomAbvGr`KitchenAbvGr`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`PorchSQFT`ExterQual`ExterCond`BsmtQual`BsmtCond`HeatingQC`KitchenQual`FireplaceQu`BsmtExposure`Fence`OverallQual`OverallCond`Electrical)!(t[`LotFrontage`LotArea`YearBuilt`YearRemodAdd`MasVnrArea`BsmtFinSF1`BsmtFinSF2`BsmtUnfSF`TotalBsmtSF`1stFlrSF`2ndFlrSF`GrLivArea`BsmtFullBath`BsmtHalfBath`FullBath`HalfBath`BedroomAbvGr`KitchenAbvGr`TotRmsAbvGrd`Fireplaces`GarageYrBlt`GarageCars`GarageArea`WoodDeckSF`PorchSQFT`ExterQual`ExterCond`BsmtQual`BsmtCond`HeatingQC`KitchenQual`FireplaceQu`BsmtExposure`Fence`OverallQual`OverallCond`Electrical])
count cols minMaxTable
count cols nonNormTable

//Add categorical columns
minMaxTable:minMaxTable,'categoricalTable
nonNormTable:nonNormTable,'categoricalTable
//Add SalePrice
nonNormTable:nonNormTable,'(select SalePrice from t)
/Add Id for analysis later
minMaxTable:minMaxTable,'(select Id from t)
nonNormTable:nonNormTable,'(select Id from t)
count cols nonNormTable
count cols minMaxTable
count nonNormTable
count minMaxTable

//move dependent variable SalePrice to first column
minMaxTable:`SalePrice xcols minMaxTable
nonNormTable:`SalePrice xcols nonNormTable

minMaxTable:"f"$minMaxTable
nonNormTable:"f"$nonNormTable
//partitian into train/test
minMaxTable:.ut.part[`train`test!3 1;0N?] minMaxTable
nonNormTable:.ut.part[`train`test!3 1;0N?] nonNormTable
count nonNormTable.train
count nonNormTable.test

Y:enlist exec SalePrice from nonNormTable.train
X:1_value flip nonNormTable.train
Yt:enlist exec SalePrice from nonNormTable.test
Xt:1_value flip nonNormTable.test
THETA:(1;1+count X)#0f //initialize THETAs to 0
/normalize X  variables

zsf:.ml.zscoref each X
.ut.rnd[0.01] (avg;sdev)@/:\: X:zsf @'X


.ut.rnd[0.01] (avg;sdev)@/:\: Xt:zsf @'Xt

/works if data normalized first
THETA:(1;1+count X)#0f //initialize THETAs to 0
show THETA:.ut.rnd[0.01] 10000 .ml.gd[0.001;.ml.lingrad[();Y;X]]/ THETA //gets close with high enough tests, but slow

/test error for THETA
.ml.rms first Yt-p:.ml.plin[Xt] THETA 

/p207 Fun Q //THIS WORKS, but use THETA 0 on the error function
/SGD
/
i:0N?count X 0 //generates random i for each observation
X:X[;i];Y:Y[;i] //shuffles Y and X

THETA:(1;1+count X)#0f
gf:.ml.lingrad[()]
cf:.ml.lincost[();Y;X]
mf:.ml.sgd[0.01;gf;{x?x};10;Y;X]
show THETA:.ut.rnd[0.01] .ml.iter[1;0f;cf;mf] THETA
.ml.rms first Y-p:.ml.plin[X] THETA 0 //training error function
.ml.rms first Yt-p:.ml.plin[Xt] THETA 0 //CV error function

/test error for THETA
.ml.rms first Y-p:.ml.plin[X] THETA 0
.ml.rms first Yt-p:.ml.plin[Xt] THETA 0      ///CV

f:.ml.lincost[();Yt;Xt]1#.fmincg.fmincg[;;THETA 0]::

//Elastic Net Regularization 
rf:.ml.enet[350;.8]
THETA:.ut.rnd[0.01] 1#.fmincg.fmincg[1000;.ml.lincostgrad[rf;Y;X];raze THETA 0]

/test error for THETA
.ml.rms first Y-ptrain:.ml.plin[X] THETA 
.ml.rms first Yt-ptest:.ml.plin[Xt] THETA 

//Use entire set
THETA:(1;1+count (X,'Xt))#0f //initialize THETAs to 0
show THETA:.ut.rnd[0.01] 10000 .ml.gd[0.001;.ml.lingrad[();(Y,'Yt);(X,'Xt)]]/ THETA //gets close with high enough tests, but slow

/test error for THETA

.ml.rms first (Y,'Yt)-p:.ml.plin[(X,'Xt)] THETA 

//Elastic Net Regularization 
/Regularization of THETA parameters
rf:.ml.enet[50;1]
THETA:.ut.rnd[0.01] 1#.fmincg.fmincg[1000;.ml.lincostgrad[rf;(Y,'Yt);(X,'Xt)];raze THETA 0]
//new error test (should be slightly bigger)
.ml.rms first (Y,'Yt)-p:.ml.plin[(X,'Xt)] THETA 

f:.ml.lincost[();(Y,'Yt);(X,'Xt)]1#.fmincg.fmincg[;;THETA 0]::

/Program takes a few minutes, optimal l1 and l2 values are 350 and 0.8 for CV data, 50 and 1 for total data
/

alr:.ut.sseq[50f;0f;600f] cross .ut.sseq[0.1;0f;1f]
alr .ml.imin e:(f[1000] .ml.lincostgrad[;(Y,'Yt);(X,'Xt)] .ml.enet .) peach alr


//Elastic Net Regularization 
/Regularization of THETA parameters
rf:.ml.enet[50;1]
THETA:.ut.rnd[0.01] 1#.fmincg.fmincg[1000;.ml.lincostgrad[rf;(Y,'Yt);(X,'Xt)];raze THETA 0]
//new error test (should be slightly bigger)
.ml.rms first (Y,'Yt)-p:.ml.plin[(X,'Xt)] THETA 

//done. I save the THETA coefficients, apply to the second set of data, and check where predictions went wrong.
save `:C:/MLProjects/HousePrices/THETA.csv

//investigate where predictions went wrong
testTable: update PredPrice:(raze ptest)  from nonNormTable.test
testTable:`PriceDiff xcols update PriceDiff:(PredPrice-SalePrice)%SalePrice from testTable
select Id, PriceDiff, PredPrice, SalePrice, OverallQual,  PPSF: SalePrice%(GrLivArea+TotalBsmtSF*0.5), GrLivArea from testTable  where (abs(PriceDiff)) > .5
flip `PriceDiff xdesc select from testTable where (abs(PriceDiff)) > .5

plt.xlabel"weighted PPSF";
plt.ylabel"% error";
plt.title"PPSF v Error";
plt.grid 1b;
plt.scatter[exec SalePrice%(GrLivArea+TotalBsmtSF*0.5) from testTable;  exec PriceDiff from testTable]
plt.show[];
//I am getting the lower PPSF incredibly wrong, need to investigate

select Id from testTable where (abs(PriceDiff))>.5
// most problematic Ids 

"Garage"
select avg abs(PriceDiff) from testTable where  GarageArea =0
select avg abs(PriceDiff) from testTable where  GarageArea >0
//I am underpenalizing for no garage
"Basement"
select avg abs(PriceDiff) from testTable where  TotalBsmtSF  >0
select avg abs(PriceDiff) from testTable where  TotalBsmtSF  =0
//Fine penalizing for no basement
"Porch"
select avg abs(PriceDiff) from testTable where  PorchSQFT  >0
select avg abs(PriceDiff) from testTable where  PorchSQFT  =0
//Porch is fine
"2nd Floor"
select avg abs(PriceDiff) from testTable where  testTable[`2ndFlrSF]>0
select avg abs(PriceDiff) from testTable where  testTable[`2ndFlrSF]=0
/2nd floor is fine
"MasVnrArea"
select avg abs(PriceDiff) from testTable where  MasVnrArea  >0
select avg abs(PriceDiff) from testTable where  MasVnrArea  =0
//MasVnrArea is fine
"WoodDeck"
select avg abs(PriceDiff) from testTable where  WoodDeckSF  >0
select avg abs(PriceDiff) from testTable where  WoodDeckSF  =0
//WoodDeck is fine
"Pool"
select avg abs(PriceDiff) from testTable where  PoolArea  >0
select avg abs(PriceDiff) from testTable where  PoolArea  =0
//inconclusive for Pool Area testing, not enough data points
"Fence"
select avg abs(PriceDiff) from testTable where  Fence  >0
select avg abs(PriceDiff) from testTable where  Fence  =0
"WoodDeck"
select avg abs(PriceDiff) from testTable where  WoodDeckSF  >0
select avg abs(PriceDiff) from testTable where  WoodDeckSF  =0
//slightly off for WoodDeck

desc abs( abs(testTable.PriceDiff) cor/: 1_flip testTable)

//My average prediction error was approximately 18%, largely resulting from colinearity,
//and the large number of zeros in many continuous features. Linear Regression would not have been my choice of algo.






