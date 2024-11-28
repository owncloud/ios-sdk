//
//  GAGraphStruct+Encoder.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.11.24.
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

#import <Foundation/Foundation.h>

#define GA_ENC_INIT \
	GAGraphStruct graphStruct = [NSMutableDictionary new]; \
	NSError *error = nil;
#define GA_ENC_ADD(var,jsName,req) \
 	if ((error = [graphStruct set:var forKey:@jsName required:req context:nil]) != nil) { \
 		if (outError != NULL) { *outError = error; } \
 		return(nil); \
	}
#define GA_ENC_RETURN return (graphStruct);

NS_ASSUME_NONNULL_BEGIN

@class GAGraphContext;

@interface NSMutableDictionary (GAGraphDataEncoder)

- (nullable NSError *)set:(nullable id<NSObject>)value forKey:(NSString *)key required:(BOOL)required context:(nullable GAGraphContext *)context;

@end

NS_ASSUME_NONNULL_END
