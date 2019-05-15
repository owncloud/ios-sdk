//
//  OCConnection+Recipients.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.19.
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

#import "OCConnection.h"
#import "NSError+OCError.h"

/*
	References:
	- Developer documentation: https://doc.owncloud.com/server/developer_manual/core/ocs-recipient-api.html
	- Implementation: https://github.com/owncloud/core/blob/master/apps/files_sharing/lib/Controller/ShareesController.php
*/

@implementation OCConnection (Recipients)

- (NSMutableArray <OCRecipient *> *)_recipientsFromJSONArray:(NSArray<NSDictionary<NSString *, id> *> *)jsonArray matchType:(OCRecipientMatchType)matchType addToArray:(NSMutableArray <OCRecipient *> *)recipientsArray
{
	for (NSDictionary<NSString *, id> *recipientDict in jsonArray)
	{
		OCRecipient *recipient = nil;

		NSString *label = recipientDict[@"label"];

		NSDictionary <NSString *, id> *value = recipientDict[@"value"];
		OCShareTypeID shareTypeID = value[@"shareType"];
		NSString *shareWith = value[@"shareWith"];
		NSString *shareWithAdditionalInfo = value[@"shareWithAdditionalInfo"];

		if ((shareWith != nil) && (shareTypeID != nil))
		{
			switch ((OCShareType)shareTypeID.integerValue)
			{
				case OCShareTypeUserShare:
				case OCShareTypeRemote:
					recipient = [[OCRecipient recipientWithUser:[OCUser userWithUserName:shareWith displayName:label]] withSearchResultName:shareWithAdditionalInfo];
				break;

				case OCShareTypeGroupShare:
					recipient = [[OCRecipient recipientWithGroup:[OCGroup groupWithIdentifier:shareWith name:label]] withSearchResultName:shareWithAdditionalInfo];
				break;

				default:
				break;
			}

			if (recipient != nil)
			{
				recipient.matchType = matchType;

				if (recipientsArray == nil)
				{
					recipientsArray = [NSMutableArray new];
				}

				[recipientsArray addObject:recipient];
			}
		}
	}

	return (recipientsArray);
}

- (nullable NSProgress *)retrieveRecipientsForItemType:(OCItemType)itemType ofShareType:(nullable NSArray <OCShareTypeID> *)shareTypes searchTerm:(nullable NSString *)searchTerm maximumNumberOfRecipients:(NSUInteger)maximumNumberOfRecipients completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDRecipients options:nil]];
	request.requiredSignals = self.actionSignals;

	[request setValue:@"json" forParameter:@"format"];

	switch (itemType)
	{
		case OCItemTypeCollection:
			[request setValue:@"folder" forParameter:@"itemType"];
		break;

		case OCItemTypeFile:
			[request setValue:@"file" forParameter:@"itemType"];
		break;
	}

	if (shareTypes != nil)
	{
		[request setValueArray:shareTypes apply:^NSString *(NSNumber *value) {
			return ([value stringValue]);
		} forParameter:@"shareType"];
	}

	if (searchTerm != nil)
	{
		[request setValue:searchTerm forParameter:@"search"];
	}

	[request setValue:[NSString stringWithFormat:@"%ld", maximumNumberOfRecipients] forParameter:@"perPage"];

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		NSError *jsonError = nil;
		NSDictionary <NSString *, id> *jsonDictionary;
		NSMutableArray<OCRecipient *> *recipients = nil;

		if ((jsonDictionary = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
		{
			NSDictionary *ocsDictionary=nil, *metaDictionary=nil, *dataDictionary=nil;

			if ((ocsDictionary = jsonDictionary[@"ocs"]) != nil)
			{
				if ((metaDictionary = ocsDictionary[@"meta"]) != nil)
				{
					NSNumber *statusCode = metaDictionary[@"statuscode"];
					NSString *statusMessage = metaDictionary[@"message"];

					switch (statusCode.integerValue)
					{
						case 100:
						case 200:
							// All is well
						break;

						case OCHTTPStatusCodeBAD_REQUEST:
							error = OCErrorWithDescription(OCErrorInsufficientParameters, statusMessage);
						break;

						default:
							error = OCErrorWithDescription(OCErrorUnknown, statusMessage);
						break;
					}
				}

				if ((error == nil) && ((dataDictionary = ocsDictionary[@"data"]) != nil))
				{
					recipients = [self _recipientsFromJSONArray:dataDictionary[@"exact"][@"users"] matchType:OCRecipientMatchTypeExact addToArray:recipients];
					recipients = [self _recipientsFromJSONArray:dataDictionary[@"exact"][@"groups"] matchType:OCRecipientMatchTypeExact addToArray:recipients];
					recipients = [self _recipientsFromJSONArray:dataDictionary[@"exact"][@"remotes"] matchType:OCRecipientMatchTypeExact addToArray:recipients];

					recipients = [self _recipientsFromJSONArray:dataDictionary[@"users"] matchType:OCRecipientMatchTypeAdditional addToArray:recipients];
					recipients = [self _recipientsFromJSONArray:dataDictionary[@"groups"] matchType:OCRecipientMatchTypeAdditional addToArray:recipients];
					recipients = [self _recipientsFromJSONArray:dataDictionary[@"remotes"] matchType:OCRecipientMatchTypeAdditional addToArray:recipients];
				}
			}
		}
		else
		{
			if (jsonError != nil)
			{
				error = jsonError;
			}
		}

		completionHandler(error, recipients);
	}];

	return (progress);
}

@end

/*
{
   "ocs":{
      "meta":{
         "status":"ok",
         "statuscode":100,
         "message":"OK",
         "totalitems":"",
         "itemsperpage":""
      },
      "data":{
         "exact":{
            "users":[
               {
                  "label":"Demo User",
                  "value":{
                     "shareType":0,
                     "shareWith":"demo"
                  }
               },
               {
                  "label":"admin",
                  "value":{
                     "shareType":0,
                     "shareWith":"admin"
                  }
               },
               {
                  "label":"test",
                  "value":{
                     "shareType":0,
                     "shareWith":"test"
                  }
               }
            ],
            "groups":[

            ],
            "remotes":[

            ]
         },
         "users":[
            {
               "label":"Shakira",
               "value":{
                  "shareType":0,
                  "shareWith":"shaka"
               }
            }
         ],
         "groups":[
            {
               "label":"admin",
               "value":{
                  "shareType":1,
                  "shareWith":"admin"
               }
            }
         ],
         "remotes":[

         ]
      }
   }
}
*/
