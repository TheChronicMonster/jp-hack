'reach 0.1';
const STARTING_PACK_COST = 100;
const PRICE_INCREASE_MULTIPLE = 100;
const ROYALTY_PERCENT = 0.05;

export const main = Reach.App(() => {
  const Creator = Participant('Creator', {
    setLicense: Fun(
      [],
      Object({
        licenseType: UInt,
        shares: UInt,
        retailPrice: UInt,
        secondaryBottom: UInt,
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
    capture: Fun([Address], Bool),
    ownershipToken: Token,
    licenseType: UInt,
    isRenting: Bool,
    bondingPrice: UInt,
    royalties: UInt,
  });
  init();

  Creator.only(() => {
    const {
      licenseType,
      shares,
      retailPrice,
      secondaryBottom,
      lenInBlocks,
      isBondingCurve,
    } = declassify(interact.setLicense());
  });
  Creator.publish(
    licenseType,
    shares,
    retailPrice,
    secondaryBottom,
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
  check(ownershipToken.supply() === totalSupply, 'token has supply');

  commit();
  Creator.publish();
  Creator.interact.isReady();
  const end = lastConsensusTime() + lenInBlocks;

  const Owners = new Set();

  V.ownershipToken.set(ownershipToken);
  V.capture.set(addy => Owners.member(addy));
  V.licenseType.set(licenseType);

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
    royalties,
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
    0,
  ])
    .define(() => {
      V.isRenting.set(isRenting);
      V.bondingPrice.set(bondingPaid);
      V.royalties.set(royalties);

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
      const newRoyals = costOfBonding * (5 / 100);
      return [
        [costOfBonding + newRoyals, [0, ownershipToken]],
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
            bondingPaid + costOfBonding + newRoyals,
            totalTokSupply - 1,
            tokensBought + 1,
            royalties + newRoyals,
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
      const newRoyals = transaction * (5 / 100);
      return [
        [transaction + newRoyals, [0, ownershipToken]],
        notify => {
          notify([highestTransaction, lastPrice]);
          if (!isFirstTransaction) {
            handleNotFirstTransaction();
          }
          transfer([0, [1, ownershipToken]]).to(this);
          Owners.insert(this);
          return [
            who,
            transaction + newRoyals,
            false,
            shouldStartRent,
            tokSupply,
            costOfBonding,
            bondingPaid,
            totalTokSupply - 1,
            tokensBought + 1,
            royalties + newRoyals,
          ];
        },
      ];
    });
  commit();
  exit();
});
