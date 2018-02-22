//
//  OCSyncRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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

#import "OCSyncRecord.h"

@implementation OCSyncRecord

@synthesize action = _action;
@synthesize timestamp = _timestamp;

@synthesize archivedServerItem = _archivedServerItem;

@synthesize parameters = _parameters;

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (NSData *)_archivedServerItemData
{
	if ((_archivedServerItemData == nil) && (_archivedServerItem != nil))
	{
		_archivedServerItemData = [NSKeyedArchiver archivedDataWithRootObject:_archivedServerItem];
	}
	
	return (_archivedServerItemData);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_action = [decoder decodeObjectOfClass:[NSString class] forKey:@"action"];
		_timestamp = [decoder decodeObjectOfClass:[NSDate class] forKey:@"timestamp"];
		_archivedServerItemData = [decoder decodeObjectOfClass:[NSDate class] forKey:@"archivedServerItemData"];
		_parameters = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"parameters"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_action forKey:@"action"];
	[coder encodeObject:_timestamp forKey:@"timestamp"];
	[coder encodeObject:[self _archivedServerItemData] forKey:@"archivedServerItemData"];
	[coder encodeObject:_parameters forKey:@"parameters"];
}

@end

OCSyncAction OCSyncActionDeleteLocal = @"deleteLocal";
OCSyncAction OCSyncActionDeleteRemote = @"deleteRemote";
OCSyncAction OCSyncActionMove = @"move";
OCSyncAction OCSyncActionCopy = @"copy";
OCSyncAction OCSyncActionCreateFolder = @"createFolder";
OCSyncAction OCSyncActionUpload = @"upload";
OCSyncAction OCSyncActionDownload = @"download";

OCSyncActionParameter OCSyncActionParameterItem = @"item";
OCSyncActionParameter OCSyncActionParameterPath = @"path";
OCSyncActionParameter OCSyncActionParameterSourcePath = @"sourcePath";
OCSyncActionParameter OCSyncActionParameterTargetPath = @"targetPath";

