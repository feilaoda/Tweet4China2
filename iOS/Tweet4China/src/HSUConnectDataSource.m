//
//  HSUConnectDataSource.m
//  Tweet4China
//
//  Created by Jason Hsu on 4/24/13.
//  Copyright (c) 2013 Jason Hsu <support@tuoxie.me>. All rights reserved.
//

#import "HSUConnectDataSource.h"
#import "HSULoadMoreCell.h"
#import "HSUBaseViewController.h"

@implementation HSUConnectDataSource

+ (void)checkUnreadForViewController:(HSUBaseViewController *)viewController
{
#ifdef AUTHOR_jason
    return;
#endif
    NSString *latestIdStr = [[NSUserDefaults standardUserDefaults] objectForKey:S(@"%@_first_id_str", self.cacheKey)];
    if (!latestIdStr) {
        latestIdStr = @"1";
    }
    [TWENGINE getMentionsTimelineSinceID:latestIdStr maxID:nil count:1 success:^(id responseObj) {
        NSArray *tweets = responseObj;
        NSString *lastIdStr = tweets.lastObject[@"id_str"];
        if (lastIdStr) { // updated
            [viewController dataSourceDidFindUnread:nil];
        }
    } failure:^(NSError *error) {
        
    }];
}

- (void)refresh
{
    [super refresh];
    
    NSString *latestIdStr = [self rawDataAtIndex:0][@"id_str"];
    if (!latestIdStr) {
        latestIdStr = @"1";
    }
    [TWENGINE getMentionsTimelineSinceID:latestIdStr maxID:nil count:self.requestCount success:^(id responseObj) {
        NSArray *tweets = responseObj;
        if (tweets.count) {
            for (int i=tweets.count-1; i>=0; i--) {
                HSUTableCellData *cellData =
                [[HSUTableCellData alloc] initWithRawData:tweets[i] dataType:kDataType_DefaultStatus];
                [self.data insertObject:cellData atIndex:0];
            }
            
            HSUTableCellData *lastCellData = self.data.lastObject;
            if (![lastCellData.dataType isEqualToString:kDataType_LoadMore]) {
                HSUTableCellData *loadMoreCellData = [[HSUTableCellData alloc] init];
                loadMoreCellData.rawData = @{@"status": @(kLoadMoreCellStatus_Done)};
                loadMoreCellData.dataType = kDataType_LoadMore;
                [self.data addObject:loadMoreCellData];
            }
            
            [self saveCache];
            [self.delegate preprocessDataSourceForRender:self];
        }
        [self.delegate dataSource:self didFinishRefreshWithError:nil];
        self.loadingCount --;
    } failure:^(NSError *error) {
        [TWENGINE dealWithError:error errTitle:@"Load failed"];
    }];
}

- (void)loadMore
{
    [super loadMore];
    
    HSUTableCellData *lastStatusData = [self dataAtIndex:self.count-2];
    NSString *lastStatusId = lastStatusData.rawData[@"id_str"];
    [TWENGINE getMentionsTimelineSinceID:nil maxID:lastStatusId count:self.requestCount success:^(id responseObj) {
        id loadMoreCellData = self.data.lastObject;
        [self.data removeLastObject];
        for (NSDictionary *tweet in responseObj) {
            HSUTableCellData *cellData =
            [[HSUTableCellData alloc] initWithRawData:tweet dataType:kDataType_DefaultStatus];
            [self.data addObject:cellData];
        }
        [self.data addObject:loadMoreCellData];
        
        [self saveCache];
        [self.data.lastObject renderData][@"status"] = @(kLoadMoreCellStatus_Done);
        [self.delegate preprocessDataSourceForRender:self];
        [self.delegate dataSource:self didFinishLoadMoreWithError:nil];
        self.loadingCount --;
    } failure:^(NSError *error) {
        [TWENGINE dealWithError:error errTitle:@"Load failed"];
        [self.data.lastObject renderData][@"status"] = error ? @(kLoadMoreCellStatus_Error) : @(kLoadMoreCellStatus_NoMore);
        [self.delegate dataSource:self didFinishLoadMoreWithError:nil];
        self.loadingCount --;
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.loadingCount && self.count > 1) {
        HSUTableCellData *cellData = [self dataAtIndex:indexPath.row];
        if ([cellData.dataType isEqualToString:kDataType_LoadMore]) {
            cellData.renderData[@"status"] = @(kLoadMoreCellStatus_Loading);
            [self loadMore];
        }
    }
    
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

-(void)saveCache
{
    [super saveCache];
    
    if (self.count) {
        NSString *firstIdStr = [self rawDataAtIndex:0][@"id_str"];
        [[NSUserDefaults standardUserDefaults] setObject:firstIdStr forKey:S(@"%@_first_id_str", [self.class cacheKey])];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
