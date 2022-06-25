import * as announcerBackend from './build/announcer.main.mjs';
import { loadStdlib } from '@reach-sh/stdlib';

const stdlib = await loadStdlib('ETH');
// stdlib.setProviderByName('TestNet');

const bal = stdlib.parseCurrency(1000);
const acct = await stdlib.newTestAccount(bal);

const ctc = acct.contract(announcerBackend);

// deploy contract
await stdlib.withDisconnect(() =>
  ctc.p.Constructor({
    ready: stdlib.disconnect,
  })
);

const announcerCtcAddress = await ctc.getInfo();

console.log('********************************************');
console.log('Announcer contract address is:', announcerCtcAddress);
console.log('********************************************');
