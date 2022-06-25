'reach 0.1';

export const main = Reach.App(() => {
    const Creator = Participant('Creator', {
        setLicense: Fun([], Object({
            assetId: Token,
            licenseType: UInt,
            shares: UInt,
            retailPrice: UInt,
            minSec: UInt,
            royalty: UInt,
            lenInBlocks: UInt,
        })),
        isReady: Fun([], Null),
        seePrice: Fun([Address, UInt], Null),
        showOutcome: Fun([Address, UInt], Null),
    });
    const Gamer = API('Gamer', {
        transaction: Fun([UInt], Tuple(Address, UInt)),
    });
    const V = View('Obs', {
        proof: Fun([Address], Null),
    });
    init();

    Creator.only(() => {
        const { assetId, licenseType, shares, retailPrice, minSec, royalty, lenInBlocks } = declassify(interact.setLicense());
    });
    Creator.publish(assetId, licenseType, shares, retailPrice, minSec, royalty, lenInBlocks);
    
    const amt = 1;
    // V.proof.set(proof);
    commit();
    Creator.pay([[amt, assetId]]);
    Creator.interact.isReady();
    assert(balance(assetId) == amt, "balance of asset is wrong");
    const end = lastConsensusTime() + lenInBlocks;
    
    const [
        highestTransaction,
        lastPrice,
        isFirstTransaction,
    ] = parallelReduce([Creator, minSec, true])
        .invariant(balance(assetId) == amt)
        .invariant(balance() == (isFirstTransaction ? 0: lastPrice))
        .while(lastConsensusTime() <= end)
        .api_(Gamer.transaction, (transaction) => {
            check(transaction > lastPrice, "transaction is too low");
            return [ transaction, (notify) => {
                notify([highestTransaction, lastPrice]);
                if ( ! isFirstTransaction ) {
                    transfer(lastPrice).to(highestTransaction);
                }
                const who = this;
                Creator.interact.seePrice(who, transaction);
                return [who, transaction, false];
            }];
        })
        .timeout(absoluteTime(end), () => {
            Creator.publish();
            return [highestTransaction, lastPrice, isFirstTransaction];
        });

        transfer( amt, assetId ).to(highestTransaction);
        if ( ! isFirstTransaction ) { transfer(lastPrice).to(Creator); }
        Creator.interact.showOutcome(highestTransaction, lastPrice);
    commit();
    exit();
});