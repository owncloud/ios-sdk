//
// GAVideo.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

// occgen: includes
#import <Foundation/Foundation.h>
#import "GAGraphObject.h"

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GAVideo : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong, nullable) NSNumber *audioBitsPerSample; //!< [integer:int32] Number of audio bits per sample.
@property(strong, nullable) NSNumber *audioChannels; //!< [integer:int32] Number of audio channels.
@property(strong, nullable) NSString *audioFormat; //!< Name of the audio format (AAC, MP3, etc.).
@property(strong, nullable) NSNumber *audioSamplesPerSecond; //!< [integer:int32] Number of audio samples per second.
@property(strong, nullable) NSNumber *bitrate; //!< [integer:int32] Bit rate of the video in bits per second.
@property(strong, nullable) NSNumber *duration; //!< [integer:int64] Duration of the file in milliseconds.
@property(strong, nullable) NSString *fourCC; //!< \"Four character code\" name of the video format.
@property(strong, nullable) NSNumber *frameRate; //!< [number:double] Frame rate of the video.
@property(strong, nullable) NSNumber *height; //!< [integer:int32] Height of the video, in pixels.
@property(strong, nullable) NSNumber *width; //!< [integer:int32] Width of the video, in pixels.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

