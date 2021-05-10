//
//  OCTUSHeader.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCHTTPTypes.h"
#import "NSString+TUSMetadata.h"
#import "OCChecksum+TUS.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCTUSVersion;
typedef NSString* OCTUSExtension NS_TYPED_ENUM;
typedef NSString* OCTUSHeaderName NS_TYPED_ENUM;

typedef NSString* OCTUSUploadTag;

typedef NSString* OCTUSCapabilityKey NS_TYPED_ENUM;
typedef NSDictionary<OCTUSCapabilityKey,id>* OCTUSCapabilities;

typedef NS_OPTIONS(UInt8, OCTUSSupport)
{
	OCTUSSupportNone,
	OCTUSSupportAvailable = (1<<0),
	OCTUSSupportExtensionCreation = (1<<1),
	OCTUSSupportExtensionCreationWithUpload = (1<<2),
	OCTUSSupportExtensionExpiration = (1<<3),
	OCTUSSupportExtensionChecksum = (1<<4),
	OCTUSSupportExtensionPartialChecksum = (1<<5),
	OCTUSSupportExtensionUploadTag = (1<<6)
};

typedef NS_OPTIONS(UInt8, OCTUSChecksumAlgorithmSupport)
{
	OCTUSChecksumAlgorithmSupportNone,
	OCTUSChecksumAlgorithmSupportSHA1
};

typedef struct {
	UInt8 reserved : 4;
	OCTUSChecksumAlgorithmSupport checksumAlgorithmSupport : 4;
	UInt64 maximumSize : 48;
	OCTUSSupport tusSupport : 8;
} _OCTUSInfoPrivate;

typedef UInt64 OCTUSInfo; // encodes OCTUSSupport, maxSize and more (format is OCTUSInfoPrivate)

#define OCTUSInfoGetSupport(info) 		((_OCTUSInfoPrivate *)&info)->tusSupport
#define OCTUSInfoSetSupport(info,flags) 	((_OCTUSInfoPrivate *)&info)->tusSupport = (flags)

#define OCTUSInfoGetChecksumAlgorithmSupport(info) 		((_OCTUSInfoPrivate *)&info)->checksumAlgorithmSupport
#define OCTUSInfoSetChecksumAlgorithmSupport(info,algorithms) 	((_OCTUSInfoPrivate *)&info)->checksumAlgorithmSupport = (algorithms)

#define OCTUSInfoGetMaximumSize(info) 		((_OCTUSInfoPrivate *)&info)->maximumSize
#define OCTUSInfoSetMaximumSize(info,maxSize) 	((_OCTUSInfoPrivate *)&info)->maximumSize = (maxSize)

#define OCTUSIsSupported(support,flag) 		((support & flag) == flag)
#define OCTUSIsAvailable(support) 		OCTUSIsSupported(support,OCTUSSupportAvailable)

@interface OCTUSHeader : NSObject <NSSecureCoding>

@property(strong,nullable) OCTUSVersion version; 		//!< Corresponds to "Tus-Resumable"
@property(strong,nullable) NSArray<OCTUSVersion> *versions; 	//!< Corresponds to "Tus-Version" header (where available), with fallback to "Tus-Resumable"
@property(strong,nullable) NSArray<OCTUSExtension> *extensions; //!< Corresponds to "Tus-Extension" header
@property(strong,nullable) NSArray<OCChecksumAlgorithmIdentifier> *checksumAlgorithms; //!< Corresponds to "Tus-Checksum-Algorithm" header

@property(strong,nullable) NSNumber *maximumSize;		//!< Corresponds to "Tus-Max-Size" header (maximum size of entire upload)
@property(strong,nullable) NSNumber *maximumChunkSize;		//!< Maximum chunk size to apply

@property(strong,nullable) NSNumber *uploadOffset;		//!< Corresponds to "Upload-Offset" header
@property(strong,nullable) NSNumber *uploadLength;		//!< Corresponds to "Upload-Length" header

@property(strong,nullable) OCChecksum *uploadChecksum;		//!< Corresponds to "Upload-Checksum" header
@property(strong,nullable) OCTUSUploadTag uploadTag;		//!< Corresponds to "Upload-Tag" header

@property(strong,nonatomic,nullable) OCTUSMetadata uploadMetadata;		//!< Corresponds to "Upload-Metadata" (parsed)
@property(strong,nonatomic,nullable) OCTUSMetadataString uploadMetadataString;	//!< Corresponds to "Upload-Metadata" (raw)

@property(readonly,nonatomic,nullable) OCHTTPHeaderFields httpHeaderFields;

@property(readonly,nonatomic) OCTUSSupport supportFlags;				//!< Returns TUS support info compressed as set of flags
@property(readonly,nonatomic) OCTUSChecksumAlgorithmSupport checksumAlgorithmFlags;	//!< Returns TUS checksum algorithm support info compressed as set of flags
@property(readonly,nonatomic) OCTUSInfo info;						//!< Returns TUS info compressed to an integer

- (instancetype)initWithHTTPHeaderFields:(OCHTTPStaticHeaderFields)headerFields;
- (instancetype)initWithTUSInfo:(OCTUSInfo)info;

@end

extern const OCTUSHeaderName OCTUSHeaderNameTusVersion;
extern const OCTUSHeaderName OCTUSHeaderNameTusResumable;
extern const OCTUSHeaderName OCTUSHeaderNameTusExtension;
extern const OCTUSHeaderName OCTUSHeaderNameTusMaxSize;
extern const OCTUSHeaderName OCTUSHeaderNameTusChecksumAlgorithm;
extern const OCTUSHeaderName OCTUSHeaderNameUploadOffset;
extern const OCTUSHeaderName OCTUSHeaderNameUploadLength;
extern const OCTUSHeaderName OCTUSHeaderNameUploadMetadata;
extern const OCTUSHeaderName OCTUSHeaderNameUploadChecksum;
extern const OCTUSHeaderName OCTUSHeaderNameUploadTag;

extern const OCTUSExtension OCTUSExtensionCreation;
extern const OCTUSExtension OCTUSExtensionCreationWithUpload;
extern const OCTUSExtension OCTUSExtensionExpiration;
extern const OCTUSExtension OCTUSExtensionChecksum;
extern const OCTUSExtension OCTUSExtensionPartialChecksum;
extern const OCTUSExtension OCTUSExtensionUploadTag;

NS_ASSUME_NONNULL_END
