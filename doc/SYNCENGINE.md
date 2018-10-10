# Sync Engine Internals

The Sync Engine is part of the `OCCore`.

## Lifecycle

Here are the stages an action (like copy, delete, download) passed through during its lifecycle:

### Action method call

Every action supported by the `OCCore` has its own method, which typically takes an item, parameters and a resultHandler.

In that method, early/basic checks can be performed to catch invalid action requests early.

If all early/basic checks pass, the action packages everything into an `OCSyncRecord` and submits it to the Sync Engine.

### Reception by to the Sync Engine

The `OCSyncRecord` containing the packaged action is added to the core's database and its `recordID` populated with the row ID at which it was inserted.

### Preflight

If an action has a pre-flight step, the Sync Engine:
- retrieves all existing sync records for the same path and action (including the one just added)
- calls the preflight method of the `OCCoreSyncAction` with a `OCCoreSyncContext` in which it provides the *existingRecords* and the *syncRecord* to preflight
- on return, the sync context's 
    - *addedItems*, *removedItems*, *updatedItems*, *refreshPaths* and *removeRecords* are merged.
    - an *error* will remove the sync record and call the resultHandler.

If an action wants to cancel its own sync record during pre-flight, it should return an *error* and (optionally) include its sync record in *removeRecords*.

### Deschedule

This method is only called if `-[OCCore descheduleSyncRecord:]` was called to remove a sync record, for example in an issue in response to a user cancelling an action. It is supposed to revert any changes made in preflight.

### Schedule

If it's an action's sync record's turn, the Sync Engine will call the schedule method with a `OCCoreSyncContext` , which will then initiate the actual action via the core's `OCConnection`.

### Result Handling

Once the core's `OCConnection` has completed the action, it returns the result to the Sync Engine, which passes it on to the Sync Engine's result handling method.

