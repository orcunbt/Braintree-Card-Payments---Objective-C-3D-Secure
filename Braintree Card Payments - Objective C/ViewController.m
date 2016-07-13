//
//  ViewController.m
//  Braintree Card Payments - Objective C
//
//  Created by Orcun on 07/02/2016.
//  Copyright © 2016 Orcun. All rights reserved.
//

#import "ViewController.h"
#import "BraintreeCard.h"
#import "Braintree3DSecure.h"
#import "BraintreeUI.h"

@interface ViewController () <BTViewControllerPresentingDelegate>


@property (weak, nonatomic) IBOutlet UITextField *cardTextField;
@property (weak, nonatomic) IBOutlet UITextField *cardExpiryMonthTextField;
@property (weak, nonatomic) IBOutlet UITextField *cardExpiryYearTextField;
@property (weak, nonatomic) IBOutlet UITextField *cardCvvTextField;

@property (weak, nonatomic) IBOutlet UIButton *buyButton;

@property (nonatomic, strong) BTAPIClient *braintreeClient;
@property (nonatomic, strong) BTThreeDSecureDriver *threeDriver;




@end

NSString *clientToken;
NSString *resultCheck;
NSString *pricethreed = @"1199.00";


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSURL *clientTokenURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/BTOrcun/tokenGen.php"];
    NSMutableURLRequest *clientTokenRequest = [NSMutableURLRequest requestWithURL:clientTokenURL];
    [clientTokenRequest setValue:@"text/plain" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:clientTokenRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // TODO: Handle errors
        clientToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        // Log the client token to confirm that it is returned from the server
        NSLog(@"Client token received: %@",clientToken);
        
    }] resume];

   }

- (void)prepareForCheckout {
    // Retain both your instance of `BTThreeDSecureDriver` and its delegate with a strong pointer to avoid memory-management bugs.
    self.threeDriver = [[BTThreeDSecureDriver alloc] initWithAPIClient:self.braintreeClient delegate:self];
}


- (IBAction)buyButtonTapped:(id)sender {
    
    // Add the client token to braintreeClient
    BTAPIClient *braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    
    // Initiliaze the BTCardClient for tokenizing card details
    BTCardClient *cardClient = [[BTCardClient alloc] initWithAPIClient:braintreeClient];
    
    // Take the card details from text fields in the app
    BTCard *card = [[BTCard alloc] initWithNumber:self.cardTextField.text
                                  expirationMonth:self.cardExpiryMonthTextField.text
                                   expirationYear:self.cardExpiryYearTextField.text
                                              cvv:self.cardCvvTextField.text];
    
    
    // Tokenize the card details
    [cardClient tokenizeCard:card
                  completion:^(BTCardNonce *tokenizedCard, NSError *error) {
                      if (error) {
                          // Handle errors
                          return;
                      }
                      
                      // Log the tokenized card nonce to confirm it's generated
                       NSLog(@"Nonce received: %@",tokenizedCard.nonce);
                      
                      // Create BT 3d secure driver
                      BTThreeDSecureDriver *threeDSecure = [[BTThreeDSecureDriver alloc] initWithAPIClient:braintreeClient delegate:self];
                      
                      // Kick off 3D Secure flow. This example uses a value of $10.
                      [threeDSecure verifyCardWithNonce:tokenizedCard.nonce
                                                            amount:[NSDecimalNumber decimalNumberWithString:pricethreed]
                                                        completion:^(BTThreeDSecureCardNonce *card, NSError *error) {
                                                            if (error) {
                                                                // Handle errors
                                                                NSLog(@"error: %@",error);
                                                                return;
                                                                
                                                            }
                                                            
                                                            // Use resulting `card`...
                                        
                                                            NSLog(@"Card nonce: %@",card.nonce);
                                                            
                                                            // Send the 3d secure nonce to server
                                                            [self postNonceToServer:card.nonce];
                                                        }];
                  }];
}

- (void)paymentDriver:(id)driver requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)paymentDriver:(id)driver requestsDismissalOfViewController:(UIViewController *)viewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postNonceToServer:(NSString *)paymentMethodNonce {
    
    
    double price = 1199.00;
    
    NSURL *paymentURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/BTOrcun/iosPayment.php"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:paymentURL];
    
    request.HTTPBody = [[NSString stringWithFormat:@"amount=%ld&payment_method_nonce=%@", (long)price,paymentMethodNonce] dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPMethod = @"POST";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSString *paymentResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        // TODO: Handle success and failure
        
        // Logging the HTTP request so we can see what is being sent to the server side
        NSLog(@"Request body %@", [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding]);
        
        // Trimming the response for success/failure check so it takes less time to determine the result
        NSString *trimResult =[paymentResult substringToIndex:50];
        
        // Log the transaction result
        NSLog(@"%@",paymentResult);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Checking the result for the string "Successful" and updating GUI elements
            if ([trimResult containsString:@"Successful"]) {
                NSLog(@"Transaction is successful!");
                resultCheck = @"Transaction successful";
                
                
            } else {
                NSLog(@"Transaction failed! Contact Mat!");
                resultCheck = @"Transaction failed!Contact Mat!";
                
            }
            
            // Create an alert controller to display the transaction result
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:resultCheck
                                                                           message:paymentResult
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:
                                            UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                
                                                NSLog(@"You pressed button OK");
                                            }];
            
            [alert addAction:defaultAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        });
    }] resume];
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
