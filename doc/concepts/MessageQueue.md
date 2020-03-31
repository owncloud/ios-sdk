# Message Queue Overview

## Components
### Queue
- backed by `OCKeyValueStore`

### Messages
- package content like `OCSyncIssue`
	- can also store a choice by the user
- support saving a `OCBookmarkUUID` to attribute a message to a specific bookmark
- `.lockingProcess` to (temporarily) block presentation by other processes
- `.processedBy` to store which handlers in which processes have already had a chance to handle the message (to avoid repetitions)

### Presenter
- provide a priority value to indicate if a message should be presented by a presenter - and with which priority
	- the presenter with the highest priority wins
- present messages and indicate outcome via provided completionHandler
	-> can indicate if the presentation was successful
		-> can indicate if the presenter wants to be notified before the message is removed from the queue (to f.ex.allow for deletion of notifications)
	-> can indicate a user's choice for `OCSyncIssue`s

### ResponseHandler
- handle messages that have received a response
- indicate if a message was handled
	-> if it was handled, is marked as removed from the queue
	
### AutoResolver
- attempt automatic handling of messages
- can be used to f.ex. automatically resolve auth-related error messages from before the authentication error was fixed

## Flow
- queue receives message
	-> stores it to the KVS
	-> checks for suitable presenter
		- while checking, stores checked presenters in `OCMessage.processedBy` (in the form of `[processID]:[presenterID]`) to avoid duplicate presentations
		-> if one is found:
			-> locks the message via its `.lockingProcess`
			-> asks the presenter to present the message
				-> presenter calls completionHandler
					- if presentation was successful: marks message as `.presentedToUser`
					- if a sync issue choice was made: saves the choice to `.syncIssueChoice` (switching `.handled` to `YES`)
					- removes `.lockingProcess`
		-> if none is found:
			-> removes `.lockingProcess` to allow other processes to present the message

- every time a presenter or responseHandler is added; every time KVS indicates a change of values
	-> loops through all stored messages
		-> if `.handled` == `NO`: asks autoResolver to see if it can automatically handle the message
			-> if autoResolver returns `YES`: updates the message in the KVS
		-> if `.presentedToUser` == `NO` and `.handled` == `NO`
			-> checks for suitable presenter and presents the message if one is found
		-> if `.handled` == `YES`: asks responseHandlers to handle the response
			-> if responseHandler returns `YES`: sets `.removed` to `YES`
		-> if `.removed` == `YES`: checks if the presenter wanted to be notified (via `presentationRequiresEndNotification`)
			-> notifies the presenter if so, and subsequently removes the presenter info, setting `presentationRequiresEndNotification` to `NO`
			-> if `presentationRequiresEndNotification` is `NO`, removes the message
