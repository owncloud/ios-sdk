//
//  OCHTTPDAVRequest.h
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

#import "OCHTTPRequest.h"
#import "OCXMLNode.h"
#import "OCHTTPDAVMultistatusResponse.h"
#import "OCTypes.h"
#import "OCItem.h"
#import "OCUser.h"

@interface OCHTTPDAVRequest : OCHTTPRequest <NSXMLParserDelegate>
{
	// Parsing variables
	OCItem *_parseItem;
	NSMutableArray <OCItem *> *_parseResultItems;
	NSError *_parseError;
	
	NSMutableArray <NSString *> *_parseTagPath;
	NSMutableDictionary <OCPath, OCHTTPDAVMultistatusResponse *> *_parsedResponsesByPath;

	NSString *_parseCurrentElement;
}

@property(strong) OCXMLNode *xmlRequest;

+ (instancetype)propfindRequestWithURL:(NSURL *)url depth:(NSUInteger)depth;
+ (instancetype)proppatchRequestWithURL:(NSURL *)url content:(NSArray <OCXMLNode *> *)contentNodes;
+ (instancetype)reportRequestWithURL:(NSURL *)url rootElementName:(NSString *)rootElementName content:(NSArray <OCXMLNode *> *)contentNodes;

- (OCXMLNode *)xmlRequestPropAttribute;

- (NSArray <OCItem *> *)responseItemsForBasePath:(NSString *)basePath reuseUsersByID:(NSMutableDictionary<NSString *,OCUser *> *)usersByUserID withErrors:(NSArray <NSError *> **)errors;
- (NSDictionary <OCPath, OCHTTPDAVMultistatusResponse *> *)multistatusResponsesForBasePath:(NSString *)basePath;

@end
