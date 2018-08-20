//
//  ChartTest.h
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "BaseViewController.h"

@interface ChartTest : BaseViewController

@property (nonatomic, readonly) UIScrollView * scrollView;  ///< 滚动视图
@property (nonatomic, strong, readonly) UIScrollView * backScrollView;  ///< 背景滚动

@property (nonatomic, strong) CAShapeLayer * redVolumLayer;   ///< 红色成交量
@property (nonatomic, strong) CAShapeLayer * greenVolumLayer;     ///< 绿色成交量

@property (nonatomic, strong) DBarScaler * volumScaler;   ///< 成交量定标器

@end
