'reach 0.1';
const STARTING_PACK_COST = 100;
// .000001 ALGO will be .0001 ALGO
const PRICE_INCREASE_MULTIPLE = 100;

export const main = Reach.App(() => {
  const Creator = Participant('Creator', {
    setLicense: Fun(
      [],
      Object({
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
    ownershipToken: Token
  });
  init();

  Creator.only(() => {
    const {
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
    licenseType,
    shares,
    retailPrice,
    secondaryBottom,
    royalty,
    lenInBlocks,
    isBondingCurve
  );

  const totalSupply = UInt.max;
  const ownershipToken = new Token({
    name: Bytes(32).pad('Tactical'),
    symbol: Bytes(8).pad('TTCL'),
    supply: totalSupply,
    decimals: 0,
  });
  check(ownershipToken.supply() === totalSupply, 'token has supply')

  commit();
  Creator.publish();
  Creator.interact.isReady();
  const end = lastConsensusTime() + lenInBlocks;

  V.ownershipToken.set(ownershipToken);

  const Owners = new Set();

  const [
    highestTransaction,
    lastPrice,
    isFirstTransaction,
    isRenting,
    tokSupply,
    costOfBonding,
    bondingPaid,
    totalTokSupply,
    tokensBought,
  ] = parallelReduce([
    Creator,
    secondaryBottom,
    true,
    false,
    1,
    STARTING_PACK_COST,
    0,
    totalSupply,
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
    .invariant(balance() === getBalance())
    .invariant(!ownershipToken.destroyed())
    .invariant(balance(ownershipToken) === totalTokSupply)
    .while(true)
    .paySpec([ownershipToken])
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
      check(balance(ownershipToken) > 0, 'has token in ctc');
      check(isBondingCurve, 'is bonding curve');
      check(!Owners.member(this), 'already owner');
      const [newSupply, newCost] = getCost();
      return [
        [costOfBonding, [0, ownershipToken]],
        notify => {
          Owners.insert(this);
          transfer([0, [1, ownershipToken]]).to(this);
          notify(null);
          return [
            this,
            lastPrice,
            false,
            false,
            newSupply,
            newCost,
            bondingPaid + costOfBonding,
            totalTokSupply - 1,
            tokensBought + 1,
          ];
        },
      ];
    })
    .define(() => {
      const handleNotFirstTransaction = () =>
        transfer(lastPrice).to(highestTransaction);
    })
    .api_(Gamer.transaction, (transaction, rentTime) => {
      check(balance(ownershipToken) > 0, 'has token in ctc');
      check(!isBondingCurve, 'is bonding curve');
      check(!Owners.member(this), 'already owner');
      const who = this;
      const shouldStartRent = rentTime > 0;
      const shouldEndRent = isRenting === true;
      check(transaction > lastPrice, 'transaction is too low');
      return [
        [transaction, [0, ownershipToken]],
        notify => {
          notify([highestTransaction, lastPrice]);
          if (!isFirstTransaction) {
            handleNotFirstTransaction();
          }
          transfer([0, [1, ownershipToken]]).to(this);
          Owners.insert(this);
          return [
            who,
            transaction,
            false,
            shouldStartRent,
            tokSupply,
            costOfBonding,
            bondingPaid,
            totalTokSupply - 1,
            tokensBought + 1,
          ];
        },
      ];
    });
  commit();
  exit();
});
