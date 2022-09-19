---
title: 'Statistical analysis on Ethereum n-consecutive block proposal probabilities'
date: 2022-08-14
permalink: /posts/ethereum-mev-multiblock
tags:
  - ethereum
---

This article answers the following question: How likely is it that a given Ethereum staking pool controlling `p` of the stake proposes `r` consecutive blocks in an epoch. After The Merge, this is of paramount importance since it opens up a new dimension for MEV[[1]](https://ethereum.org/en/developers/docs/mev/).

Introduction
---

Ethereum is a [byzantine fault tolerant](https://en.wikipedia.org/wiki/Byzantine_fault) public distributed database (a.k.a. blockchain) that is made out of thousands of nodes storing its information, making it one of the most resilient systems invented so far. Technically, it can store arbitrary information but the main use case in the last few years has been related to finance, where the blockchain is used as a ledger, storing account balances.

Miners (or validators, as they will be called after September 2022 once Ethereum migrates from Proof of Work to Proof of Stake) are responsible for updating the database, taking turns at a constant peace of 12 seconds, creating new blocks aggregating multiple valid transactions and appending them to the blockchain. They collect a fee in return, that incentivizes them to behave properly and include as many transactions as possible.

Needless to say, miners/validators have not only a great responsibility in the network, but a lot of power as well, since ultimately they are the ones modifying the distributed ledger. This ability to modify it can be (and is) leveraged by them to extract monetary value, the so-called MEV.

However, the soon-to-happen transition from Proof of Work to Proof of Stake, will introduce new ways of extracting MEV, like multi-block MEV, where a given entity controlling `p` share of the network stake will propose `r` consecutive blocks with a given probability. This article models these probabilities both analytically and empirically.

Ethash vs RANDAO
---

Before diving into the modeling, you may ask. Why isn't multiblock MEV possible in PoW but is in PoS? Well, it's because of the algorithm that selects who proposes the next block. Let's see the differences:

* In **PoW**, block proposers are selected with *ethash*, where the first to solve a complex puzzle is given the right to propose the next block. It takes around 13 seconds to find this solution, but the key here is that the next proposer is not deterministic. Its just based on i) hashpower and ii) luck. No one knows the next proposer until the solution is found.

* Whereas in **PoS**, block proposers are selected using *RANDAO*, some kind of RNG (*Random Number Generator*) algorithm, that gets entropy from all the participants among other sources[[2]](https://eth2book.info/altair/part2/building_blocks/randomness#where-does-the-entropy-come-from). Its main difference from other is that randao is deterministic within each epoch, since all validators have to reach the same conclusion on who is the next proposer.

The key here is that *RANDAO* is updated just once per epoch (32 slots of 12 seconds) so in PoS anyone can know who is going to propose the next 32 blocks. Knowing this allows for multi-block MEV, something that is not possible in PoW.

Intro to MEV
---

MEV stands for Maximal Extractable Value. It refers to the value that can be extracted by **including**, **excluding**, or **changing** the order of the transactions within a block. Since the miners/validators are the ones creating the blocks and appending them to the ledger, they have this power. Note that changing the order or excluding transactions in the block they propose is not against the protocol rules, so MEV can be extracted without acting maliciously (ethics aside).
Some ways of MEV:
* **frontrunning**: Let's say that you have detected an arbitrage opportunity between two DEX, and try to benefit from that. You create a transaction and send it to the mempool. Well, the miner/validator creating the next block will see your transaction, and will most likely include their transaction first, so that when you arrive, the arbitrage opportunity no longer exists because someone else has already benefited from it.
* **sandwiching**: Are you buying a high amount of Eth? Well, that will push the price up a bit. If someone sees this transaction in the mempool, it will place a transaction before you buying Eth, then yours and then one selling.

Etheruem Pools and Validators
---

At the time of writing, Ethereum's consensus layer is made out of more than 415.000[[3]](https://www.beaconcha.in) validators. In each slot (every 12 seconds) a validator is randomly chosen to propose the block in that slot. An epoch contains 32 slots, so a given validator "rolls the dice" 32 times per epoch to propose a block.

With that high number of validators, you may think that it won't be very likely that a validator proposes more than one block per epoch, and even less likely that it proposes multiple blocks in a row, which is what we are studying in this post.

However, not all validators belong to completely uncorrelated entities. Some pools or operators control several hundred or even thousands of validators, so we must calculate the probabilities on a pool/operator level, not on a validator level. A pool controlling 10% of the stake, or 40k+ validators, the probability that it proposes 2 or even 3 blocks in a row is not neglectable. This is exactly what we are quantifying.

Analytical Analysis
---

Hereunder we model analytically the probability of a pool proposing at least `r` blocks in a row within an epoch controlling `p` of the total validators.

Starting from a slot perspective, each validator has the same probability of proposing the next block. This can be modeled as a binomial distribution [[4]](https://en.wikipedia.org/wiki/Binomial_distribution), where the probability of success `p` is:

$p = \frac{1}{n\_{active\_validators}}$

However, as we have explained, some entities control several thousands of validators. Let `v` be the number of validators that a given pool controls, we can calculate the probability of a given pool proposing a block in a slot as:

$p = \frac{1}{n\_active\_validators} * v$

But we are interested in the probability of the pool proposing **at least** `r` **consecutive** blocks in a **whole epoch**, which is not trivial.

If we didn't care that the blocks were consecutive, we could use the following expression to calculate the probability of getting exactly `k` successes in `n` independent trials with `p` probability of success. But it's **not** what we want.

$ \binom{n}{k}  p^k(1-p)^{n-k}$

Leaving Ethereum particularities aside, we can model this problem as the chances of getting at least `k` heads when flipping a biased coin `n` times with a probability of head of `p`.

We can calculate this probability by adding the individual success probabilities of all possible events. Let's see some examples where we want to get at least two heads HH (`k=2`) in `n=1,2,3,...` realizations. In our case:
* heads map to a block proposal duty
* the number of realizations is the slots per epoch =32.

**k=2 n=1**

Out of 1 run, the possibilities of getting 2 heads is 0, since there are no successes in the sample space:
* `0` run contains at least two heads HH
* `2` runs do not contain two heads HH

The probability of each event is shown on the right:

```
H -> p
T -> (1-p)
```

**k=2 n=2**

Out of 2 runs, there is a $ p^2$ probability that we will get two heads:
* `1` run contains at least two heads HH
* `3` runs do not contain two heads HH

```
HH -> p^2      ->sucess
HT -> p*(1-p)
TH -> p*(1-p)
TT -> (1-p)^2
```

**k=2 n=3**

With 3 runs the probability of getting at least 2 heads is the sum of all individual probabilities. As we can see, not all success cases have the same probability.

* `3` runs contain at least two heads HH
* `5` runs do not contain two heads HH


$ p_{success} = p^3 + p^2*(1-p) + p*(1-p)^2 $

```
HHH -> p^3        ->sucess
HHT -> p^2*(1-p)  ->sucess
HTT -> p*(1-p)^2
HTH -> p^2*(1-p)
THH -> p*(1-p)^2  ->sucess
TTH -> p*(1-p)^2
THT -> p*(1-p)^2
TTT -> (1-p)^3
```

Note that in all cases the sum of all individual probabilities for each event equals to one, where $ p_i $ is the individual probability of success of $i$ event.

$ \sum_{n=0}^{2^k}p_i = 1 $

Same for 4 and 5 realizations. Not showing all the combinations for practical reasons.

**k=2 n=4**

* `8` runs contain at least two heads HH
* `8` runs do not contain two heads HH

**k=2 n=5**
* `19` runs contain at least two heads HH
* `13` runs do not contain two heads HH

If we pay attention, we can see how the number of runs with no success follows a pattern:

$ 2, 3, 5, 8, 13 $

This is the Fibonacci series, skipping the first two initial numbers $1, 1$.


But what if `k` is different? Well:
* `k=3` the runs with no success follow the [tribonacci](http://mathworld.wolfram.com/TribonacciNumber.html) sequence: $2, 4, 7, 13, 24, 44$
* `k=4` we get the [tetranacci](http://mathworld.wolfram.com/TetranacciNumber.html) sequence: $ 2, 4, 8, 15, 29, 56 $

It's possible to generalize this for an **unbiassed** coin (`p=0.5`) with the following expressions:

$ p_{nosuccess} = \frac{F_{n+2}^{(k)}}{2^n} $ 

$ p_{success} = \frac{2^n-F_{n+2}^{(k)}}{2^n} $

For example, the probability of getting at least 7 runs with heads using an unbiased coin in 100 coin flips, would be[[4]](https://leancrew.com/all-this/2009/06/stochasticity/):

$ \frac{2^{100} - F_{102}^{(7)}}{2^{100}} = 0.318 $

However, we can't use this since:
* We can't model our problem as an unbiased coin, since our probability of success depends on the % of the validator the pool controls.
* With 32 runs, which represents 1 epoch, there are $2^{32}$ combinations of outcomes, where each one has its probability. Calculating all of them would be too much.

Luckily, Feller came up with an approximation [5] that allows us to calculate the probability of no success:

$ q_n \approx \frac{1-px}{(r+1-rx)q}  \frac{1}{x^{n+1}}$

Where:
* `r` consecutive events (in our case the consecutive blocks)
* `n` trial (in our case 32 slots)
* `p` probability of success (in our case the share of validators of the pool)
* `q=1-p`
* `x` is the closest real root to one calculated as follows.

$ 1 -x+qp^rx^{r+1} = 0  $

We can write this expression in Python solving for `x` and then for `q_n`. With this, we get that the probability of a pool controlling 30% of all validators proposing at least 2 consecutive blocks in an epoch is 90.71 %.

```python
from sympy import *
x = symbols('x', real=True)

r = 2; n = 32; p = 0.3

xx = min(i for i in solve(1-x+(1-p)*p**r*x**(r+1)) if i > 1)
qn = ((1 - p*xx) / ((r + 1 - r*xx)*(1-p))) * (1/(xx**(n+1)))

print("Probability of no success:", qn*100, "%")  #  9.28 %
print("Probability of success:", (1-qn)*100, "%") # 90.71 %
```

Montecarlo Simulations
---

In order to validate that our analytical probabilities are correct, we run a Monte Carlo simulation. By repeated random sampling (simulating hundreds of thousands of epochs) we can calculate the probabilities of each event empirically, and then compare it against the analytical results.

With a simple Python script, we can estimate the probability of a pool controlling 30% of the stake `p=0.3` proposing at least 2 blocks in a row `r=2`, which is 90.865 %, a number quite close to the analytical one.


```python
from numpy import random
from itertools import groupby

def max_consecutive_ones(l):
    return max(([sum(g) for i, g in groupby(l) if i == 1]), default=0)

num_trials = 100000
r = 2; n = 32; p = 0.3

epoch_proposals = [random.binomial(1, p, size=n) for i in range(num_trials)]
num_of_n_consec_proposals = sum([1 for i in epoch_proposals if max_consecutive_ones(i) >= r])

print("Probability of success:", num_of_n_consec_proposals/num_trials * 100, "%")
# 90.865 %
```

Conclussions And Results
---

Using the scripts above, we calculate the probabilities of proposing at least `n` consecutive blocks for a pool controlling `p` of the validators (over one). Note that the probabilities are displayed in percentage, so a pool controlling 10% of the validators will have a chance of 0.2617% of proposing at least 4 blocks in a row.

Analytical probabilities in % (using Feller's estimation)

|        | n=2     | n=3     | n=4       | n=5       |
|--------|---------|---------|-----------|-----------|
| p=0.01 | 0.3066  | 0.0029  | 2.8719e-5 | 2.7729e-7 |
| p=0.05 | 7.1490  | 0.3563  | 0.0172    | 0.0008    |
| p=0.1  | 24.8938 | 2.6814  | 0.2617    | 0.0252    |
| p=0.2  | 66.2931 | 17.9493 | 3.6941    | 0.7215    |
| p=0.3  | 90.7154 | 45.9332 | 15.7139   | 4.7601    |
| p=0.4  | 98.4841 | 74.4787 | 38.6253   | 16.6232   |
| p=0.5  | 99.8672 | 92.2060 | 66.4729   | 38.9562   |

Montecarlo probabilities in % (with 100000 runs per tuple)

|        | n=2    | n=3    | n=4    | n=5    |
|--------|--------|--------|--------|--------|
| p=0.01 | 0.315  | 0.003  | 0.001  | 0.0    |
| p=0.05 | 7.063  | 0.335  | 0.030  | 0.0    |
| p=0.1  | 24.743 | 2.675  | 0.258  | 0.0139 |
| p=0.2  | 66.039 | 17.918 | 3.622  | 0.675  |
| p=0.3  | 90.468 | 45.763 | 15.540 | 4.808  |
| p=0.4  | 98.470 | 74.514 | 38.726 | 16.622 |
| p=0.5  | 99.868 | 92.240 | 66.548 | 38.872 |

As we can see, both the empirical and analytical results match, so we can validate that our simulations are correct. We can also see that for a pool controlling >10% of the total validators, the probability of proposing 2, 3 or even 4 blocks is not neglectable. Note that one epoch has a duration of 12*32 seconds so there are:
* 225 epochs in a day:
* 6750 epoch in a month.

So a pool controlling 10% of the total stake has a probability of 0.258% of proposing 4 blocks in a row within an epoch. But if we look at this for a whole day, the probabilities of this happening increase 225-fold on average. Same for a month, being 6750-fold.

We will leave this analysis for another post, answering the question: How many epochs in a day/month will contain at least an `n`-consecutive block proposal of a pool controlling `p` of all validators?

Coinbase Case Study
---


| <br>n-consecutive blocks/month ➡️ <br>pool share (sept-2022) ⬇️ | n=2 | n=3 | n=4 | n=5 | n=6 | n=7 |
| --- | --- | --- | --- | --- | --- | --- |
| 🥇 Coinbase (14.68 %) | 3051 | 531 | 76 | 11 | 1.80 | 0.14 |
| 🥈 Kraken (8.76 %) | 1339 | 125 | 10 | 1.2 | 0.04 | 0 |
| 🥉 Binance (5.16 %) | 511 | 25 | 1.3 | 0.06 | 0 | 0 |
| BitcoinSuisse (2.15 %) | 93 | 1.7 | 0.06 | 0 | 0 | 0 |
| Lido Blockscape (1.76 %) | 63 | 1.5 | 0 | 0 | 0 | 0 |
| Stakedus (1.26 %) | 33 | 0.67 | 0 | 0 | 0 | 0 |
| F2Pool (0.84 %) | 14 | 0.27 | 0 | 0 | 0 | 0 |
| Bitfinex (0.77 %) | 12 | 0.20 | 0 | 0 | 0 | 0 |
| Huobi (0.68 %) | 8 | 0.00 | 0 | 0 | 0 | 0 |
| Bloxstaking (0.57 %) | 7 | 0.00 | 0 | 0 | 0 | 0 |


<img src='/images/img_count.png'>

<img src='/images/img_nproposals.png'>

References:
---

[1] https://ethereum.org/en/developers/docs/mev/

[2] https://eth2book.info/altair/part2/building_blocks/randomness#where-does-the-entropy-come-from

[3] https://www.beaconcha.in

[4] https://math.stackexchange.com/questions/417762/probability-of-20-consecutive-success-in-100-runs

[5] An Introduction to Probability Theory and Its Applications, 3rd Edition, p. 325, equation 7.11

