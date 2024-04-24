#HW
library(ggplot2)
library(SPLICE)
library(dplyr)
library(data.table)
library(lubridate)
library(zoo)

set.seed(1)

options(scipen = 999)

valuationDate = as.Date('2022-12-31') # date to cut off transactions for the purpose of to-date figures
# data structure
trianglePeriodicity = 4 # quarterly. Note this is hardcoded for exposure as quarterly for now, so use 4. Needs further work otherwise.
triangleDimension = 16 # 16 -> 4 years at 4 periods per year
dataStartDate = as.Date(paste0(year(valuationDate) - triangleDimension/trianglePeriodicity, '-12-31')) # to trim the data. Note we produce 2 extra prior years and trim due to run-on.
# portfolio parameters
numPolicies = rep(10000, triangleDimension) # policies per year
claimFreq = rep(0.1, triangleDimension) # yearly claim frequency
baseInflation = rep(1.02^(1/4) - 1, (triangleDimension+2*trianglePeriodicity)*2) # quarterly inflation rate at 2%. Ensure vector is more than long enough (unsure why)
lossRatio = 0.8 # desired approx loss ratio
meanClaimSize = 20000
sdClaimSize = 20000
class = 'TestClassA'
resgroup = 'ST'
entities = c('DynamoUK', 'DynamoAU')
entityProp = c(0.7, 0.3) # weighting of policies between entities (only works for 2 currently)
channels = c('Direct', 'BrokerA', 'BrokerB')
channelProp = c(0.25, 0.5, 0.25) # weighting between distribution channels (only works for 3 currently)
# supporting parameters
CHE = 0.03 # claims handling expenses
commission = 0.1 # commission rate on non-direct channels
nonRIRate = 0.07 # nonRI recovery rate (mean - assume a skewed beta distribution)
nonRIRateMax = 0.2 # max nonRI rate to scale the distribution down
RIThreshold = 150000 # assume XoL recovery for random claims that are above this amount
RIChance = 0.5 # chance that a claim above threshold is under the fac cover


set_parameters(ref_claim = 20000, time_unit = 1/trianglePeriodicity) # used for some functions, not sure exactly which

# define Poisson params for claim freq
poissonMean = numPolicies*claimFreq/trianglePeriodicity
frequency = claim_frequency(I = triangleDimension + 2*trianglePeriodicity, simfun = rpois, lambda = poissonMean) # poisson distribution

occurrence = claim_occurrence(frequency)

# define LogNormal params for claim size
lnormMean = meanClaimSize # mean claim size
lnormSD = sdClaimSize # std dev around this mean
lnormSigma = (log(lnormSD^2/lnormMean^2+1))^(1/2)
lnormMu = log(lnormMean) - lnormSigma^2/2

size = claim_size(frequency, simfun = rlnorm, meanlog = lnormMu, sdlog = lnormSigma) # lognormal distribution

# define Weibull params for notification delay
weibullMean = 1 # mean number of periods delay
weibullSD = 1 # std dev around this mean
weibullParams = function(claim_size, occurrence_period){
  weibullCoV = weibullSD/weibullMean
  shape = get_Weibull_parameters(weibullMean, weibullCoV)[1, ]
  scale = get_Weibull_parameters(weibullMean, weibullCoV)[2, ]
  c(shape = shape, scale = scale)
}
notification = claim_notification(frequency, size, rfun = rweibull, paramfun = weibullParams)

# define Weibull params for closure
weibullMean = 2 # mean number of periods delay
weibullSD = 4 # std dev around this mean
weibullParams = function(claim_size, occurrence_period){
  weibullCoV = weibullSD/weibullMean
  shape = get_Weibull_parameters(weibullMean, weibullCoV)[1, ]
  scale = get_Weibull_parameters(weibullMean, weibullCoV)[2, ]
  c(shape = shape, scale = scale)
}
closure = claim_closure(frequency, size, rfun = rweibull, paramfun = weibullParams)

# define geometric params for payment numbers
geomMean = 1.8 # mean number of payments per claim
geomParams = function(claim_size){
  geomP = 1/geomMean
  c(prob = geomP)
}
paymentNo = claim_payment_no(frequency, size, rfun = rgeom, paramfun = geomParams)
paymentNo = lapply(paymentNo, function(x) pmax(x, 1)) # make sure we have at least 1 payment per claim

# define payment size function
# this may look very different for e.g. liability vs motor
paymentSizeFun = function(n, claim_size){
  prop = runif(n)
  prop = prop/sum(prop)
  claim_size * prop
}
paymentSize = claim_payment_size(frequency, size, paymentNo, rfun = paymentSizeFun)

# allowing inbuilt functionality for this one
paymentDelay = claim_payment_delay(frequency, size, paymentNo, closure)

paymentTime = claim_payment_time(frequency, occurrence, notification, paymentDelay)

# assume 2% inflation, nothing superimposed
superInflationOccurrence = function(occurrence, size) {1}
superInflationPaymentTime = function(paymentTime, size) {1}
paymentInflation = claim_payment_inflation(frequency, paymentSize, paymentTime, occurrence, size, baseInflation, superInflationOccurrence, superInflationPaymentTime)

claimsFull = claims(frequency, occurrence, size, notification, closure, paymentNo, paymentSize, paymentDelay, paymentTime, paymentInflation)

# transactions = generate_transaction_dataset(claimsFull) %>% 
#   data.table() %>% 
#   setorder(occurrence_time, payment_time)

claims = generate_claim_dataset(frequency, occurrence, size, notification, closure, paymentNo) %>% 
  data.table() %>% 
  setorder(occurrence_time) %>% 
  .[, class := class] %>% 
  .[, resgroup := resgroup]