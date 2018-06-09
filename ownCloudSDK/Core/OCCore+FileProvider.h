//
//  OCCore+FileProvider.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>

@interface OCCore (FileProvider)

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError *error, OCSyncAnchor syncAnchor, OCItem *itemFromDatabase))completionHandler;
- (NSURL *)localURLForItem:(OCItem *)item;

@end
