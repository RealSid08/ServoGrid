# Privacy

ServoGrid is designed to be useful without an account. The current app has no analytics, advertising, tracking, cloud database, or ServoGrid-operated server.

## Data handled on device

- Fuel snapshots and bounded comparison history are stored in the app container. Current alert preferences and source health are held in memory in this build.
- Provider credentials, when the user later configures them, are read from the Apple Keychain.
- Location is requested only after a location-related action and is used to present nearby fuel evidence.
- Notification permission is requested only when the user enables an alert.

## Network access

When a live source is selected, ServoGrid contacts that provider directly. The provider can receive normal network metadata such as IP address and request time under its own privacy terms. Demo mode reads bundled JSON and does not need a fuel-data request.

## Background behaviour

ServoGrid may ask iOS for best-effort background refresh. iOS decides whether and when it runs. Local alerts are evaluated after foreground or granted background execution; the app does not claim continuous monitoring or remote push delivery.

## Removal

Deleting the app removes its app-container cache and preferences. Keychain items can outlive app deletion under Apple platform behaviour; a production credential-management screen should provide explicit credential deletion before credentialed sources are offered to end users.
