# Signal Handling

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

### Signals firing a single or multiple times
Signals can fire
	- only once (to signal one-time events like the completion of a task)
	- multiple times (to signal f.ex. progress updates) until eventually signalling termination of a task

A signal can indicate if it is terminating the signal via `OCSignal.terminatesConsumersAfterDelivery`, which defaults to `YES` by default.
If a signal will be used to deliver updates, that property should be set to `NO` until the final update, which should then be set to `YES`.

Consumers themselves can also exercise control over how many times they want to consume a signal through `OCSignalConsumer.deliveryBehaviour`:
- if set to `OCSignalDeliveryBehaviourOnce` the consumer will only receive the signal once and then be removed.
- if set to `OCSignalDeliveryBehaviourUntilTerminated` the consumer will receive signals whenever they change, until `terminatesConsumersAfterDelivery` is `YES`, at which point the consumer weill be removed.

### Signal versioning
Since signals can fire more than once, they are versioned to ensure each version is only delivered once. The `OCSignalManager` takes care of incrementing the version with every update, whereas `OCSignalConsumer` tracks the last delivered version and will only be signalled if a signal's version differs from the last delivered one.
