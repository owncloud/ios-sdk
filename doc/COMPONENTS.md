#  ownCloud iOS SDK Components

### Components used in the ownCloud iOS SDK - and why they were chosen

## SQLite

SQLite was chosen as local database for the cache and internal record keeping. Key motivations:
- SQLite is a proven and [reliable](https://www.sqlite.org/transactional.html) solution
- SQLite is already included in iOS, so it doesn't need to be bundled with the SDK and increase size
- Other databases would need to be included in the SDK, which could make its inclusion into projects that use the same database harder. With SQLite, this is less likely to be a problem as apps are more likely to link against the iOS-supplied version (which the SDK links against) than to bring and link against their own copy.


