//
//  OCConnectionDAVRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCConnectionRequest.h"
#import "OCXMLNode.h"

@interface OCConnectionDAVRequest : OCConnectionRequest
{
	OCXMLNode *_xmlRequest;
}

@property(strong) OCXMLNode *xmlRequest;

+ (instancetype)propfindRequestWithURL:(NSURL *)url depth:(NSUInteger)depth;

- (OCXMLNode *)xmlRequestPropAttribute;

@end
