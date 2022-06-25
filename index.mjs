import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib();

const startingBalance = stdlib.parseCurrency(100);

const LICENSETYPE = ['FREE', 'LIMITED', 'BONDING CURVE', 'FRACTIONAL', 'CUSTOM'];

console.log(`Creating test Assset`);
const accCreator = await stdlib.newTestAccount(startingBalance);

const theAsset = await stdlib.launchToken(accCreator, "Alloy game", "GAME", { supply: 1 });
const assetId = theAsset.id;
const licenseType = Math.floor(Math.random() * 5);
const shares = 1;
const retailPrice = stdlib.parseCurrency(10);
const minSec = stdlib.parseCurrency(0);
const royalty = 5;
const lenInBlocks = 10;
const params = { assetId, licenseType, shares, retailPrice, minSec, royalty, lenInBlocks };

let done = false;
const bidders = [];
const startLicense = async () => {
    let transaction = minSec;
    const runBidder = async (who) => {
        const inc = stdlib.parseCurrency(Math.random() * 10);
        transaction = transaction.add(inc);

        const acc = await stdlib.newTestAccount(startingBalance);
        acc.setDebugLabel(who);
        await acc.tokenAccept(assetId);
        bidders.push([who, acc]);
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
    };

    await runBidder('Alice');
    await runBidder('Bob');
    await runBidder('Claire');
    while (! done) {
        await stdlib.wait(1);
    }
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

// View //
//const proof = await ctc.views.Obs.proof();
console.log(`The asset is owned by ${formatAddress(who)}.`);

for (const [who, acc] of bidders) {
    const [ amt, amtAsset ] = await stdlib.balancesOf(acc, [null, assetId]);
    console.log(`${who} has ${stdlib.formatCurrency(amt)} ${stdlib.standardUnit} and ${amtAsset} of the Asset`);
}
done = true;