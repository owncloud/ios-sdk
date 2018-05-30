# Sync Strategies
*by Felix Schwarz for ownCloud GmbH*

An overview of sync strategies for use by the ownCloud iOS SDK.

This document only covers what happens at sync time. Other UI interactions are outside the scope of this document.

# Guiding principles
1. Avoid loss of any data changed by the user - locally or remotely.
2. Be prepared for crashes.
3. Be prepared for full disks.
4. Be prepared for connection errors at any phase.
5. Be prepared for server errors and handle them gracefully.
6. When asking the user, provide as much useful information as possible to the user so he can make a qualified decision.

# Basic Algorithm
- Every Action passed to ``OCCore`` is commited as Sync Record to the Sync Journal.
- If the action affects an existing item on the server, the Sync Record contains an archived copy ("ArchCopy") of the ``OCItem`` object (incl. ETag, FileID, LastModified, Size, ..) and a timestamp of the action
- If a new action is committed for an item before a previous Sync Record for the same item had a chance to be processed, it replaces that previous Sync Record, but retains its ArchCopy.
- When the Sync Engine processes a Sync Record, it checks the version of the item on the server and compares its metadata with that of the ArchCopy:
  - If the metadata matches, it proceeds to carry out the Action stored in the Sync Engine
  - If the metadata does not match, it calls a delegate that presents an interface to the user, asking the user to decide on the resolution
  - Sync Records are removed from the Sync Journal once processed
- The Sync Engine first processes all of its records before retrieving new and changed files from the server and updating local copies as necessary.

# What happens when Sync is started
### Considerations
- ``OCCore`` keeps a cache of all information it received from the server in its ``OCDatabase``
- ``OCCore`` keeps a sync journal in its ``OCDatabase``
- ``OCCore`` keeps a list of *Available Offline* items (which can be both folders and files)

### Hitting Sync
- ``OCCore`` first processes the Sync Records in the Sync Journal
- ``OCCore`` then requests current information for all *Available Offline* items, compares it against its cached information
  - if there are no conflicts with remaining Sync Records: mirror changes locally
  - if there are conflicts with remaining Sync Records: do not make changes locally
- Note: ``OCCore`` automatically updates its cached information for all other items as the user browses to them

# Sync Engine actions / reactions
An overview over which cases actions handle - and how they handle them. Please report any missing cases, so they can be considered.

### Delete (triggered locally by user)
- **Item removed from server**: Do nothing on the server, but remove any local copy
- **Item changed on the server**: Warn the user and ask for confirmation (changes suggest the user may want to keep the item). Include last modified date of the server item and timestamp of the action.
- **Item can't be deleted from server**: Inform user and remove Sync Record.
- **Other server error**: Inform user and keep Sync Record.

### Delete (triggered by sync with remote)
- **Item removed locally**: Do nothing.
- **Item changed locally**: Warn the user and ask for confirmation (changes suggest the user may want to keep the item). Include last modified date of the local item and offer to upload it again (=> creates Upload Sync Record).

### Move / Rename
- **Item removed from server**: Upload any local copy at the new location. If there's no local copy: there's nothing useful to do, so do nothing.
- **Item changed on the server**: If the action's timestamp is newer than the change: move the file. Otherwise ask the user for confirmation.
- **Item can't be moved on server**: Inform user and remove Sync Record.
- **Other server error**: Inform user and keep Sync Record.
- Note: this action can't be reliably triggered from the server unless there is a log or sync always performs a full server scan (looking for items matching the FIleID). It is instead mimiced by the absence of a file (Delete triggered by sync with remote) and the existance of a new file ("Download").

### Create Directory
- **Item with same name and path exists on server**:
  - existing item is a directory:
    - if the user didn't also add one or more items in that directory: do nothing and remove the Sync Record.
    - if the user did also add one or more items in that directory: inform user and offer to either
      - create the directory with a different name (and adjust the pending Sync Records and local copies of any connected items inside the new directory accordingly)
      - add the items to the already existing directory on the server
  - existing item is a file:
    - prompt user for a different name for the directory (and adjust the pending Sync Records and local copies of any connected items inside the new directory accordingly)
- **Item can't be created**: Inform user and offer picking a different name, retrying or - if there are no other, dependant Sync Records - cancel the folder creation (in which case the Sync Record can be removed immediately).
- **Other server error**: Inform user and keep Sync Record.
- Note: the creation of a directory can be a prerequisite of syncing additional files that were put into the new folder to create.

### Upload
- **No Server Side Item**: Upload the file.
- **Item changed on the server**: Ask the user for confirmation.
- **Item already exists on the server**:
  - If the exact copy has been there at the time the Sync Record was committed (server item matches ArchCopy data), overwrite it.
  - If there was no copy around at the time the Sync Record was committed (no ArchCopy data), ask for confirmation.
- **Item can't be uploaded to server**: Inform user, keep Sync Record.
- **Target directory does no longer exist**: Inform user, offer to (re-)create it.
- **No space left on server**: Inform user, keep Sync Record.
- **Other server error**: Inform user, keep Sync Record.
- Note: this action - by its very nature - can only be triggered locally. Use If-Match to ensure the server only accepts a new version if the old version is still the one that the client has seen before (in case of error, the latest ETag is returned in the answer)

### Download / "Sync newer versions"
- **Item changed on the server**:
  - if a **modified local copy exists**, ask the user if the existing copy should be overwritten. Provide guidance using the lastModified dates.
  - if the **local copy is just a downloaded copy** of a previous version on the server: overwrite it without asking.
- **Disk full**: Inform user, discard Sync Record (it'll be recreated either by user action or by sync as needed).
- **Other server error**: Inform user, discard Sync Record (it'll be recreated either by user action or by sync as needed).
