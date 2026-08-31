# Data sources and access decisions

Verified 30 August 2026. “Runtime state” describes a clean checkout with no private credentials. A public consumer page is not treated as permission to build an undocumented third-party API.

| Jurisdiction | Authoritative reference | Clean-checkout runtime state | ServoGrid decision |
| --- | --- | --- | --- |
| Western Australia | [FuelWatch RSS tools](https://www.fuelwatch.wa.gov.au/tools/rss) | Public live/scheduled adapter | Fetch bounded regional RSS feeds for today or tomorrow, preserve feed dates, and attribute FuelWatch. |
| New South Wales | [FuelCheck API product](https://api.nsw.gov.au/Product/Index/22) | Credential-ready; unavailable until configured | Use documented OAuth client credentials and v2 price endpoint. Fail before network access when Keychain credentials are absent. |
| Tasmania | [FuelCheck API product](https://api.nsw.gov.au/Product/Index/22) | Credential-ready; unavailable until configured | Use the documented FuelCheck contract only after credentials/agreement are configured. |
| Queensland | [Fuel price reporting dataset](https://www.data.qld.gov.au/dataset/fuel-price-reporting-2025) and [consumer registration](https://www.fuelpricesqld.com.au/) | Unavailable | Current data requires data-consumer signup/token. Historical open resources are not presented as a current-price feed. |
| South Australia | [Fuel price reporting](https://www.sa.gov.au/topics/driving-and-transport/fuel-pricing/fuel-price-reporting) | Unavailable | Current machine access is restricted to registered publishers under its scheme; no scraping or impersonation. |
| Victoria | [Servo Saver public API dataset](https://discover.data.vic.gov.au/dataset/servo-saver-public-api) | Delayed/unavailable | Application/approval is required and public output is delayed by 24 hours. Even once configured, it must be labelled delayed, never live. |
| Northern Territory | [MyFuel NT](https://consumeraffairs.nt.gov.au/myfuel-nt) | Unavailable | The consumer service is public, but a documented third-party API and current reuse terms were not verified. |
| Australian Capital Territory | [FuelCheck API product](https://api.nsw.gov.au/Product/Index/22) | Unavailable | Public FuelCheck documentation used here establishes NSW/Tasmania coverage, not ACT coverage. ServoGrid does not infer it. |
| National evaluation fixture | Checked-in JSON under `ServoGrid/Resources/Fixtures` | Demo only | Ten synthetic stations exercise the national UI and three comparable VIC records support a deterministic movement brief. The fixture is labelled Demo data everywhere. |

## Normalization contract

Adapters return the same domain objects or a typed failure. Provider payload parsing stays outside the UI. ServoGrid retains:

- `sourceEventAt`: when the source says the price became effective;
- `sourceDatasetAt`: when the source says the dataset was produced;
- `observedAt`: when ServoGrid first saw this exact record;
- `checkedAt`: when ServoGrid checked the source.

Missing values remain missing. `checkedAt` is operational evidence, not price freshness evidence.

## Credentials and terms

`FuelCheckAdapter` reads `fuelcheck.clientID` and `fuelcheck.clientSecret` through `KeychainCredentialStore`. No usable credential, token, subscriber agreement, private feed, or provider response is committed. `Secrets.xcconfig`, provisioning profiles, build products, test results, and device artefacts are ignored.

Before enabling another jurisdiction, verify the current provider terms, record attribution/licence details in `SourceCatalog`, add complete parser fixtures and error tests, and keep coverage delayed or unavailable until the real adapter is proven.
