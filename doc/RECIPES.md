#  ownCloud SDK Recipes

## A collection of recipes for common tasks.

# Authentication

## Bookmark creation
```objc
OCBookmark *bookmark;

bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
```

## Bookmark setup (WORK IN PROGRESS)
```objc
OCBookmark *bookmark; // Bookmark from previous recipe
OCConnection *connection;

if (connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
{
	[connection prepareForSetupWithOptions:@{ OCAuthenticationMethodAllowURLProtocolUpgradesKey : @(YES) }
	                     completionHandler:^(OCConnectionPrepareResult result, NSError *error, NSData *certificateData, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods)
	{
		/***** WORK IN PROGRESS ****/
	
		switch (result)
		{
			case OCConnectionPrepareResultSuccess:
				NSLog(@"Preparation successful!");

				bookmark.certificateData = certificateData;
				bookmark.certificateModificationDate = [NSDate date];

				// -> Proceed
			break;

			case OCConnectionPrepareResultError:
				// Display error to user
				NSLog(@"Preparation failed with error: %@", error);
			break;

			case OCConnectionPrepareResultURLChangedByUpgrading:
				// The suggestedURL is an upgraded version (http->https) of the previous URL and otherwise identical.

				connection.bookmark.url = suggestedURL;

				bookmark.certificateData = certificateData;
				bookmark.certificateModificationDate = [NSDate date];

				// -> Proceed
			break;
			
			case OCConnectionPrepareResultURLChangedSignificantly:
				// The suggestedURL presents a significant change from the bookmark's URL.
				// Prompt user for confirmation

				if (resultOfPromptingUserForConfirmation)
				{
					connection.bookmark.url = suggestedURL;

					bookmark.certificateData = certificateData;
					bookmark.certificateModificationDate = [NSDate date];

					// -> Proceed
				}
			break;
		}
	}];
}

```


## Get OAuth2 token for Bookmark and store it permanently
```objc
OCBookmark *bookmark; // Bookmark from previous recipe
OCConnection *connection;
UIViewController *topViewController; // View controller to use as parent for presenting view controllers needed for authentication

if (connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
{
    [connection generateAuthenticationDataWithMethod:OCAuthenticationMethodOAuth2Identifier
                options:@{ OCAuthenticationMethodPresentingViewControllerKey : topViewController }
                completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
                    if (error == nil)
                    {
                        // Success! Save authentication data to bookmark.
                        bookmark.authenticationData = authenticationData;
                        bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
                        
                        // Serialize bookmark and write it to a file on disk
                        [[bookmark bookmarkData] writeToFile:.. atomically:YES];
                    }
                    else
                    {
                        // Failure
                        NSLog(@"Could not get token (error: %@)", error);
                    }
                }
    ];
}
```

## Authenticate to server using stored OAuth2 token, request root directory items and print them to the log
```objc
OCBookmark *bookmark; // Bookmark with OAuth2 token from previous recipe
OCCore *core;

if (core = [[OCCore alloc] initWithBookmark:bookmark]) != nil)
{
    OCQuery *rootQuery;
    
    // Create a query for the root directory
    rootQuery = [OCQuery queryForPath:@"/"];

    // Provide a block that is called every time there's a query result update available
    rootQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
        // Request the latest changes
        [query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
            if (changeset != nil)
            {
                NSLog(@"Latest contents of root directory:");
                for (OCItem *item in changeset.queryResult)
                {
                    NSLog(@"%@", item.name);
                }
                
                NSLog(@"Insertions since last update:");
                for (OCItem *item in changeset.insertedItems)
                {
                    NSLog(@"%@", item.name);
                }

                NSLog(@"Removed since last update:");
                for (OCItem *item in changeset.removedItems)
                {
                    NSLog(@"%@", item.name);
                }

                NSLog(@"Updated since last update:");
                for (OCItem *item in changeset.updatedItems)
                {
                    NSLog(@"%@", item.name);
                }
            }
        }];
    };

    [core startQuery:rootQuery];
}
```

