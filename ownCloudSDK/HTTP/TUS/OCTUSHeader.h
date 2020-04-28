//
//  OCTUSHeader.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCHTTPTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCTUSVersion;
typedef NSString* OCTUSExtension;

typedef NSString* OCTUSHeaderJSON;

typedef NS_OPTIONS(UInt8, OCTUSSupport)
{
	OCTUSSupportNone,
	OCTUSSupportAvailable = (1<<0),
	OCTUSSupportExtensionCreation = (1<<1),
	OCTUSSupportExtensionCreationWithUpload = (1<<2),
	OCTUSSupportExtensionExpiration = (1<<3)
};

typedef struct {
	UInt8 reserved : 8;
	UInt64 maximumSize : 48;
	OCTUSSupport tusSupport : 8;
} OCTUSInfoPrivate;

typedef UInt64 OCTUSInfo; // encodes OCTUSSupport, maxSize and more

#define OCTUSInfoGetSupport(info) 		((OCTUSInfoPrivate *)&info)->tusSupport
#define OCTUSInfoSetSupport(info,flags) 	((OCTUSInfoPrivate *)&info)->tusSupport = (flags)

#define OCTUSInfoGetMaximumSize(info) 		((OCTUSInfoPrivate *)&info)->maximumSize
#define OCTUSInfoSetMaximumSize(info,maxSize) 	((OCTUSInfoPrivate *)&info)->maximumSize = (maxSize)

@interface OCTUSHeader : NSObject // <NSSecureCoding>

@property(strong,nullable) OCTUSVersion version; 		//!< Corresponds to "Tus-Resumable"
@property(strong,nullable) NSArray<OCTUSVersion> *versions; 	//!< Corresponds to "Tus-Version" header (where available), with fallback to "Tus-Resumable"
@property(strong,nullable) NSArray<OCTUSExtension> *extensions; //!< Corresponds to "Tus-Extension" header

@property(strong,nullable) NSNumber *maximumSize;		//!< Corresponds to "Tus-Max-Size" header

@property(strong,nullable) NSNumber *uploadOffset;		//!< Corresponds to "Upload-Offset" header
@property(strong,nullable) NSNumber *uploadLength;		//!< Corresponds to "Upload-Length" header

@property(readonly,nonatomic) OCTUSSupport supportFlags;	//!< Returns TUS support info compressed as set of flags
@property(readonly,nonatomic) OCTUSInfo info;			//!< Returns TUS info compressed to an integer

- (instancetype)initWithHTTPHeaderFields:(OCHTTPHeaderFields)headerFields;
//- (OCHTTPHeaderFields)httpHeaderFields;

//- (instancetype)initWithHeaderJSON:(OCTUSHeaderJSON)headerJSON;
//- (OCTUSHeaderJSON)headerJSON;

@end

NS_ASSUME_NONNULL_END
