//
//  IAPAngel.h
//
//
//  Created by danal Luo on 10/26/12.
//
//  QQ:290994669

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>


typedef void(^PurchaseCompleteBlock)(SKPaymentTransaction *transaction, NSError *error);
typedef void(^RestoreCompleteBlock)(NSArray *transactions, NSError *error);


@interface IAPAngel : NSObject<SKProductsRequestDelegate,SKPaymentTransactionObserver>

+ (id)shared;

/** Check if purchasing can go on */
- (BOOL)canPurchase;

/** Purchase by product identifier */
- (void)purchase:(NSString *)productId complete:(PurchaseCompleteBlock)onComplete;

/** Purchase a product */
- (void)purchaseProduct:(SKProduct *)product complete:(PurchaseCompleteBlock)onComplete;

/** Restore non-consumable products */
- (void)restorePurchases:(RestoreCompleteBlock)onComplete;

/** Request products from appstore */
- (void)requestProducts:(NSSet *)productIds;

/** Cancel previous request */
- (void)cancelRequest;

/** Save the transaction. Usually for non-consumable product */
- (void)saveTransaction:(SKPaymentTransaction *)transaction;

/** Clear saved transaction by product identifier */
- (void)clearTransaction:(NSString *)productId;

/** Wthether a product purchased yet */
- (BOOL)isPurchasedProduct:(NSString *)productId;

/** Verify the receipt */
+ (BOOL)verifyReceipt:(NSData *)receiptData sandbox:(BOOL)inSandbox;

@end


