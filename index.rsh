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
      })
    ),
    isReady: Fun([], Null),
    seePrice: Fun([Address, UInt], Null),
    showOutcome: Fun([Address, UInt], Null),
  });
  const Gamer = API('Gamer', {
    transaction: Fun([Bool, UInt, UInt], Tuple(Address, UInt)),
  });
  const V = View('Obs', {
    proof: Fun([Address], Null),
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
    } = declassify(interact.setLicense());
  });
  Creator.publish(
    assetId,
    licenseType,
    shares,
    retailPrice,
    secondaryBottom,
    royalty,
    lenInBlocks
  );

  const amt = 1;

  const rentSet = new Set();

  commit();
  Creator.pay([[amt, assetId]]);
  Creator.interact.isReady();
  assert(balance(assetId) == amt, 'balance of asset is wrong');
  const end = lastConsensusTime() + lenInBlocks;

  const [
    highestTransaction,
    lastPrice,
    isFirstTransaction,
    bondingCost,
    tokSupply,
    howMuchPaid,
    isRenting,
  ] = parallelReduce([
    Creator,
    secondaryBottom,
    true,
    STARTING_PACK_COST,
    1,
    0,
    false,
  ])
    .invariant(balance(assetId) == amt)
    .invariant(balance() === (isFirstTransaction ? 0 : lastPrice))
    .invariant(balance() === howMuchPaid)
    .while(lastConsensusTime() <= end)
    .define(() => {
      const handleNotFirstTransaction = () =>
        transfer(lastPrice).to(highestTransaction);
      const doBondingCurve = isTrue => {
        const newSupply = tokSupply + 1;
        const newCost =
          pow(mul(newSupply, PRICE_INCREASE_MULTIPLE), 2, 10) +
          mul(2, newSupply) +
          STARTING_PACK_COST;
        return isTrue ? [newCost, newCost] : [tokSupply, bondingCost];
      };
    })
    .api_(Gamer.transaction, (bondCurve, transaction, rentTime) => {
      const who = this;
      const shouldStartRent = rentTime > 0;
      const shouldEndRent = isRenting === true;
      check(transaction > lastPrice, 'transaction is too low');
      return [
        bondCurve ? bondingCost : transaction,
        notify => {
          notify([highestTransaction, lastPrice]);
          if (!isFirstTransaction) {
            handleNotFirstTransaction();
          }
          const [newSupply, newCost] = doBondingCurve(bondCurve);
          //   const newBondingCost = Creator.interact.seePrice(who, transaction);
          return [
            who,
            transaction,
            false,
            newCost,
            newSupply,
            howMuchPaid,
            shouldStartRent ? true : shouldEndRent ? false : isRenting,
          ];
        },
      ];
    });
  // .timeout(absoluteTime(end), () => {
  //   Creator.publish();
  //   return [
  //     highestTransaction,
  //     lastPrice,
  //     isFirstTransaction,
  //     bondingCost,
  //     tokSupply,
  //     howMuchPaid,
  //     numOfRenters,
  //   ];
  // });

  transfer(amt, assetId).to(highestTransaction);
  if (!isFirstTransaction) {
    transfer(lastPrice).to(Creator);
  }
  Creator.interact.showOutcome(highestTransaction, lastPrice);
  commit();
  exit();
});
