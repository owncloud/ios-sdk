#  ownCloud iOS SDK Components

### Components used in the ownCloud iOS SDK - and why they were chosen

## SQLite

### General

SQLite was chosen as local database for the cache and internal record keeping. Key motivations:
- SQLite is a proven and [reliable](https://www.sqlite.org/transactional.html) solution
- SQLite is already included in iOS, so it doesn't need to be bundled with the SDK, which would increase its size.
- Other databases would need to be included in the SDK, which could make its inclusion into projects that use the same database more complicated. With SQLite, this is less likely to be a problem as apps are more likely to link against the iOS-supplied version (which the SDK links against) than to bring and link against their own copy.

### Thumbnail Cache

Thumbnails are stored *in* the SQLite database rather than directly in the filesystem, based on the following considerations:

#### Average Thumbnail Size
The average thumbnail size, even at 384 x 384 pixels, is still just 14 KB. For 256 x 256, it's a mere 7.6 KB.

Max Size (pixels) | Average size
:---: | ----:
64 x 64		  | `1.371` bytes
128 x 128	  | `2.858` bytes
256 x 256	  | `7.591` bytes
384 x 384	  | `14.244` bytes

#### Speed
At [these sizes](https://www.sqlite.org/fasterthanfs.html), SQLite provides a [speed advantage](https://www.sqlite.org/intern-v-extern-blob.html) over splitting the cache in database and thumbnail files. Based on the [default page size](https://www.sqlite.org/pgszchng2016.html) of SQLite databases of 4096 bytes, SQLite should provide a performance advantage up to a thumbnail file size of 50 KB.

#### Atomicity
Rather than having to keep track of the database entries and file system objects separately, the implementation can take advantage of all benefits of an ACID-compliant database and transactions.

## OpenSSL

The iOS `Security.framework` does not provide the means to extract the details from a certificate that users have come to expect. To fill that gap, the `ownCloudUI.framework` uses OpenSSL for parsing certificates and making the information available through a `OCCertificate` category.

At the time of writing, this is the only use of OpenSSL in the project.

## SFAuthorizationSession

The OAuth2 Authentication Method uses `SFAuthorizationSession` to obtain a token via OAuth2, as recommended by [RFC 8252](https://tools.ietf.org/html/rfc8252#appendix-B.1). Advantages of this approach include:
- convenience: the web view provided by  `SFAuthorizationSession` and Safari on the same device share cookies
- security: the  `SFAuthorizationSession` class provides no hooks to inject code or extract data
- clean code: the direct support for a callback URL schemes makes it possible to contain the entire implementation into a single file

## ISRunLoopThread

[ISRunLoopThread](https://gist.github.com/felix-schwarz/9fa9055b6ade900f1f21) pairs the benefits of a serial dispatch queue with those of an NSRunLoop-based single-thread environment, making it a great choice to isolate OCSQLite's SQLite calls to a single thread.
