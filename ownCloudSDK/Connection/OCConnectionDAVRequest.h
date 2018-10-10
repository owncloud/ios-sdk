//
//  OCConnectionDAVRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
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

#import "OCConnectionRequest.h"
#import "OCXMLNode.h"

@interface OCConnectionDAVRequest : OCConnectionRequest <NSXMLParserDelegate>
{
	OCXMLNode *_xmlRequest;

	// Parsing variables
	OCItem *_parseItem;
	NSMutableArray <OCItem *> *_parseResultItems;
	NSError *_parseError;
	
	NSMutableArray <NSString *> *_parseTagPath;
	
	NSString *_parseCurrentElement;
}

@property(strong) OCXMLNode *xmlRequest;

+ (instancetype)propfindRequestWithURL:(NSURL *)url depth:(NSUInteger)depth;

- (OCXMLNode *)xmlRequestPropAttribute;

- (NSArray <OCItem *> *)responseItemsForBasePath:(NSString *)basePath;

@end
