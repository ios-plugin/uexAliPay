/**
 *
 *	@file   	: uexAliPayOrder.m  in EUExAliPay
 *
 *	@author 	: CeriNo
 * 
 *	@date   	: 2016/12/19
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
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


#import "uexAliPayOrder.h"
#import "RSADataSigner.h"
#import "RSADataVerifier.h"

@implementation uexAliPayContent

- (NSString *)description {
    
    NSMutableDictionary *tmpDict = [NSMutableDictionary new];
    // NOTE: 增加不变部分数据
    [tmpDict addEntriesFromDictionary:@{@"subject":_subject?:@"",
                                        @"out_trade_no":_out_trade_no?:@"",
                                        @"total_amount":_total_amount?:@"",
                                        @"seller_id":_seller_id?:@"",
                                        @"product_code":_product_code?:@"QUICK_MSECURITY_PAY"}];
    
    // NOTE: 增加可变部分数据
    if (_body.length > 0) {
        [tmpDict setObject:_body forKey:@"body"];
    }
    
    if (_timeout_express.length > 0) {
        [tmpDict setObject:_timeout_express forKey:@"timeout_express"];
    }
    
    // NOTE: 转变得到json string
    NSData* tmpData = [NSJSONSerialization dataWithJSONObject:tmpDict options:0 error:nil];
    NSString* tmpStr = [[NSString alloc]initWithData:tmpData encoding:NSUTF8StringEncoding];
    return tmpStr;
}

@end


@implementation uexAliPayOrder


- (NSDictionary *)orderInfoDictV1{
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    [dict setValue:self.app_id forKey:@"partner"];
    [dict setValue:@"mobile.securitypay.pay" forKey:@"service"];
    [dict setValue:@"utf-8" forKey:@"_input_charset"];
    [dict setValue:self.notify_url forKey:@"notify_url"];
    [dict setValue:self.biz_content.out_trade_no forKey:@"out_trade_no"];
    [dict setValue:self.biz_content.seller_id forKey:@"seller_id"];
    [dict setValue:self.biz_content.subject forKey:@"subject"];
    [dict setValue:@"1" forKey:@"payment_type"];
    [dict setValue:self.biz_content.total_amount forKey:@"total_fee"];
    [dict setValue:self.biz_content.body forKey:@"body"];
    return dict;
    
    
    
}


- (NSDictionary *)orderInfoDictV2{
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    [dict setValue:self.app_id forKey:@"app_id"];
    [dict setValue:@"alipay.trade.app.pay" forKey:@"method"];
    [dict setValue:@"utf-8" forKey:@"charset"];

    [dict setValue:self.timestamp?:@"" forKey:@"timestamp"];
    [dict setValue:@"1.0" forKey:@"version"];
    [dict setValue:_biz_content.description?:@"" forKey:@"biz_content"];
    [dict setValue:self.useRSA2 ? @"RSA2" : @"RSA" forKey:@"sign_type"];
    [dict setValue:self.format forKey:@"format"];
    [dict setValue:self.return_url forKey:@"return_url"];
    [dict setValue:self.notify_url forKey:@"notify_url"];
    [dict setValue:self.app_auth_token forKey:@"app_auth_token"];

    return dict;
}

- (NSString *)orderInfoEncoded:(BOOL)bEncoded {
    
    if (_app_id.length <= 0) {
        return nil;
    }
    
    // NOTE: 增加不变部分数据
    NSDictionary *tmpDict = nil;
    
    switch (self.type) {
        case uexAliPayOrderTypeV1:
            tmpDict = [self orderInfoDictV1];
            break;
        case uexAliPayOrderTypeV2:
            tmpDict = [self orderInfoDictV2];
        default:
            break;
    }

    // NOTE: 排序，得出最终请求字串
    NSArray* sortedKeyArray = [[tmpDict allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableArray *tmpArray = [NSMutableArray new];
    for (NSString* key in sortedKeyArray) {
        NSString* orderItem = [self orderItemWithKey:key andValue:[tmpDict objectForKey:key] encoded:bEncoded];
        if (orderItem.length > 0) {
            [tmpArray addObject:orderItem];
        }
    }
    return [tmpArray componentsJoinedByString:@"&"];
}

- (NSString*)orderItemWithKey:(NSString*)key andValue:(NSString*)value encoded:(BOOL)bEncoded
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

- (NSString *)orderStringSignedWithRSAPrivateKey:(NSString *)privateKey{
    NSString *orderInfo = [self orderInfoEncoded:NO];
    NSString *orderInfoEncoded = [self orderInfoEncoded:YES];
    RSADataSigner *signer = [[RSADataSigner alloc] initWithPrivateKey:privateKey];
    NSString *signedString = [signer signString:orderInfo withRSA2:self.useRSA2];
    NSString *signType = self.useRSA2 ? @"RSA2" : @"RSA";
    switch (self.type) {
        case uexAliPayOrderTypeV1:
            return [NSString stringWithFormat:@"%@&sign=%@&sign_type=%@",orderInfoEncoded, signedString,signType];
        case uexAliPayOrderTypeV2:
            return [NSString stringWithFormat:@"%@&sign=%@",orderInfoEncoded, signedString];
    }
}

@end
