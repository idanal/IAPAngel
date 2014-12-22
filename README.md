IAPAngel is an easy way to use in app purchase for appstore

Require

StoreKit framework
iOS 5 or later
ARC or MRC

Usage:
1.Purchase：

    if (![[IAPAngel shared] canPurchase]){
        ALERT(@"Error:Cannot purchase");
    }
    [[IAPAngel shared] purchase:productId complete:^(SKPaymentTransaction *transaction, NSError *error) {
        if (!error) {
            if ([IAPAngel verifyReceipt:transaction.transactionReceipt sandbox:YES]){
                ALERT(@"Purchase success!");
            }
        } else {
             ALERT(@"Purchaes failed!");
        }
    }];

2.Restore:
    [[IAPAngel shared] restorePurchases:^(NSArray *transactions, NSError *error) {
        if (error){
            ALERT(@"Restore failed!");
        }
        else{
            NSMutableString *str = [NSMutableString string];
            for (SKPaymentTransaction *t in transactions){
                [str appendString:t.payment.productIdentifier];
            }
            [str appendString:@"Restore success"];
            ALERT(str);
        }
    }];

3.Save a transaction for non-consumable product:
- (void)saveTransaction:(SKPaymentTransaction *)transaction;

4.Check a product:
- (BOOL)isPurchasedProduct:(NSString *)productId;
