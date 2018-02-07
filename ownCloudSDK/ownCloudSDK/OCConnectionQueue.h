//
//  OCConnectionQueue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCConnectionQueue : NSObject

/*
	TODO: Connection queue supporting
	- different priorities
	- grouping requests
	- cancelling requests (single + group)
	- use NSURLSession and tasks under the hood, support background session
*/

@end
