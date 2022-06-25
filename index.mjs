import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib();

const startingBalance = stdlib.parseCurrency(100);

const LICENSETYPE = ['FREE', 'LIMITED', 'BONDING CURVE', 'FRACTIONAL', 'CUSTOM'];

// BEGIN ANNOUNCER
export const startAnnouncer = (any) => {
    const ctcListener = acct.contract(
      announcerBackend,
      0x2bed781e6E5Cdc2dCA64107541D07c9aB36357cc,
    );
    announcerBackend.Listener(ctcListener, {
      hear: async (string) => {
        console.log('WOOOO', addr);
      },
    });
  };
  
  export const publishLicense = (any, string) => {
    const announcer = acc.contract(announcerBackend, 0x2bed781e6E5Cdc2dCA64107541D07c9aB36357cc)
      .a
      .Publisher;
    return announcer.publishListing(ctc);
  };
  // END ANNOUNCER

console.log(`Creating test Asset`);
const accCreator = await stdlib.newTestAccount(startingBalance);

const theAsset = await stdlib.launchToken(accCreator, "Alloy game", "GAME", { supply: 1 });
const assetId = theAsset.id;
const licenseType = Math.floor(Math.random() * 5);
const shares = 1;
const retailPrice = stdlib.parseCurrency(10);
const secondaryBottom = stdlib.parseCurrency(0);
const royalty = 5;
const lenInBlocks = 10;
const isBondingCurve = (licenseType == 2) ? true : false;
const params = { assetId, licenseType, shares, retailPrice, secondaryBottom, royalty, lenInBlocks, isBondingCurve };

let done = false;
const buyers = [];
const renters = [];
const startLicense = async () => {
    let transaction = secondaryBottom;
    const runBuyer = async (who) => {
        const inc = stdlib.parseCurrency(Math.random() * 10);
        transaction = transaction.add(inc);

        const acc = await stdlib.newTestAccount(startingBalance);
        
        acc.setDebugLabel(who);
        await acc.tokenAccept(assetId);
        buyers.push([who, acc]);
        const ctc = acc.contract(backend, ctcCreator.getInfo());
        const getBal = async () => stdlib.formatCurrency(await stdlib.balanceOf(acc));

        console.log(`${who} bids ${stdlib.formatCurrency(transaction)}.`);
        console.log(`${who} balance before is ${await getBal()}`);
        try {
            const [ lastBidder, lastBid ] = await ctc.apis.Gamer.transaction(transaction);
            console.log(`${who} out bid ${lastBidder} who bid ${stdlib.formatCurrency(lastBid)}.`);
        } catch (e) {
            console.log(`${who} failed to bid, because the auction is over`);
        }
        console.log(`${who} balance after is ${await getBal()}`);

        console.log(`Open the view`);
        const proof = await ctc.views.Obs.proof();
        console.log(`The asset is owned by ${who}.`);
    };

    await runBuyer('Alice');
    await runBuyer('Bob');
    await runBuyer('Claire');
    done = true;
    while (! done) {
        await stdlib.wait(1);
    }

    // console.log(`Open the view`);
    // const proof = await ctc.views.Obs.proof();
    // console.log(`The asset is owned by ${formatAddress(who)}.`);

    const runRenter = async (who) => {
        //let done = false;
        const getBal = async () => stdlib.formatCurrency(await stdlib.balanceOf(acc));
        const rentPrice = stdlib.parseCurrency(Math.random() * 10);
        const acc = await stdlib.newTestAccount(startingBalance);
        console.log(`Owner ${who} places asset for rent.`);

        acc.setDebugLabel(who);
        await acc.tokenAccept(assetId);
        renters.push([who, acc]);
        
        console.log(`${who} rents for ${stdlib.formatCurrency(rentPrice)}.`);
        console.log(`${who} balance before is ${await getBal()}`);
        try {
            const [ lastRenter, lastRent ] = await ctc.apis.Gamer.transaction(transaction);
            console.log(`${who}, ${lastRenter} rented for ${stdlib.formatCurrency(lastRent)}.`);
        } catch (e) {
            console.log(`${who} failed to rent, because the item is no longer available.`);
        }
        console.log(`${who} balance after is ${await getBal()}`);
    };

    await runRenter('Denise');
    //done = true;
    while (! done) {
        await stdlib.wait(1);
    }
    console.log(`Rent sequence 1 complete`);

    const returnRent = async (who) => {
        const getBal = async () => stdlib.formatCurrency(await stdlib.balanceOf(acc));
        const rentPrice = stdlib.parseCurrency(Math.random() * 10);
        const acc = await stdlib.newTestAccount(startingBalance);
        
        acc.setDebugLabel(who);
        await acc.tokenAccept(assetId);
        renters.push([who, acc]);
        console.log(`returning Rent`);
        console.log(`${who} returns the asset`)
    }
    await returnRent('Denise');
};

const ctcCreator = accCreator.contract(backend);
await ctcCreator.p.Creator({
    setLicense: () => {
        console.log(`Creator sets parameters of License:`, params);
        return params;
    },
    isReady: () => {
        startLicense();
    },
    seePrice: (who, amt) => {
        console.log(`Creator saw that ${stdlib.formatAddress(who)} bid ${stdlib.formatCurrency(amt)}.`);
    },
    showOutcome: (purchaser, amt) => {
        console.log(`Creator saw that ${stdlib.formatAddress(purchaser)} won with ${stdlib.formatCurrency(amt)}`);
    },
});

console.log(`announce results`);
    for (const [who, acc] of buyers) {
        const [ amt, amtAsset ] = await stdlib.balancesOf(acc, [null, assetId]);
        console.log(`${who} has ${stdlib.formatCurrency(amt)} ${stdlib.standardUnit} and ${amtAsset} of the Asset`);
    }