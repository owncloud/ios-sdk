//
//  OCFeatureAvailability.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.12.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#ifndef OCFeatureAvailability_h
#define OCFeatureAvailability_h

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS || TARGET_OS_MACCATALYST
	#define OC_FEATURE_AVAILABLE_FILEPROVIDER 1
	#define OC_FEATURE_AVAILABLE_AUTHENTICATION_SESSION 1

	#if TARGET_OS_IOS
	// Commented out due to "ITMS-90809: Deprecated API Usage - New apps that use UIWebView are no longer accepted. Instead, use WKWebView for improved security and reliability"
	// To include UIWebView browser session support, define OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION via the build settings (preprocessor macros: "OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION=1")

	// #define OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION 1
	#endif /* TARGET_OS_IOS */
#else
	#define OC_FEATURE_AVAILABLE_FILEPROVIDER 0
	#define OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION 0
	#define OC_FEATURE_AVAILABLE_AUTHENTICATION_SESSION 0
#endif /* TARGET_OS_IOS || TARGET_OS_MACCATALYST */

#endif /* OCFeatureAvailability_h */
