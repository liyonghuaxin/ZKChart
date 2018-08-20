//
//  BLineChart.m
//  HQZMarket
//
//  Created by mac on 2018/7/30.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "BLineChart.h"

@implementation BLineChart

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        UIPinchGestureRecognizer * pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchesViewOnGesturer:)];
        [self addGestureRecognizer:pinchGestureRecognizer];
        
        UILongPressGestureRecognizer * longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressViewOnGesturer:)];
        [self addGestureRecognizer:longPress];
        
        UITapGestureRecognizer * tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchIndexLayer:)];
        [self addGestureRecognizer:tapRecognizer];
    }
    
    return self;
}

#pragma mark 手势
/** 放大手势 */
-(void)pinchesViewOnGesturer:(UIPinchGestureRecognizer *)recognizer{
    
}

- (void)touchIndexLayer:(UILongPressGestureRecognizer *)recognizer{
    
}
/** 长按十字星 */
- (void)longPressViewOnGesturer:(UILongPressGestureRecognizer *)recognizer
{
    self.scrollView.scrollEnabled = NO;
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        [self updateSubLayer];
        
        self.scrollView.scrollEnabled = YES;
//        self.queryPriceView.hidden = YES;
    }
    else if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint velocity = [recognizer locationInView:self];
//        [self updateQueryLayerWithPoint:velocity];
//        self.queryPriceView.hidden = NO;
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGPoint velocity = [recognizer locationInView:self];
//        [self updateQueryLayerWithPoint:velocity];
    }
}

- (void)updateVolumIndexLayer:(NSInteger)index{
    
}

- (void)updateChart{

}

#pragma mark - 实时更新

- (void)updateSubLayer{
    
}

@end
