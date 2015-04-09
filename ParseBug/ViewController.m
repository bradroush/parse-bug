//
//  ViewController.m
//  ParseBug
//
//  Created by Brad Roush on 4/9/15.
//  Copyright (c) 2015 Brad Roush All rights reserved.
//

#import <Parse/Parse.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>

#import "ViewController.h"
#import "ParseUI.h"

@interface ViewController () <PFLogInViewControllerDelegate, PFSignUpViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UIButton *registerButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:@"UpdateUI" object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated {
    [self updateUI];
}

- (IBAction)registerUser:(id)sender {
    [self showLogin];
}

- (IBAction)logout:(id)sender {
    [PFUser logOutInBackgroundWithBlock:^(NSError *error) {
        if (!error) {
            [PFAnonymousUtils logInWithBlock:^(PFUser *user, NSError *error) {
                if (!error) {
                    user[@"anonymous"] = [NSNumber numberWithBool:YES];
                }
                [self updateUI];
            }];
            [self updateUI];
        }
    }];
}

- (void)updateUI {
    PFUser *user = [PFUser currentUser];
    NSNumber *anonNumber = user[@"anonymous"];
    if ([anonNumber boolValue]) {
        // User is anonymous
        self.usernameLabel.text = @"Anonymous";
        self.registerButton.hidden = NO;
    } else {
        // User is registered
        self.usernameLabel.text = user.username;
        self.registerButton.hidden = YES;
    }
}

- (void)showLogin {
    
    // Create the log in view controller
    PFLogInViewController *logInViewController = [[PFLogInViewController alloc] init];
    logInViewController.delegate = self;
    [logInViewController setFacebookPermissions:@[@"public_profile", @"email", @"user_friends"]];
    logInViewController.fields =  PFLogInFieldsUsernameAndPassword | PFLogInFieldsPasswordForgotten | PFLogInFieldsLogInButton | PFLogInFieldsFacebook | PFLogInFieldsSignUpButton | PFLogInFieldsDismissButton; // Show Twitter login, Facebook login, and a Dismiss button.
    [self presentViewController:logInViewController animated:YES completion:nil];
    
    // Create the sign up view controller
    PFSignUpViewController *signUpViewController = [[PFSignUpViewController alloc] init];
    [signUpViewController setDelegate:self]; // Set ourselves as the delegate
    
    // Assign our sign up controller to be displayed from the login controller
    [logInViewController setSignUpController:signUpViewController];
}

#pragma mark - Login

// Sent to the delegate to determine whether the log in request should be submitted to the server.
- (BOOL)logInViewController:(PFLogInViewController *)logInController shouldBeginLogInWithUsername:(NSString *)username password:(NSString *)password {
    // Check if both fields are completed
    if (username && password && username.length != 0 && password.length != 0) {
        return YES; // Begin login process
    }
    
    [[[UIAlertView alloc] initWithTitle:@"Missing Information"
                                message:@"Make sure you fill out all of the information!"
                               delegate:nil
                      cancelButtonTitle:@"ok"
                      otherButtonTitles:nil] show];
    return NO; // Interrupt login process
}

// Sent to the delegate when a PFUser is logged in.
- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user {
    NSLog(@"didLogInUser");
    
    user[@"anonymous"] = [NSNumber numberWithBool:NO];
    
    if ([FBSDKAccessToken currentAccessToken]) {
        [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:nil]
         startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
             if (!error) {
                 NSLog(@"fetched user:%@", result);
                 // result is a dictionary with the user's Facebook data
                 NSDictionary *userData = (NSDictionary *)result;
                 NSString *firstName = userData[@"first_name"];
                 NSString *facebookID = userData[@"id"];
                 NSString *shortId = [facebookID substringFromIndex: [facebookID length] - 5];
                 user.username = [NSString stringWithFormat:@"%@%@",[firstName lowercaseString],shortId];
             } else {
                 NSLog(@"%@",error);
             }
             [user saveEventually];
             [self dismissViewControllerAnimated:YES completion:nil];
         }];
    } else {
        NSLog(@"NO FBSDKAccessToken!!!");
        [user saveEventually];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// Sent to the delegate when the log in attempt fails.
- (void)logInViewController:(PFLogInViewController *)logInController didFailToLogInWithError:(NSError *)error {
    NSLog(@"didFailToLogInWithError:%@",error);
    
}

// Sent to the delegate when the log in screen is dismissed.
- (void)logInViewControllerDidCancelLogIn:(PFLogInViewController *)logInController {
    NSLog(@"logInViewControllerDidCancelLogIn");
}

#pragma mark - Sign Up

// Sent to the delegate to determine whether the sign up request should be submitted to the server.
- (BOOL)signUpViewController:(PFSignUpViewController *)signUpController shouldBeginSignUp:(NSDictionary *)info {
    BOOL informationComplete = YES;
    
    // loop through all of the submitted data
    for (id key in info) {
        NSString *field = [info objectForKey:key];
        if (!field || field.length == 0) { // check completion
            informationComplete = NO;
            break;
        }
    }
    
    // Display an alert if a field wasn't completed
    if (!informationComplete) {
        [[[UIAlertView alloc] initWithTitle:@"Missing Information"
                                    message:@"Make sure you fill out all of the information!"
                                   delegate:nil
                          cancelButtonTitle:@"ok"
                          otherButtonTitles:nil] show];
    }
    
    return informationComplete;
}

// Sent to the delegate when a PFUser is signed up.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didSignUpUser:(PFUser *)user {
    user[@"anonymous"] = [NSNumber numberWithBool:NO];
    [user saveEventually];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Sent to the delegate when the sign up attempt fails.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didFailToSignUpWithError:(NSError *)error {
    NSLog(@"Failed to sign up:%@",error);
}

// Sent to the delegate when the sign up screen is dismissed.
- (void)signUpViewControllerDidCancelSignUp:(PFSignUpViewController *)signUpController {
    NSLog(@"User dismissed the signUpViewController");
}


@end
