//
//  OCConnectionDAVRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
