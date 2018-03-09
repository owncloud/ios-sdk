#  ownCloud SDK Recipes

## A collection of recipes for common tasks.

# Getting started

## Bookmark creation
```objc
OCBookmark *bookmark;

bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
```

## Bookmark setup and authentication
This shows the complete process from a user entered URL to a complete bookmark with authentication data usable to connect to the server.
```objc
NSString *userEnteredURLString; // URL string retrieved from a text field, as entered by the user.
UIViewController *topViewController; // View controller to use as parent for presenting view controllers needed for authentication
OCBookmark *bookmark; // Bookmark from previous recipe
NSString *userName=nil, *password=nil; // Either provided as part of userEnteredURLString - or set independently
OCConnection *connection;

// Create bookmark from normalized URL (and extract username and password if included)
bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithUsername:&userName password:&password afterNormalizingURLString:userEnteredURLString protocolWasPrepended:NULL]];

if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
{
    // Prepare for setup
    [connection prepareForSetupWithOptions:nil completionHandler:^(OCConnectionIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods)
     {
         // Check for warnings and errors
         NSArray <OCConnectionIssue *> *errorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError];
         NSArray <OCConnectionIssue *> *warningAndErrorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelWarning];
         BOOL proceedWithAuthentication = YES;

         if (errorIssues.count > 0)
         {
             // Tell user it can't be done and present the issues in warningAndErrorIssues to the user
         }
         else
         {
             if (warningAndErrorIssues.count > 0)
             {
                 // Present issues contained in warningAndErrorIssues to user, then call -approve or -reject on the group issue containing all
                 if (userReviewedAndAgreedToProceedDespiteWarnings)
                 {
                     // Apply changes to bookmark
                     [issue approve];
                     proceedWithAuthentication = YES;
                 }
                 else
                 {
                     // Handle rejection as needed
                     [issue reject];
                 }
             }
             else
             {
                 // No or only informal issues. Apply changes to bookmark contained in the issues.
                 [issue approve];
                 proceedWithAuthentication = YES;
             }
         }

         // Proceed with authentication
         if (proceedWithAuthentication)
         {
             // Generate authentication data for bookmark
             [connection generateAuthenticationDataWithMethod:[preferredAuthenticationMethods firstObject] // Use most-preferred, allowed authentication method
                         options:@{
                                       OCAuthenticationMethodPresentingViewControllerKey : topViewController,
                                       OCAuthenticationMethodUsernameKey : userName,
                                       OCAuthenticationMethodPassphraseKey : password
                                }
                         completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
                                if (error == nil)
                                {
                                    // Success! Save authentication data to bookmark.
                                    bookmark.authenticationData = authenticationData;
                                    bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;

                                    // -- At this point, we have a bookmark that can be used to log into an ownCloud server --

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
     }];
}
```

# Authentication

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
