//
//  OCVFSNode.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCVFSNode.h"
#import "NSData+OCHash.h"

@interface OCVFSNode ()
{
	OCVFSNodeID _identifier;
}
@end

@implementation OCVFSNode

- (OCVFSNodeID)identifier
{
	if (_identifier == nil)
	{
		NSString *hashBasis = ((_name != nil) ? [_path stringByAppendingPathComponent:_name] : _path);

		if (hashBasis != nil)
		{
			_identifier = [[[hashBasis dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] asHexStringWithSeparator:nil];
		}
	}

	return (_identifier);
}

+ (OCVFSNode *)virtualFolderAtPath:(OCPath)path withName:(NSString *)name location:(OCLocation *)location
{
	OCVFSNode *node = [self new];

	node.type = (location != nil) ? OCVFSNodeTypeLocation : OCVFSNodeTypeVirtualFolder;

	node.path = path;
	node.name = name;

	node.location = location;

	return (node);
}

@end
