//
//  ViewController.m
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "ViewController.h"
#import "PriceChart.h"
#import "ChartTest.h"
#import "Test.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>{
    UITableView *myTableView;
    NSArray *dataArr;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    myTableView = [[UITableView alloc] init];
    myTableView.delegate = self;
    myTableView.dataSource = self;
    myTableView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    [self.view addSubview:myTableView];
    
    dataArr = @[@"K线图",@"Minute线图",@"价格、市值、成交量", @"bitK线"];
}


-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return dataArr.count;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (indexPath.row) {
        case 0:{
            Test *test = [[Test alloc] init];
            [self.navigationController pushViewController:test animated:YES];
            break;
        }
        case 1:{
            Test *test = [[Test alloc] init];
            test.index = 1;
            [self.navigationController pushViewController:test animated:YES];
            break;
        }
        case 2:{
            PriceChart *price = [[PriceChart alloc] init];
            [self.navigationController pushViewController:price animated:YES];
            break;
        }
        case 3:{
            ChartTest *test = [[ChartTest alloc] init];
            [self.navigationController pushViewController:test animated:YES];
            break;
        }
        default:
            break;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = dataArr[indexPath.row];
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
