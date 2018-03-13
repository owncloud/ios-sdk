//
//  OCCertificateViewController.h
//  ownCloudUI
//
//  Created by Felix Schwarz on 13.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OCCertificate+OpenSSL.h"

@interface OCCertificateViewController : UITableViewController
{
	OCCertificate *_certificate;
}

@property(strong,nonatomic) OCCertificate *certificate;

- (instancetype)initWithCertificate:(OCCertificate *)certificate;

@end
