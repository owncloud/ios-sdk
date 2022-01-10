#  Unified Resource Retrieval & Caching

The `OCResource` subsystem provides the infrastructure to
- request resources
- cache downloaded resources and deliver them from cache
- keep (versioned) resources updated with the latest remote version
- receive live updates to resources as they are generated / retrieved

## Components

### Manager
Single instance per vault for all resource types. Keeps track of sources, requests and storage.

### Jobs
Internal object that keeps track of relevant sources and requests (+ helps to group them).

### Storage
Protocol-based, typically implemented by `OCDatabase`, so single instance per vault for all resource types. Provides a single interface to all sources to retrieve and store resources.

### Sources
Registered with the manager, provide resources in different qualities (placeholder, remote thumbnail, locally generated thumbnail, …) with different priorities.

### Requests
Describe the requested resource. Receive updates as long as they are running.

### Resources 
Encapsulates the resource status and the resource itself.


## Internal structure
- `OCResourceManager` is created at the `OCVault` level, with `OCDatabase` as storage
- sources are added, single instance of `OCResourceSourceDatabase` looks for versions from the cache
	- sources are presorted using `priorityForType:`
- when requests are added, `OCResourceManager` proceeds as follows:
	- asks the `OCRequest` for its `relationWithRequest:` with all other running, primary requests
		- if `groupWith`, "links" the request to the other request's job
		- if `replace`, uses the request as new primary request and resets the job
		- if all return `distinct`, adds a job for the new request, with the request as a new primary request
	- for new primary requests, creates a new job and schedules it as `new`
- during scheduling, requests are processed as follows:
	- jobs with status `new` are assigned a copy of the pre-sorted sources for the request's type
	- then works through the sources from highest to lowest priority until
		- it receives the resource in a quality >= best quality returned by the sources (except the quality returned by the source returning the resource)
		- none of the resources have been able to return the resource
- instances of `OCResource` must be serializable via `NSSecureCoding` so they can be persisted and retrieved in a standardized way, regardless of their internal structure and subclass
