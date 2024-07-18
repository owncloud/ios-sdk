#  Item Policies

## Introduction
The Item Policy system in `OCCore` provides the infrastructure to run code (more generally) / process items (more specifically) in response to specific events, which can be of different scope.

Currently, the Item Policy system is used to implement features like:

#### Available Offline
Automatically download files and folders that are marked as Available Offline (and keep them updated).

#### Download Expiration
Automatically removes downloaded files X seconds after they have last been used by the user.

#### Vacuum
Removes files and folders from the filesystem that belong to items that have been deleted on the server/client.

#### Version Updates
When a file is updated on the server, removes the outdated local copy if it is not used - or - automatically downloads the latest version if the local copy is currently accessed read-only.


## Components
The Item Policy system is built from different components:

### Item Policy (`OCItemPolicy`)
Item policies are lightweight objects that
- target a set of items that should be processed, using an `OCQueryCondition` (`condition`)
- are associated with an Item Policy Processor (linked by `OCItemPolicyKind`) that will process matching items (`kind`)
- are persisted in and managed by `OCDatabase` across processes and relaunches
- can provide a method and query condition on when the policy should automatically be removed (`policyAutoRemovalMethod`, `policyAutoRemovalCondition`)

For convenience, `OCItemPolicy` also offers additional properties to store information for direct usage by Item Policy Processors.

### Item Policy Processor (`OCItemPolicyProcessor`)
Item Policy Processors (IPP) provide the actual implementation to process the items that match Item Policies of the same kind (`OCItemPolicyKind`) as the Item Policy Processor.

Item Policy Processors can add additional conditions and entry points:
- `policyCondition`: a query condition matching items that a policy should be run for - in addition to existing Item Policies. Useful to implement IPPs with an - effectively - built-in Item Policy.
- `matchCondition`: only items passing this query condition are actually processed by the Item Policy Processor.
- `cleanupCondition`: items matching this query condition are considered to require cleanup after processing and go through the IPP's cleanup.

### Triggers
Item Policy Processors are run on one or more Triggers:

- `ItemsChanged`: triggered whenever items change (f.ex. following sync actions, PROPFINDs, etc.)
- `ItemListUpdateCompleted`: triggered whenever an item list update was completed with changes and the database of cache items is considered consistent with server contents
- `ItemListUpdateCompletedWithoutChanges`: triggered whenever an item list update was completed without changes and the database of cache items is considered consistent with server contents
- `PoliciesChanged`: triggered whenever an item policy was added, removed or updated
- `All`: on all of the above Triggers


## Call Pattern
When a trigger is hit in `OCCore`, it goes through the registered Item Policy Processors (IPPs) and makes the following calls:
- `performPreflightOnPoliciesWithTrigger:withItems:`: allows the IPP to go through (and update) its policies based on the passed items. Items are only passed as they are added, updated or removed. The Available Offline IPP f.ex. uses this to update the paths and locations of its Item Policies as folders are moved or renamed.
- `willEnterTrigger:`: tells the IPP that the Core will make further calls for the passed Trigger
- check if `matchCondition` is not `nil` and, if it is not, loops through the trigger's matching items, calling:
   - `beginMatchingWithTrigger:` before the first item
   - `performActionOn:withTrigger:` for every matching item. This is typically where an IPP schedules actions.
   - `endMatchingWithTrigger:` after the last item
   - none of the above three methdos is called if no items match `matchCondition`
- check if `cleanupCondition` is not `nil` and, if it is not, loops through the trigger's matching items, calling:
   - `beginCleanupWithTrigger:` before the first item
   - `performCleanupOn:withTrigger:` for every matching item. This is typically where an IPP schedules actions.
   - `endCleanupWithTrigger:` after the last item
   - none of the above three methdos is called if no items match `cleanupCondition`
- `didPassTrigger:`: tells the IPP that the Core is finished with it for the passed Trigger
