//
//  PartnerConfig.h
//  EUExAliPay
//
//  Created by xurigan on 14/11/10.
//  Copyright (c) 2014年 com.zywx. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PartnerConfig : NSObject

@property(nonatomic, copy)NSString * partnerID;
@property(nonatomic, copy)NSString * sellerID;
@property(nonatomic, copy)NSString * partnerPrivKey;
@property(nonatomic, copy)NSString * alipayPubKey;
@property(nonatomic, copy)NSString * notifyUrl;
@property(nonatomic, copy)NSString * appScheme;

@end
