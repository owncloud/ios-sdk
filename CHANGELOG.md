## 11.9.1 version
- OCAuthenticationMethodOAuth2/OIDC: no longer treat network errors during token refresh as permanently failed refresh
- OCHostSimulator: add auth-race-condition host simulator, to test handling of race conditions in Authorization
- OCNetworkMonitor / OCCoreNetworkMonitorSignalProvider: add logging

## 11.9 version
- Authentication: new type OCAuthenticationDataID
	- an ID that's unique for every OCBookmark.authenticationData and changes when the authenticationData is changed
	- is attached to OCHTTPRequests and OCHTTPResponses, allowing to determine if a request's "Authorization" is based on a different token
- OCHTTPRequest / OCHTTPResponse
	- add authenticationDataID property
	- added counter to logged "Authorization" header fields that allow to determine if its contents was changed between requests
	- the counter issues a new number for every new and not previously used header field contents
	- initial idea was to log the OCAuthenticationDataID, but that could have given hints to its content
- OCAuthenticationMethodOAuth2 / OCAuthenticationMethodOIDC:
	- add support for authenticationDataID
	- in case of preemptive token renewals, now reloads the secret from keychain and performs another date check before triggering a refresh
	- used OCAuthenticationDataID to reschedule/resend HTTP requests that were responded to with a 401 status code and that was sent with another (older) token
- OCAuthenticationMethodBasicAuth
	- store authenticationDataID when loading secret
- OCBookmark
	- add .authenticationDataID property that returns the OCAuthenticationDataID for the bookmark's authenticationData
	- add .user property, storing the last retrieved version of OCConnection.loggedInUser
	- use .user property to compose WebDAV endpoint path (fixing https://github.com/owncloud/enterprise/issues/4924 )
- OCChecksumAlgorithm: add convenience method to use OCChecksumAlgorithms for checksum calculations on NSData objects
- Server Locator: allow locating the actual server for a user via webfinger or lookup table
- OCCore+CommandLocalModification: no longer handle failure of -startAccessingSecurityScopedResource as an error, as that may indicate the inputFileURL is not actually security scoped, not that the file can't be accessed. Fixes enterprise#4934.

## 11.8.1 version
- OCSQL: add collation support via new OCSQLiteCollation class, making it as simple as possible to encapsulate and add collations, avoiding string format conversions (i.e. UTF-8 <-> UTF-16) where possible
- OCSQL: add collation OCSQLiteCollationLocalized (OCLOCALIZED) for "Finder-like" sorting
- OCDatabase+Schema: upgrade schema for metadata to use OCLOCALIZED for item name
- OAuth2 improvements
	- add authentication-oauth2.oidc-fallback-on-client-registration-failure (default: true). Allows the automatic fallback to default client_id / client_secret if OpenID Connect Dynamic Client Registration fails with any error.
	- store token expiration timespan and - if stored token expiration timespan < (safetyMargin + 20) seconds - no longer preemptively refresh the token within the safety margin
- OCConnection: remove authenticated WebDAV request asking root WebDAV endpoint for D:supported-method-set, instead rely on capabilities to respond with an authentication error if auth credentials are not valid.
- OCBookmark: add first-level support for access to the user.displayName with new property userDisplayName. The property is kept up-to-date by OCConnection, which updates it on every connect, if it was changed
- OCBookmarkManager: fix possible deadlock

## 11.8 version
- Infinite PROPFIND: add support for dav > propfind > depth_infinity capability
- OCLocale: modular localization system replacing direct system localization calls, allowing overrides via MDM and Branding.plist, adding variable support
- OCCore+FileProvider: add handling for edge case when the database is not available or not open, preventing a hang
- OCCore+ItemList: implement coordinated scan for changes
	- synchronizes scans for changes across processes
	- prioritizes scans, giving the app highest and the fileprovider second highest priority
	- consolidate related log messages under ScanChanges tag (including PollForChanges and UpdateScan)
- OCLock: add support for trying to acquire a lock and immediately returning with the result, with a new OCErrorLockInvalidated error code in case the lock couldn't be acquired
- OCSQLiteDB: disable statement caching in minimum memory configuration
- Browser Session Class: add AWBrowser to simplify configuration for AirWatch browser
- Class Settings: metadata type corrections; no longer output "computed: '<null>'" entries for class settings in the LogIntro if it is the only entry for that MDM parameter

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
