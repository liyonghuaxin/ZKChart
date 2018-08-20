//
//  BaseBitChart.h
//  HQZMarket
//
//  Created by mac on 2018/7/30.
//  Copyright © 2018年 mac. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GGGraphics.h"

@interface BaseBitChart : UIView<UIScrollViewDelegate>

@property (nonatomic, readonly) UIScrollView * scrollView;  ///< 滚动视图
@property (nonatomic, strong, readonly) UIScrollView * backScrollView;  ///< 背景滚动

@property (nonatomic, strong, readonly) GGCanvas * stringLayer;

@property (nonatomic, strong) DBarScaler * volumScaler;   ///< 成交量定标器

/**
 * 视图滚动
 */
- (void)scrollViewContentSizeDidChange;

/**
 * 设置成交量层
 *
 * @param rect redVolumLayer.frame = rect; greenVolumLayer.frame = rect
 */
- (void)setVolumRect:(CGRect)rect;

/**
 * 成交量视图是否为红色
 *
 * @parm obj volumScaler.lineObjAry[idx]
 */
- (BOOL)volumIsRed:(id)obj;

/**
 * 局部更新成交量
 *
 * range 成交量更新k线的区域, CGRangeMAx(range) <= volumScaler.lineObjAry.count
 */
- (void)updateVolumLayer:(NSRange)range;


@end
