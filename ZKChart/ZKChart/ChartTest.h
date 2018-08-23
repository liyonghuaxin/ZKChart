//
//  ChartTest.h
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "BaseViewController.h"

#import "BaseModel.h"
#import "MinuteAbstract.h"
#import "VolumeAbstract.h"
#import "QueryViewAbstract.h"

@interface BitTimeModel : BaseModel <MinuteAbstract, VolumeAbstract, QueryViewAbstract>

@property (nonatomic , assign) NSInteger volume;
@property (nonatomic , assign) CGFloat price_change;
@property (nonatomic , assign) CGFloat price;
@property (nonatomic , assign) CGFloat price_change_rate;
@property (nonatomic , assign) CGFloat turnover;
@property (nonatomic , copy) NSString * date;
@property (nonatomic , assign) NSInteger total_volume;
@property (nonatomic , assign) CGFloat avg_price;
@property (nonatomic , strong) NSDate * ggDate;

@end

@interface ChartTest : BaseViewController

@property (nonatomic, readonly) UIScrollView * scrollView;  ///< 滚动视图
@property (nonatomic, strong, readonly) UIScrollView * backScrollView;  ///< 背景滚动

@property (nonatomic, strong) CAShapeLayer * redVolumLayer;   ///< 红色成交量
@property (nonatomic, strong) CAShapeLayer * greenVolumLayer;     ///< 绿色成交量

@property (nonatomic, strong) DBarScaler * volumScaler;   ///< 成交量定标器
@property (nonatomic, strong) DLineScaler * lineScaler;     ///< 分时线定标器

@end
