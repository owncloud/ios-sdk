//
//  OCConnection+SharingLegacy.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "OCXMLParser.h"
#import "OCFeatureAvailability.h"

// OC 10
#if OC_LEGACY_SUPPORT

NS_ASSUME_NONNULL_BEGIN

@interface OCSharingResponseStatus : NSObject <OCXMLObjectCreation>

@property(strong) NSString *status;
@property(strong) NSNumber *statusCode;

@property(strong) NSString *message;

@property(strong,nonatomic) NSError *error;

@end

@interface OCConnection (SharingLegacy)

// MARK: - Internal
- (NSArray<OCShare *> *)_parseSharesResponse:(OCHTTPResponse *)response data:(NSData *)responseData category:(OCShareCategory)shareCategory error:(NSError **)outError status:(OCSharingResponseStatus * _Nullable * _Nullable)outStatus statusErrorMapper:(NSError*(^)(OCSharingResponseStatus *status))statusErrorMapper;

// MARK: - Legacy implementations
- (nullable OCProgress *)legacyCreateShare:(OCShare *)share options:(nullable OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget;
- (nullable OCProgress *)legacyUpdateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges resultTarget:(OCEventTarget *)eventTarget;

@end

NS_ASSUME_NONNULL_END

#endif /* OC_LEGACY_SUPPORT */
