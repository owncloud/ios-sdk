//
//  NSError+OCDAVError.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCXMLParser.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCDAVExceptionName;

typedef NS_ENUM(NSInteger, OCDAVError)
{
	OCDAVErrorNone = -1,

	OCDAVErrorUnknown,
	OCDAVErrorServiceUnavailable	//!< ownCloud server is in maintenance mode
};

@interface NSError (OCDAVError) <OCXMLObjectCreation>

#pragma mark - Convenience accessors
@property(readonly,nonatomic) BOOL isDAVException; //!< Returns YES if the error represents a DAV exception
@property(readonly,nonatomic) OCDAVError davError; //!< Returns the OCDAVError code. Returns OCDAVErrorNone if this error doesn't represent a OCDAVError
@property(readonly,strong,nullable,nonatomic) OCDAVExceptionName davExceptionName;
@property(readonly,strong,nullable,nonatomic) NSString *davExceptionMessage;

@end

extern NSErrorDomain OCDAVErrorDomain;

NS_ASSUME_NONNULL_END
