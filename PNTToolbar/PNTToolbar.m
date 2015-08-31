//
// PNTToolbar.m
//
// Copyright (c) 2014 Planet 1107 (http://www.planet1107.net/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "PNTToolbar.h"

static const CGFloat AGRModalWindowHeightForLegacyOS = 620.0f;// Temporary fix, only for iOS7.
static const CGFloat AGRModalWindowNavigationBarHeight = 44.0f;

@interface PNTToolbar () <UITextFieldDelegate>

@property (assign, nonatomic) BOOL shouldReturnActivated;

@property (strong, nonatomic) UIBarButtonItem *barButtonItemPrevious;
@property (strong, nonatomic) UIBarButtonItem *barButtonItemNext;
@property (strong, nonatomic) UIBarButtonItem *barButtonItemDone;
@property (strong, nonatomic) UIBarButtonItem *barButtonItemSpace;

@property (assign, nonatomic) CGRect keyboardFrame;

@end

@implementation PNTToolbar

#pragma mark - Object lifecycle

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        _barButtonItemPrevious = [[UIBarButtonItem alloc] initWithTitle:@" < " style:UIBarButtonItemStyleBordered target:self action:@selector(barButtonItemPreviousTouchUpInside:)] ;
        _barButtonItemNext = [[UIBarButtonItem alloc] initWithTitle:@" > " style:UIBarButtonItemStyleBordered target:self action:@selector(barButtonItemNextTouchUpInside:)];
        _barButtonItemSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        _barButtonItemDone = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(barButtonItemDoneTouchUpInside:)];
        self.items = @[_barButtonItemPrevious, _barButtonItemNext, _barButtonItemSpace, _barButtonItemDone];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

+ (PNTToolbar *)defaultToolbar {
    
    PNTToolbar *toolbar = [[PNTToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
    toolbar.barStyle = UIBarStyleDefault;
    return toolbar;
}


#pragma mark - Setter methods

- (void)setInputFields:(NSArray *)inputFields {
    
    _inputFields = inputFields;
    NSMutableArray *delegates = [NSMutableArray array];
    for (UITextField *textField in inputFields) {
        if (textField.delegate && textField.delegate != self) {
            [delegates addObject:textField.delegate];
        } else {
            [delegates addObject:[NSNull null]];
        }
        textField.delegate = self;
        textField.inputAccessoryView = self;
    }
    self.inputFieldsDelegates = delegates;
}

- (void)setNavigationButtonsTintColor:(UIColor *)navigationButtonsTintColor {

    _navigationButtonsTintColor = navigationButtonsTintColor;
    self.barButtonItemPrevious.tintColor = navigationButtonsTintColor;
    self.barButtonItemNext.tintColor = navigationButtonsTintColor;
    self.barButtonItemDone.tintColor = navigationButtonsTintColor;
}

- (void)setShouldReturnActivated:(BOOL)shouldReturnActivated {

    _shouldReturnActivated = shouldReturnActivated;
    if (self.shouldHideNavigationButtons) {
        self.items = @[_barButtonItemSpace, _barButtonItemDone];
    } else {
        self.items = @[_barButtonItemPrevious, _barButtonItemNext, _barButtonItemSpace, _barButtonItemDone];
    }
}


#pragma mark - Keyboard methods


- (void)keyboardWillBeHidden:(NSNotification *)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.mainScrollView.contentInset = contentInsets;
    self.mainScrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWasShown:(NSNotification *)aNotification {

    CGRect keyboardEndFrame = [aNotification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.keyboardFrame = [self.mainScrollView.superview convertRect:keyboardEndFrame fromView:nil];
    UIViewAnimationCurve curve = [aNotification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
    UIViewAnimationOptions options = (curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
    NSTimeInterval duration = [aNotification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    CGFloat keyboardHeight = [self keyboardHeightFromNotification:aNotification];
    CGFloat additionalSpace = [self additionalSpace];

    CGFloat bottomInset = keyboardHeight - additionalSpace;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0f, 0.0f, bottomInset, 0.0f);
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        self.mainScrollView.scrollIndicatorInsets = contentInsets;
        self.mainScrollView.contentInset = contentInsets;
    } completion:^(BOOL finished) {
        NSUInteger indexOfActiveTextFiled = [self.inputFields indexOfObjectPassingTest:^BOOL(UITextField *textField, NSUInteger idx, BOOL* stop) {
            return textField.isFirstResponder;
        }];
        if (indexOfActiveTextFiled != NSNotFound) {
            UITextField *textField = self.inputFields[indexOfActiveTextFiled];
            CGRect frameToScroll = [self.mainScrollView convertRect:textField.frame fromView:textField.superview];
            [self scrollRectToVisible:frameToScroll animated:YES];
        }
    }];


}

- (CGFloat)keyboardHeightFromNotification:(NSNotification *)aNotification {

    NSDictionary *info = aNotification.userInfo;
    CGSize keyboardSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    return keyboardSize.width > keyboardSize.height ? keyboardSize.height : keyboardSize.width;
}

- (CGFloat)additionalSpace {

    CGFloat scrollViewSuperviewHeight = CGRectGetHeight(self.mainScrollView.superview.frame);
    CGFloat scrollViewHeight = CGRectGetHeight(self.mainScrollView.frame);

    return scrollViewSuperviewHeight - scrollViewHeight + [self positionFromBottom];
}

- (CGFloat)superviewHeightForLegacyOS NS_DEPRECATED_IOS(7_0, 8_0) {
    return AGRModalWindowHeightForLegacyOS;
}

- (CGFloat)superviewNavigationBarHeightForLegacyOS NS_DEPRECATED_IOS(7_0, 8_0) {
    return 0.0f;
}

- (CGFloat)positionFromBottom {

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return 0.0f;
    }

    BOOL isLegacyOS =  (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1);

    BOOL isLandscapeAndLegacy
    = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) && isLegacyOS;

    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    CGFloat statusBarHeight = isLandscapeAndLegacy ? statusBarFrame.size.width : statusBarFrame.size.height;

    CGFloat superviewHeight = isLegacyOS ? [self superviewHeightForLegacyOS] : self.mainScrollView.superview.bounds.size.height;
    CGFloat navigationBarHeight = isLegacyOS ? [self superviewNavigationBarHeightForLegacyOS]
    : AGRModalWindowNavigationBarHeight;

    CGFloat windowHeight = isLandscapeAndLegacy ? self.window.bounds.size.width : self.window.bounds.size.height;
    return windowHeight - superviewHeight - navigationBarHeight - statusBarHeight;
}

#pragma mark - Button methods

- (void)barButtonItemPreviousTouchUpInside:(id)sender {
    
    NSUInteger indexOfActiveTextFiled = [self.inputFields indexOfObjectPassingTest:^BOOL(UITextField *textField, NSUInteger idx, BOOL* stop) {
        return textField.isFirstResponder;
    }];
    if (indexOfActiveTextFiled > 0) {
        [self.inputFields[indexOfActiveTextFiled - 1] becomeFirstResponder];
    }
}

- (void)barButtonItemNextTouchUpInside:(id)sender {
    
    NSUInteger indexOfActiveTextFiled = [self.inputFields indexOfObjectPassingTest:^BOOL(UITextField *textField, NSUInteger idx, BOOL* stop) {
        return textField.isFirstResponder;
    }];
    if (indexOfActiveTextFiled < self.inputFields.count - 1) {
        [self.inputFields[indexOfActiveTextFiled + 1] becomeFirstResponder];
    }
}

- (void)barButtonItemDoneTouchUpInside:(id)sender {
    
    for (UITextField *textField in self.inputFields) {
        [textField resignFirstResponder];
    }
}


#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    CGRect frameToScroll = [self.mainScrollView convertRect:textField.frame fromView:textField.superview];
    [self scrollRectToVisible:frameToScroll animated:YES];

    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldDidBeginEditing:)]) {
        [self.inputFieldsDelegates[index] textFieldDidBeginEditing:textField];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldDidEndEditing:)]) {
        [self.inputFieldsDelegates[index] textFieldDidEndEditing:textField];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
        return [self.inputFieldsDelegates[index] textField:textField shouldChangeCharactersInRange:range replacementString:string];
    } else {
        return YES;
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldShouldBeginEditing:)]) {
        return [self.inputFieldsDelegates[index] textFieldShouldBeginEditing:textField];
    } else {
        return YES;
    }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    
    BOOL shouldEndEditing = NO;
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldShouldEndEditing:)]) {
        shouldEndEditing = [self.inputFieldsDelegates[index] textFieldShouldEndEditing:textField];
    } else {
        shouldEndEditing = YES;
    }
    if (self.shouldReturnActivated && shouldEndEditing) {
        for (UITextField *textField in self.inputFields) {
            [textField resignFirstResponder];
        }
    }
    self.shouldReturnActivated = NO;
    return shouldEndEditing;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldShouldClear:)]) {
        return [self.inputFieldsDelegates[index] textFieldShouldClear:textField];
    } else {
        return YES;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    NSUInteger index = [self.inputFields indexOfObject:textField];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textFieldShouldReturn:)]) {
        self.shouldReturnActivated = [self.inputFieldsDelegates[index] textFieldShouldReturn:textField];
        return self.shouldReturnActivated;
    } else {
        self.shouldReturnActivated = YES;
        [textField resignFirstResponder];
        return self.shouldReturnActivated;
    }
}


#pragma mark - UITextViewDelegate methods

- (void)textViewDidBeginEditing:(UITextView *)textView {
    
    CGRect frameToScroll = [self.mainScrollView convertRect:textView.frame fromView:textView.superview];
    [self scrollRectToVisible:frameToScroll animated:YES];

    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewDidBeginEditing:)]) {
        [self.inputFieldsDelegates[index] textViewDidBeginEditing:textView];
    }
    
}

- (void)textViewDidChange:(UITextView *)textView {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewDidChange:)]) {
        [self.inputFieldsDelegates[index] textViewDidChange:textView];
    }
    
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewShouldBeginEditing:)]) {
        return [self.inputFieldsDelegates[index] textViewShouldBeginEditing:textView];
    } else {
        return YES;
    }
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewShouldEndEditing:)]) {
        return [self.inputFieldsDelegates[index] textViewShouldEndEditing:textView];
    } else {
        return YES;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewDidEndEditing:)]) {
        [self.inputFieldsDelegates[index] textViewDidEndEditing:textView];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
        return [self.inputFieldsDelegates[index] textView:textView shouldChangeTextInRange:range replacementText:text];
    } else {
        return YES;
    }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    
    NSUInteger index = [self.inputFields indexOfObject:textView];
    if ([self.inputFieldsDelegates[index] respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.inputFieldsDelegates[index] textViewDidChangeSelection:textView];
    }
}


#pragma mark - Other methods

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated {
    
    if (rect.size.height > self.keyboardFrame.origin.y) {
        rect.size.height = self.keyboardFrame.origin.y;
    }
    [self.mainScrollView scrollRectToVisible:rect animated:animated];
}

@end