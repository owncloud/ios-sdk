## 11.7.1 version

- support for streaming, infinite PROPFIND to prepopulate accounts and speed up initial discovery
- minimum interval between two scans for changes can now be configured via MDM and serverside via capabilities
- fix crash happening during class settings discovery
- add streaming support to OCXMLParser

## 11.7 version

- Scan for changes no longer uses the background URL session, so redirects can be fully managed by the SDK
- New class setting to allow configuration of time interval between the end of one to the beginning of the next scan for changes
- Fix crash in protocol conformance check

## 11.6.1 version

- Certificates
	- LetsEncrypt root certificate handling: extend the default certificate renewal acceptance rule to accept a change from DST Root CA X3 / R3 to ISRG Root X1 / R3, provided that the certificate passes system validation
- Class Settings
	- dynamically determine which settings to include in the settings snapshot in the log intro
- Key Value Store
	- add new semantics for sharing a single Key Value Store instance, based on URL, identifier and owner
- Vault
	- switch to new shared KVS semantics to avoid rapid recreation of the KVS where OCVault is used only very briefly

## 11.6 version

- Bookmarks
	- ItemResolution: enumerates bookmarks to resolve Local IDs to items and a bookmark
- Connection
	- add connection validator flags support: "clear-cookies" to control clearing cookies when entering the connection validator, off by default
	- correctly handle Service Unavailable errors when the true reason is the unavailability of external storage
	- improved Maintenance Mode detection and handling
	- HTTP: add "Original-Request-ID" header to allow tracing of retried requests
- Authentication
	- add OCAuthenticationBrowserSession that allows redirection of authentication settings to browsers with custom scheme
	- provide simplified version for mibrowser scheme as OCAuthenticationBrowserSessionMIBrowser 
- Database Update for improved search capabilities
	- new ownerUserName, lastModifiedDate, syncActivity columns
	- introduce migration with progress reporting and error when initiated from an extension
	- add simplified database versioning that allows retrieval and comparison in the app
- Core
	- uploads: bugfixes in conflict resolution
	- item scrubbing to fix forever spinning items
	- allow limiting result counts for OCQuerys
	- ItemResolution: enumerates bookmarks to resolve Local IDs to items and a running core
	- extend OCQueryConditions with new fields
- Class Settings
	- simplify parameter names
	- add subcategory and label metadata key
	- allow expansion of flat parameters in complex structures (supported for MDM and Branding (app-side))
- Measurements (new): allow benchmarking and logging of actions across different components, starting with OCQueries
- CancelActions (new): new container that allows to encapsulate a cancel action, so it can be passed around and code be injected from different places
- Logging: allow logging of file operations
- bugfixes in Sync Engine, Process Manager, Item Policies, Claims, QueryConditions, Imports, Core Manager, Item Deserialization, Logging

## 11.5.2 version

- Support for MDM setting hierarchies with flat keys
- Item Resolution
  - New method to request OCCore and OCItem for a provided OCLocalID
  - New method to find the OCBookmark that contains a provided OCLocalID

## 11.5 version

- Class Settings 
	- metadata support
	- validation support
	- documentation support
	- new OCClassSetting class makes class settings observable and more approachable
- Host Simulator now part of the SDK
- Connection Validator
- refined, more powerful detection of available authentication methods
- OpenID Connect Dynamic Client Registration support
- Certificate Diffing support
- Improved HTTP logging
- Extended redirection handling and new policies
- Improved error handling
- Fixed unit tests and added nullability information to many classes

## 1.1.2 version

- Fix for long delays before starting a request on iOS 13.1

## 1.1.1 version

- OAuth2/OIDC improvements

## 1.1.0 version

- Background Upload Support
- Item Policies and Available Offline Support
- Open ID Connect Support
- OAuth2 improvements
- iOS 13 fixes
- SQLite fixes for background threads
- Additional Logging
- New Key-Value Store Class
- Bug fixes

## 1.0.3 version

- Authentication improvements
- Fixed background crash
- Log file improvements

## 1.0.2 version

- add support for local users with @ inside their username

## 1.0.1 version

- fixed crash in Favourites fetching
- OAuth2 improvements
- support for account auto-connect

## 1.0.0 version

- first release version for the SDK
- complete rewrite for the iOS SDK
- support for file provider access
- support for Share API 
- OAuth2
- Latest ownCloud Server API
