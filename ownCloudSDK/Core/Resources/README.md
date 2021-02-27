#  Unified Remote Resource Management

The `OCResource` subsystem provides the infrastructure to
- request resources
- cache downloaded resources and deliver them from cache
- keep (versioned) resources updated with the latest remote version

## Components

### Cache
Single instance per account for all resource types. Provides a single interface to all sources to retrieve and store resources. Could keep a memory cache for extra performance.

### Sources
All logic that's needed to retrieve a resource - including placeholders, from cache or the server.

### Requests
Describes the resource that should be retrieved.

### Resources 
Encapsulates the resource status and the resource itself.
