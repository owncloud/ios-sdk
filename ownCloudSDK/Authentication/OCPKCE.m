//
//  OCPKCE.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.06.19.
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

#import "OCPKCE.h"
#import "NSString+OCRandom.h"
#import "NSData+OCHash.h"

@interface OCPKCE ()
{
	OCPKCECodeChallenge _codeChallenge;
}
@end

@implementation OCPKCE

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_method = OCPKCEMethodS256;
	}

	return(self);
}

- (OCPKCECodeVerifier)codeVerifier
{
	@synchronized (self)
	{
		if (_codeVerifier == nil)
		{
			// Generate random verifier
			/*
			   RFC 7636:

			   code_verifier = high-entropy cryptographic random STRING using the
			   unreserved characters [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
			   from Section 2.3 of [RFC3986], with a minimum length of 43 characters
			   and a maximum length of 128 characters.
			*/
   			_codeVerifier = [NSString stringWithRandomCharactersOfLength:128 allowedCharacters:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
		}
	}

	return (_codeVerifier);
}

- (OCPKCECodeChallenge)codeChallenge
{
	@synchronized (self)
	{
		if (_codeChallenge == nil)
		{
			if ([_method isEqual:OCPKCEMethodPlain])
			{
				// RFC 7636: code_challenge = code_verifier
				_codeChallenge = self.codeVerifier;
			}
			else if ([_method isEqual:OCPKCEMethodS256])
			{
				/*
					RFC 7636:
					code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))

					..

					To be concrete, example C# code implementing these functions is shown
					below.  Similar code could be used in other languages.

					static string base64urlencode(byte [] arg)
					{
						string s = Convert.ToBase64String(arg); // Regular base64 encoder
						s = s.Split('=')[0]; // Remove any trailing '='s
						s = s.Replace('+', '-'); // 62nd char of encoding
						s = s.Replace('/', '_'); // 63rd char of encoding
						return s;
					}

				*/
			 	// Regular base64 encoder
				_codeChallenge = [[[self.codeVerifier dataUsingEncoding:NSASCIIStringEncoding] sha256Hash] base64EncodedStringWithOptions:0];

				// Remove any trailing '='s
				while ([_codeChallenge hasSuffix:@"="])
				{
					_codeChallenge = [_codeChallenge substringWithRange:NSMakeRange(0,_codeChallenge.length-1)];
				}

				// 62nd char of encoding
				_codeChallenge = [_codeChallenge stringByReplacingOccurrencesOfString:@"+" withString:@"-"];

				// 63rd char of encoding
				_codeChallenge = [_codeChallenge stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
			}
		}
	}

	return (_codeChallenge);
}

@end

OCPKCEMethod OCPKCEMethodPlain = @"plain";
OCPKCEMethod OCPKCEMethodS256 = @"S256";
