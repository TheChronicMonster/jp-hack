'reach 0.1';
const STARTING_PACK_COST = 100;
// .000001 ALGO will be .0001 ALGO
const PRICE_INCREASE_MULTIPLE = 100;

export const main = Reach.App(() => {
  const Creator = Participant('Creator', {
    setLicense: Fun(
      [],
      Object({
        assetId: Token,
        licenseType: UInt,
        shares: UInt,
        retailPrice: UInt,
        secondaryBottom: UInt,
        royalty: UInt,
        lenInBlocks: UInt,
        isBondingCurve: Bool,
      })
    ),
    isReady: Fun([], Null),
    seePrice: Fun([Address, UInt], Null),
    showOutcome: Fun([Address, UInt], Null),
  });
  const Gamer = API('Gamer', {
    transaction: Fun([UInt, UInt], Tuple(Address, UInt)),
    doBonding: Fun([], Null),
  });
  const V = View('Obs', {
    proof: Fun([Address], Null),
    capture: Fun([Address], Bool),
  });
  init();

  Creator.only(() => {
    const {
      assetId,
      licenseType,
      shares,
      retailPrice,
      secondaryBottom,
      royalty,
      lenInBlocks,
      isBondingCurve,
    } = declassify(interact.setLicense());
  });
  Creator.publish(
    assetId,
    licenseType,
    shares,
    retailPrice,
    secondaryBottom,
    royalty,
    lenInBlocks,
    isBondingCurve
  );

  const amt = 1;

  commit();
  Creator.pay([[amt, assetId]]);
  Creator.interact.isReady();
  assert(balance(assetId) == amt, 'balance of asset is wrong');
  const end = lastConsensusTime() + lenInBlocks;

  const [
    highestTransaction,
    lastPrice,
    isFirstTransaction,
    isRenting,
    tokSupply,
    costOfBonding,
    bondingPaid,
  ] = parallelReduce([
    Creator,
    secondaryBottom,
    true,
    false,
    1,
    STARTING_PACK_COST,
    0,
  ])
    .define(() => {
      const getBalance = () => {
        if (isBondingCurve) {
          return bondingPaid;
        } else {
          return isFirstTransaction ? 0 : lastPrice;
        }
      };
    })
    .invariant(balance(assetId) == amt)
    .invariant(balance() === getBalance())
    .while(lastConsensusTime() <= end)
    .define(() => {
      const getCost = () => {
        const newSupply = tokSupply + 1;
        // bonding curve - ax^2 + bx + c
        const newCost =
          pow(mul(newSupply, PRICE_INCREASE_MULTIPLE), 2, 10) +
          mul(2, newSupply) +
          STARTING_PACK_COST;
        return [newSupply, newCost];
      };
    })
    .api_(Gamer.doBonding, () => {
      check(isBondingCurve, 'is bonding curve');
      const [newSupply, newCost] = getCost();
      return [
        [costOfBonding],
        notify => {
          notify(null);
          return [
            this,
            lastPrice,
            false,
            false,
            newSupply,
            newCost,
            bondingPaid + costOfBonding,
          ];
        },
      ];
    })
    .define(() => {
      const handleNotFirstTransaction = () =>
        transfer(lastPrice).to(highestTransaction);
    })
    .api_(Gamer.transaction, (transaction, rentTime) => {
      check(!isBondingCurve, 'is bonding curve');
      const who = this;
      const shouldStartRent = rentTime > 0;
      const shouldEndRent = isRenting === true;
      check(transaction > lastPrice, 'transaction is too low');
      return [
        [transaction],
        notify => {
          notify([highestTransaction, lastPrice]);
          if (!isFirstTransaction) {
            handleNotFirstTransaction();
          }
          return [
            who,
            transaction,
            false,
            shouldStartRent,
            tokSupply,
            costOfBonding,
            bondingPaid,
          ];
        },
      ];
    });

  transfer(amt, assetId).to(highestTransaction);
  Creator.interact.showOutcome(highestTransaction, lastPrice);
  transfer(balance()).to(Creator);
  commit();
  exit();
});
