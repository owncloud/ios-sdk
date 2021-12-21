#  Unified Remote Resource Management

The `OCResource` subsystem provides the infrastructure to
- request resources
- cache downloaded resources and deliver them from cache
- keep (versioned) resources updated with the latest remote version

## Components

### Manager
Single instance per vault for all resource types. Glues sources, storage and requests together.

### Storage
Single instance per vault for all resource types. Provides a single interface to all sources to retrieve and store resources.

### Sources
All logic that's needed to retrieve a resource - including placeholders, from cache or the server.

### Requests
Describes the resource that should be retrieved.

### Resources 
Encapsulates the resource status and the resource itself.
