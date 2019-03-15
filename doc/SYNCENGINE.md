# Sync Engine Internals

The Sync Engine is part of the `OCCore`.

## Concurrency Concept (WIP)

- every sync record gets one or more concurrency tags
- in order to get executed, no previously scheduled, running sync record may be active whose concurrency tags *contain* any of the sync record's concurrenty tags
	- *contain* in this context means that a previous sync record's tag `/Pictures/Photo.jpg` blocks the execution of a subsequent sync record tagged `/Pictures/`, but not `/Pictures/OtherPic.jpg`
- concurrency tags typically are
	- the `localID` of the item the sync action affects (like the item itself, but also the localID of source/old and desintation/new parent items)
	- the source/old and destinaton/new path of the item the sync action affects
	
### Examples
The following examples don't take local optimizations to be introduced by full offline support into account (like a delete cancelling a download or upload of the same item).

#### Deleting a folder from which a file is to be moved before
- Action A: User wants to move `/Pictures/Photo.jpg` to `/Documents/`
- Action B: User wants to then delete `/Pictures/`
- Action A is performed, but Action B is blocked because `/Pictures/` is contained in Action A's tags.
- Once Action A is finished, Action B is performed
- The result is that `Photo.jpg` is now in `/Documents/` and `/Pictures/` has been removed. Without blocking, `Photo.jpg` could have been lost.

#### Deleting a folder to which a file is to be moved before
- Action A: User wants to move `/Pictures/Photo.jpg` to `/Documents/`
- Action B: User wants to then delete `/Documents/`
- Action A is performed, but Action B is blocked because `/Documents/` is contained in Action A's tags.
- Once Action A is finished, Action B is performed
- The result is that `Photo.jpg` is gone along with  `/Documents/`. Without blocking, moving `Photo.jpg` could have resulted in an error and the file still be around.

#### Downloading multiple files
- User wants to download  `/Pictures/Photo.jpg` (A) and `/Pictures/Comic.jpg` (B)
- Since  `/Pictures/Comic.jpg` is not contained in  `/Pictures/Photo.jpg` , the two records get executed in parallel

#### Download multiple files and move the parent folder
- User wants to download  `/Pictures/Photo.jpg` (A) and `/Pictures/Comic.jpg` (B)
- User wants to move `/Pictures/` to `/Images/Pictures/` (C)
- A and B don't block each other and get executed in parallel
- C is blocked until A and B have finished
- The result is that the downloads and rename succeed. Without blocking, one or both files could possibly no longer have been found.

#### Download file, remote rename and deletion
- Action A: user wants to download `/Pictures/Photo.jpg` (Local ID: `ABC`)
- Action B: remote user renames  `/Pictures/Photo.jpg` to `/Pictures/Zoo.jpg`
- Action C: user wants to delete `/Pictures/Zoo.jpg`
- A is performed and begins downloading, B is performed on the server by another user
- C is blocked by A because  `/Pictures/Zoo.jpg` has the same Local ID as `/Pictures/Photo.jpg`
- The result is what one would expect. Without blocking, the file could have been deleted completing the download.

#### Duplicate file, delete duplicate
- Action A: user duplicates file `/Pictures/Photo.jpg` to `/Pictures/Photo 2.jpg`
- Action B: user deletes `/Pictures/Photo 2.jpg`
- B is blocked until B is finished
- The result is what one would expect. Without blocking, deleting the duplicate file could have produced an error, while the duplicate file could be present shortly after.

#### Parallel upload and download
- Action A: user uploads `/Pictures/New.jpg`
- Action B: user downloads `/Pictures/Photo.jpg`
- Both actions are performed at the same time

# Historic

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


