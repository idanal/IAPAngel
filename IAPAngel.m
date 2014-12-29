//
//  IAPAngel.m
//
//
//  Created by danal Luo on 10/26/12.
//
//  QQ:290994669

#import "IAPAngel.h"
#import "SFHFKeychainUtils.H"
#include <netdb.h>

@interface IAPAngel ()
@property (retain, nonatomic) SKProductsRequest *request;
@property (retain, nonatomic) NSMutableArray *restoredProducts;
@property (copy, nonatomic) PurchaseCompleteBlock onPurchaseComplete;
@property (copy, nonatomic) RestoreCompleteBlock onRestoreComplete;
@end


@implementation IAPAngel

+ (id)shared{
    static IAPAngel *_sharedIAPAngel = nil;
    @synchronized(self){
        if (_sharedIAPAngel == nil) {
            _sharedIAPAngel = [[self alloc] init];
        }
        return _sharedIAPAngel;
    }
}

- (void)dealloc{
    self.request = nil;
    self.restoredProducts = nil;
    self.onPurchaseComplete = nil;
    self.onRestoreComplete = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (id)init{
    self = [super init];
    if (self) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (BOOL)canPurchase {
    const char *hostname = "appstore.com";
    struct hostent *hostinfo = gethostbyname(hostname);
    if (hostinfo == NULL) {
        return NO;
    }
    return [SKPaymentQueue canMakePayments];
}

- (void)purchase:(NSString *)productId complete:(PurchaseCompleteBlock)onComplete{
    if (![self canPurchase]) return;
    self.onPurchaseComplete = onComplete;
    [self requestProducts:[NSSet setWithObject:productId]];
}

- (void)purchaseProduct:(SKProduct *)product complete:(PurchaseCompleteBlock)onComplete{
    if (![self canPurchase]) return;
    self.onPurchaseComplete = onComplete;
    [self makePayment:product];
}

//1. We retrieve the specified products
- (void)requestProducts:(NSSet *)productIds{
    SKProductsRequest *r = [[SKProductsRequest alloc] initWithProductIdentifiers:productIds];
#if !__has_feature(objc_arc)
    [r autorelease];
#endif
    self.request = r;
    self.request.delegate = self;
    [self.request start];
}

//2. Create a payment and add it to the PaymentQueue
- (void)makePayment:(SKProduct *)product{
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

//3.Obsever the payment transation
- (void)purchaseComplete:(SKPaymentTransaction *)transaction error:(NSError *)err{
    _onPurchaseComplete(transaction,err);
}

- (void)restorePurchases:(RestoreCompleteBlock)onComplete{
    if (![self canPurchase]) return;
    self.onRestoreComplete = onComplete;
    self.restoredProducts = [NSMutableArray array];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)cancelRequest{
    [self.request cancel];
}

- (void)saveTransaction:(SKPaymentTransaction *)transaction{
    [SFHFKeychainUtils storeUsername:transaction.payment.productIdentifier andPassword:@"1" forServiceName:NSStringFromClass(self.class) updateExisting:YES error:nil];
}

- (void)clearTransaction:(NSString *)productId{
    [SFHFKeychainUtils deleteItemForUsername:productId andServiceName:NSStringFromClass(self.class) error:nil];
}

- (BOOL)isPurchasedProduct:(NSString *)productId{
    NSString *pwd = [SFHFKeychainUtils getPasswordForUsername:productId andServiceName:NSStringFromClass(self.class) error:nil];
    if (pwd && [pwd boolValue]) return YES;
    else return NO;
}

- (NSString *)receiptForProduct:(NSString *)productId{
    return nil;
}

+ (BOOL)verifyReceipt:(NSData *)receiptData sandbox:(BOOL)inSandbox{
    NSString *URL;
    if (inSandbox){
        URL = @"https://sandbox.itunes.apple.com/verifyReceipt";
    } else {
        URL = @"https://buy.itunes.apple.com/verifyReceipt";
    }
    NSString * encodingStr = [receiptData base64Encoding];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%d", [encodingStr length]] forHTTPHeaderField:@"Content-Length"];
    
    NSDictionary* body = [NSDictionary dictionaryWithObjectsAndKeys:encodingStr, @"receipt-data", nil];
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:nil];
    [request setHTTPBody:bodyData];
    
    NSHTTPURLResponse *urlResponse = nil;
    NSError *errorr = nil;
    NSData *receivedData = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&urlResponse
                                                             error:&errorr];
    //Parse
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:receivedData options:NSJSONReadingAllowFragments error:nil];
    if([[result objectForKey:@"status"] intValue] == 0){//0 means success
        return YES;
    }
    return NO;
    
}

////////////////////////////////////////////////////////////////////////////////////

#pragma mark - ProductsRequest Delegates

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
#ifdef DEBUG
    NSLog(@"Received Products:%@\nInvalid Products:%@",response.products,response.invalidProductIdentifiers);
#endif
    if ([response.products count] > 0){
        [self makePayment:[response.products firstObject]];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    //If error occurs, abort purchasing
    if (error) {
        [self purchaseComplete:nil error:error];
    }
}

#pragma mark - PaymentTransaction Delegates

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
    for (SKPaymentTransaction *t in transactions)
    {
        switch (t.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
            {
                //NSLog(@"Purchase %@ success!",t.payment.productIdentifier);
                [self purchaseComplete:t error:nil];
                [[SKPaymentQueue defaultQueue] finishTransaction:t];
            }
                break;
            case SKPaymentTransactionStateRestored:
            {
                //NSLog(@"%@ Restored!",t.payment.productIdentifier);
                [self.restoredProducts addObject:t];
                [[SKPaymentQueue defaultQueue] finishTransaction:t];
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                //NSLog(@"Purchasing %@ failed!-%@",t.payment.productIdentifier,t.error.description);
                [self purchaseComplete:t error:t.error];
                [[SKPaymentQueue defaultQueue] finishTransaction:t];
            }
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads{
#ifdef DEBUG
    NSLog(@"%s %@",__func__,downloads);
#endif
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
    _onRestoreComplete(_restoredProducts,nil);
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    _onRestoreComplete(nil,error);
}

@end
