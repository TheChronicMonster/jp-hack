import { loadStdlib, ask } from '@reach-sh/stdlib';
import * as licenseBackend from './build/index.main.mjs';
import * as announcerBackend from './build/announcer.main.mjs';

const NETWORK = 'ETH';
const PROVIDER = 'TestNet';

export const stdlib = loadStdlib(NETWORK);
stdlib.setProviderByName(PROVIDER);

const getAccFromMnemonic = async (
  message = 'Please paste the secret of the deployer:'
) => {
  const secret = await ask.ask(message);
  const acc = await stdlib.newAccountFromSecret(secret);
  return acc;
};

const acct = await getAccFromMnemonic();

const ctcAcct = acct.contract(announcerBackend);

// deploy contract
await stdlib.withDisconnect(() =>
  ctcAcct.p.Constructor({
    ready: stdlib.disconnect,
  })
);

const announcerCtcAddress = await ctcAcct.getInfo();

console.log('********************************************');
console.log('Announcer contract address is:', announcerCtcAddress);
console.log('********************************************');

console.log('Deploying DRM CTC...');

const ctcDRM = acct.contract(licenseBackend);

// deploy contract
await stdlib.withDisconnect(() =>
  ctcDRM.p.Creator({
    isReady: stdlib.disconnect,
    setLicense: () => {
      const licenseType = Math.floor(Math.random() * 5);
      const shares = 1;
      const retailPrice = stdlib.parseCurrency(10);
      const secondaryBottom = stdlib.parseCurrency(0);
      const royalty = 5;
      const lenInBlocks = 10;
      const isBondingCurve = licenseType == 2 ? true : false;
      return {
        licenseType,
        shares,
        retailPrice,
        secondaryBottom,
        royalty,
        lenInBlocks,
        isBondingCurve,
      };
    },
    seePrice: (who, amt) => {
      console.log({ who, amt });
    },
    showOutcome: (purchaser, amt) => {
      console.log(
        `Creator saw that ${stdlib.formatAddress(
          purchaser
        )} won with ${stdlib.formatCurrency(amt)}`
      );
    },
  })
);
// set global views for all functions to use
// const { packTok: pTokV, NFT: nftV } = ctcDRM.v;
// const [_rawPackTok, rawPackTok] = await pTokV();
// const [_rawNFT, rawNFT] = await nftV();
// const NFT_id = await fmtNum(rawNFT);
// const packTok = fmtNum(rawPackTok);

const ctcInfo = await ctcDRM.getInfo();

console.log('');
console.log('************************');
console.log('Contract Deployed!');
console.log({
  ctcInfo: ctcInfo,
});
console.log('************************');
console.log('');

process.exit(0);
