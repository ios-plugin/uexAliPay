/**
 *
 *	@file   	: uexAliPayAuthInfo.m  in EUExAliPay
 *
 *	@author 	: CeriNo
 * 
 *	@date   	: 2017/2/16
 *
 *	@copyright 	: 2017 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#import "uexAliPayAuthInfo.h"
#import "RSADataVerifier.h"
#import "RSADataSigner.h"

@implementation uexAliPayAuthInfo


- (NSString *)authInfoEncoded:(BOOL)bEncoded
{
    if (self.appID.length != 16||self.pid.length != 16) {
        return nil;
    }
    NSString *uuid = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    
    // NOTE: 增加不变部分数据
    NSMutableDictionary *tmpDict = [NSMutableDictionary new];
    [tmpDict addEntriesFromDictionary:@{@"app_id":_appID,
                                        @"pid":_pid,
                                        @"apiname":@"com.alipay.account.auth",
                                        @"method":@"alipay.open.auth.sdk.code.get",
                                        @"app_name":@"mc",
                                        @"biz_type":@"openservice",
                                        @"product_id":@"APP_FAST_LOGIN",
                                        @"scope":@"kuaijie",
                                        @"target_id":(_targetID?:uuid),
                                        @"auth_type":(_authType?:@"AUTHACCOUNT")}];
    
    
    // NOTE: 排序，得出最终请求字串
    NSArray* sortedKeyArray = [[tmpDict allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableArray *tmpArray = [NSMutableArray new];
    for (NSString* key in sortedKeyArray) {
        NSString* orderItem = [self itemWithKey:key andValue:[tmpDict objectForKey:key] encoded:bEncoded];
        if (orderItem.length > 0) {
            [tmpArray addObject:orderItem];
        }
    }
    return [tmpArray componentsJoinedByString:@"&"];
}

- (NSString*)itemWithKey:(NSString*)key andValue:(NSString*)value encoded:(BOOL)bEncoded
{
    if (key.length > 0 && value.length > 0) {
        if (bEncoded) {
            value = [self encodeValue:value];
        }
        return [NSString stringWithFormat:@"%@=%@", key, value];
    }
    return nil;
}
- (NSString*)encodeValue:(NSString*)value
{
    NSString* encodedValue = value;
    if (value.length > 0) {
        encodedValue = (__bridge_transfer  NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)value, NULL, (__bridge CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8 );
    }
    return encodedValue;
}

- (NSString *)authInfoStringSignedWithPrivateKey:(NSString *)privateKey{
    NSString *orderInfo = [self authInfoEncoded:NO];
    NSString *orderInfoEncoded = [self authInfoEncoded:YES];
    RSADataSigner *signer = [[RSADataSigner alloc]initWithPrivateKey:privateKey];
    NSString *signedString = [signer signString:orderInfo withRSA2:self.useRSA2];
    NSString *signType = self.useRSA2 ? @"RSA2" : @"RSA";
    return [NSString stringWithFormat:@"%@&sign=%@&sign_type=%@",orderInfoEncoded, signedString,signType];


}


@end
