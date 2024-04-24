# SyntheticsWithSplice

Trying to simulate data to use chainladder methods on claims.

Based on the code by Hayden Ware at Dynamo Analytics.

### The synthetic data:

-   generated with the SPLICE R package

-   script up to line \~214 covers generation of a claims dataset

-   currently more complex to avoid the use of default package options which are themselves unnecessary complex (and black box).

-   beyond 214 is partially hacked for the purposes of Psicle and dashboarding, e.g. generating a corresponding premium dataset, reinsurance, ..., and stitching it together.

-   each claim characteristic (payment delay/count, sizes, notification delays, etc) is simulated from a specified distribution, so can be tailored to look like any 'real life' portfolio

-   Limitation is any 'trend' needs to be baked in to the simulation, and hence is known upfront and may not reflect a real life trend

### Thinks to know about the data being generated

-   **Exposure** is quarterly (`trianglePeriodicity = 4`)

    -   hence the triangle dimension is 4x4=16 for 4 years

-   the **number of policies** per year are 10,000

-   use an **inflation rate** of 2%, giving 0.0049629% per quarter

-   claim-**frequency** is at 0.1

-   desired approximate **loss ratio** at 0.8

Supporting parameters:

| Parameter                                                                                        | Value   |
|--------------------------------------------------------------------------------------------------|---------|
| Claims handling expenses (`CHE`)                                                                 | 0.03    |
| Commission rate on non-direct channels (`commision`)                                             | 0.1     |
| nonRI recovery rate (`nonRIRate`)                                                                | 0.07    |
| Maximum nonRI rate to scale the distribution down (`nonRIRateMax`)                               | 0.2     |
| RI threshold, assuming XoL recovery for random claims that are above this amount (`RIThreshold`) | 150,000 |
| The chance that a claim above the threshold is under the fac cover (`RIChance`)                  | 0.5     |

: Supporting parameters in R

⭐ *Note that the `set_parameters()` function will then set package-wise global parameters for the claims simulator - a function in `SynthETIC`*

💡 Note that 2 extra prior years are being produced.

### The process of simulating the claims

When simulating claims, two of the most important things to consider are the claim severity and claim frequency. These two elements will be simulated using different distributions.

**Claim frequency:** The claim frequencies are simulated using a Poisson distribution. So suppose you have 6 years (24 quarters), you can simulate the amount of claims that occur in every quarter using `claim_frequency()` and get the 'time-stamps' of these claims using `claim_occurence()`.

**Claim size:** Thereafter, the claim sizes are simulated according to a lognormal distribution, using `claim_size()`.

**Claim notification delay:** Further, the notification of the claim delay does not occur immediately, which leads to a delay. This notification delay is accounted for by using a weibull distribution and the `claim_notification()` function. The mean delay is $1$ day.

**Claim closure delay:** After the claim notification comes, there is another delay before the claim is settled. This delay is simulated using the `claim_closure()` function. This delay is also assumed to have a weibull distribution with a mean of $2$.

**Claim settlement payments:** Now, the claims are not usually settled with a single lump sum. The number of payments it takes to settle a claim is assumed to have a geometric distribution with a mean number of payments per claim being $1.8$ in the function `claim_payment_no()`. But in order to ensure that there is at least 1 payment per claim, change all the nr. of payments that are simulated to be 0 to 1. The size of these different payments are simulated using `claim_payment_size`, which returns a vector with the payment delay pattern for each of the claims and occurrence periods. Thereafter the delays between the payments and the resulting time stamps are simulated using `claim_payment_delay()` and `claim_payment_time()`.
