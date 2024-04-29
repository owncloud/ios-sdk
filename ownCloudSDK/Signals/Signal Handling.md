#  Signal Handling

## Introduction

The ownCloud iOS SDK faces the challenge of having to implement a distributed design and safeguard against termination with persistance while also offering a simple interface with result delivery via the convenience of blocks (closures).

Since blocks can't be persisted to disk, this required compromises like binding sync actions to the originating process for the time the originating process was around. If, however, the originating process was suspended by iOS, actions would not get executed until the originating process resumed running the Sync Engine - sometimes blocking follow-up actions started in other processes.

A dedicated Signal subsystem provides a solution to this by decoupling Sync Action processing and result delivery.

## Example flow

- `OCCore` action is initiated and a `completionHandler` is provided
- Inside the action, a new signal UUID is generated with `OCSignal.generateUUID` and saved as part of the `OCSyncAction`
- A new `OCSignalConsumer` is registered with the `OCSignalManager` for the generated signal UUID, with the `completionHandler` wrapped into a `signalHandler` that fills in `completionHandler` from a dictionary
- The `OCSignalManager` persists `OCSignalConsumer` to disk, and stores the `signalHandler`s in memory, mapped by signal UUID
- The `OCSyncAction` is executed on a different process. When it completes, it creates an `OCSignal` with the generated signal UUID and the `completionHandler` parameters inside a perstistable dictionary.
- The `OCSignal` is persisted if there's any `OCSignalConsumer` registered for it (on disk)
- The storage of the `OCSignal` triggers `OCSignalManager` in other processes to check if they have a `OCSignalConsumer` for the event - and run the `completionHandler` if one can be found

## Design
- `OCSignalRecord`s offer space for
	- one `OCSignal`
	-  `OCSignalConsumer`s, bound to a `OCBookmarkUUID`, `OCCoreRunIdentifier` and process bundle ID
- clean up when core is stopped, removing entries for that `OCCoreRunIdentifier` 
- clean up when core is started, removing entries with same process bundle ID but different `OCCoreRunIdentifier` 
- if last consumer is removed, remove record altogether
