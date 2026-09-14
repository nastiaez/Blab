# Translation edge-case QA

Local Alice browser and Bob Android-emulator acceptance for the approved
translation-reliability follow-up.

## Verified journeys

- `No` from Alice resolves to `Nein` for Bob using sender/context evidence.
- `OMG Nastia` resolves naturally while keeping the name in German, Hindi, and
  Ukrainian.
- Changing Bob's conversation tone leaves completed translations readable and
  unchanged; later work uses the newly saved setting.
- Incoming unsupported Chinese keeps the authored text and shows neutral
  guidance. Bob's own unsupported Chinese tells Bob to use German.
- Bob's `Danke Alice` resolves to `Thank you, Alice` for Alice in the browser.

## Evidence

- `no-nein.png`
- `omg-german.png`
- `omg-hindi.png`
- `omg-ukrainian.png`
- `tone-history-stays.png`
- `unsupported-bob.png`
- `alice-reverse-and-unsupported.png`

## Environment limitation

The local provider rejected several fresh requests during its grammatical-form
audit. The UI and stored preference confirmed that the tone switch no longer
reloads history, while automated coverage confirms that later requests receive
the new tone. A fresh respectful sentence was therefore not used as visual
acceptance evidence.
