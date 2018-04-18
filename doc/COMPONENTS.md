#  ownCloud iOS SDK Components

### Components used in the ownCloud iOS SDK - and why they were chosen

## SQLite

SQLite was chosen as local database for the cache and internal record keeping. Key motivations:
- SQLite is a proven and [reliable](https://www.sqlite.org/transactional.html) solution
- SQLite is already included in iOS, so it doesn't need to be bundled with the SDK, which would increase its size.
- Other databases would need to be included in the SDK, which could make its inclusion into projects that use the same database more complicated. With SQLite, this is less likely to be a problem as apps are more likely to link against the iOS-supplied version (which the SDK links against) than to bring and link against their own copy.

## OpenSSL

The iOS `Security.framework` does not provide the means to extract the details from a certificate that users have come to expect. To fill that gap, the `ownCloudUI.framework` uses OpenSSL for parsing certificates and making the information available through a `OCCertificate` category.

At the time of writing, this is the only use of OpenSSL in the project.

## SFAuthorizationSession

The OAuth2 Authentication Method uses `SFAuthorizationSession` to obtain a token via OAuth2, as recommended by [RFC 8252](https://tools.ietf.org/html/rfc8252#appendix-B.1). Advantages of this approach include:
- convenience: the web view provided by  `SFAuthorizationSession` and Safari on the same device share cookies
- security: the  `SFAuthorizationSession` class provides no hooks to inject code or extract data
- clean code: the direct support for a callback URL schemes makes it possible to contain the entire implementation into a single file
