//
//  OCXMLParserElement.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCXMLParser.h"

@interface OCXMLParserElement : NSObject <OCXMLElementParsing>
{
	NSMutableDictionary <NSString *, id> *_keyValues;
	NSMutableArray <OCXMLElementParser> *_children;
}

@property(strong) NSString *elementName;
@property(strong) NSDictionary <NSString*,NSString*> *attributes;
@property(strong) NSMutableDictionary <NSString *, id> *keyValues;
@property(strong) NSMutableArray <OCXMLElementParser> *children;

@end
