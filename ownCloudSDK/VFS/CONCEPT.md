#  Virtual File System concept

## Goals
- allow mixing virtual folder structure with actual content
	- represent drives as virtual folders
	- allow placing virtual folders amidst actual content
- satisfy FileProvider requirements:
	- conversion: FPItemURL -> PersistentItemID (sync)
	- conversion: PersistentItemID -> FPItemURL (sync)
	- conversion: ItemID -> Item (sync)
	- ItemID -> Enumerator (sync)
	- Item needs to comply to NSFileProviderItem (sync)
		- required properties (as per header):
			- itemIdentifier
			- parentItemIdentifier
			- filename
		- more required properties (as per doc):
			- contentType (-> folder - or file type as UTI)
			- capabilities (-> permissions)
	- ItemID -> Thumbnail (async)

## Implementation
- OCVault / OCVaultLocation
	- performs necessary mappings as required by FP
		- including mapping of virtual nodes/virtual node IDs from/to FPItemURLs
- VFSNode
	- represents a file or folder
	- builds a tree
- VFSCore
	- method to retrieve contents of a virtual node as VFSContent, providing:
		- contained VFSNode child nodes
		- OCQuery + OCCore (where applicable)
		- automatic return of a requested OCCore via OCCoreManager upon deallocation
	[- method that, for a node, returns an object that conforms to a `VFSItem` protocol describing the item (this can of course also be the node or item itself, but gives a hook for future customizations)]
- VFSItemID string addressing scheme
	- using "\" as separator, not ":", because that might also be used in ocis identifiers
	- Real items: 	 I\[bookmarkUUID]\[driveID]\[localID][\[fileName]]
	- Virtual items: V\[bookmarkUUID]\[driveID] or V\[vfsNodeID]
