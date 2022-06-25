'reach 0.1';

export const main = Reach.App(() => {
  const Constructor = Participant('Constructor', {
    ready: Fun([], Null),
  });
  const Publisher = API('Publisher', {
    publish: Fun([Contract], Null),
  });
  const Listener = ParticipantClass('Listener', {
    hear: Fun([Contract], Null),
  });

  init();

  Constructor.publish();
  Constructor.interact.ready();

  var [] = [];
  invariant(balance() == 0);
  while (true) {
    commit();

    const [[licenseCtc], k] = call(Publisher.publish).throwTimeout(false);
    k(null);

    Listener.interact.hear(licenseCtc);

    continue;
  }

  commit();
  exit();
});
