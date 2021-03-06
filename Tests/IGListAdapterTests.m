/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant 
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <objc/runtime.h>

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import <IGListKit/IGListKit.h>
#import <IGListKit/IGListReloadDataUpdater.h>

#import "IGListAdapterInternal.h"
#import "IGListTestAdapterDataSource.h"
#import "IGListTestSection.h"
#import "IGTestSupplementarySource.h"
#import "IGTestNibSupplementaryView.h"

@interface IGListAdapterTests : XCTestCase

// infra does not hold a strong ref to collection view
@property (nonatomic, strong) IGListCollectionView *collectionView;
@property (nonatomic, strong) IGListAdapter *adapter;
@property (nonatomic, strong) IGListTestAdapterDataSource *dataSource;
@property (nonatomic, strong) UIWindow *window;

@end

@implementation IGListAdapterTests

- (void)setUp {
    [super setUp];

    // minimum line spacing, item size, and minimum interim spacing are all set in IGListTestSection
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionView = [[IGListCollectionView alloc] initWithFrame:self.window.bounds collectionViewLayout:layout];

    [self.window addSubview:self.collectionView];

    // syncronous reloads so we dont have to do expectations or other nonsense
    IGListReloadDataUpdater *updater = [[IGListReloadDataUpdater alloc] init];

    self.dataSource = [[IGListTestAdapterDataSource alloc] init];
    self.adapter = [[IGListAdapter alloc] initWithUpdater:updater
                                                    viewController:nil
                                                  workingRangeSize:0];
    self.adapter.collectionView = self.collectionView;
    self.adapter.dataSource = self.dataSource;
}

- (void)tearDown {
    [super tearDown];
    self.window = nil;
    self.collectionView = nil;
    self.adapter = nil;
    self.dataSource = nil;
}

- (void)test_whenAdapterNotUpdated_withDataSourceUpdated_thatAdapterHasNoSectionControllers {
    self.dataSource.objects = @[@0, @1, @2];
    XCTAssertNil([self.adapter sectionControllerForObject:@0]);
    XCTAssertNil([self.adapter sectionControllerForObject:@1]);
    XCTAssertNil([self.adapter sectionControllerForObject:@2]);
}

- (void)test_whenAdapterUpdated_thatAdapterHasSectionControllers {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    XCTAssertNotNil([self.adapter sectionControllerForObject:@0]);
    XCTAssertNotNil([self.adapter sectionControllerForObject:@1]);
    XCTAssertNotNil([self.adapter sectionControllerForObject:@2]);
}

- (void)test_whenAdapterReloaded_thatAdapterHasSectionControllers {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter reloadDataWithCompletion:nil];
    XCTAssertNotNil([self.adapter sectionControllerForObject:@0]);
    XCTAssertNotNil([self.adapter sectionControllerForObject:@1]);
    XCTAssertNotNil([self.adapter sectionControllerForObject:@2]);
}

- (void)test_whenAdapterUpdated_thatSectionControllerHasSection {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    IGListSectionController <IGListSectionType> * list = [self.adapter sectionControllerForObject:@1];
    XCTAssertEqual([self.adapter sectionForSectionController:list], 1);
}

- (void)test_whenAdapterUpdated_withUnknownItem_thatSectionControllerHasNoSection {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    IGListSectionController <IGListSectionType> * randomList = [[IGListTestSection alloc] init];
    XCTAssertEqual([self.adapter sectionForSectionController:randomList], NSNotFound);
}

- (void)test_whenQueryingAdapter_withUnknownItem_thatSectionControllerIsNil {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    XCTAssertNil([self.adapter sectionControllerForObject:@3]);
}

- (void)test_whenQueryingIndexPaths_withSectionController_thatPathsAreEqual {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    IGListSectionController <IGListSectionType> * second = [self.adapter sectionControllerForObject:@1];
  NSArray *paths0 = [self.adapter indexPathsFromSectionController:second
                                                       indexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 4)]
                                          adjustForUpdateBlock:NO];
    NSArray *expected = @[
                          [NSIndexPath indexPathForItem:2 inSection:1],
                          [NSIndexPath indexPathForItem:3 inSection:1],
                          [NSIndexPath indexPathForItem:4 inSection:1],
                          [NSIndexPath indexPathForItem:5 inSection:1],
                          ];
    XCTAssertEqualObjects(paths0, expected);
}

- (void)test_whenQueryingIndexPaths_insideBatchUpdateBlock_thatPathsAreEqual {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter performUpdatesAnimated:YES completion:nil];
    IGListSectionController <IGListSectionType> * second = [self.adapter sectionControllerForObject:@1];

    __block BOOL executed = NO;
    [self.adapter performBatchAnimated:YES updates:^{
      NSArray *paths = [self.adapter indexPathsFromSectionController:second
                                                          indexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 2)]
                                             adjustForUpdateBlock:YES];
        NSArray *expected = @[
                              [NSIndexPath indexPathForItem:2 inSection:1],
                              [NSIndexPath indexPathForItem:3 inSection:1],
                              ];
        XCTAssertEqualObjects(paths, expected);

        executed = YES;
    } completion:nil];
    XCTAssertTrue(executed);
}

- (void)test_whenQueryingReusableIdentifier_thatIdentifierEqualsClassName {
    NSString *identifier = IGListReusableViewIdentifier(UICollectionViewCell.class, nil, nil);
    XCTAssertEqualObjects(identifier, @"UICollectionViewCell");
}

- (void)test_whenQueryingReusableIdentifier_thatIdentifierEqualsClassNameAndSupplimentaryKind {
    NSString *identifier = IGListReusableViewIdentifier(UICollectionViewCell.class, nil, UICollectionElementKindSectionFooter);
    XCTAssertEqualObjects(identifier, @"UICollectionElementKindSectionFooterUICollectionViewCell");
}

- (void)test_whenQueryingReusableIdentifier_thatIdentifierEqualsClassNameAndNibName {
    NSString *nibName = @"IGNibName";
    NSString *identifier = IGListReusableViewIdentifier(UICollectionViewCell.class, nibName, nil);
    XCTAssertEqualObjects(identifier, @"IGNibNameUICollectionViewCell");
}

- (void)test_whenDataSourceChanges_thatBackgroundViewVisibilityChanges {
    self.dataSource.objects = @[@1];
    UIView *background = [[UIView alloc] init];
    self.dataSource.backgroundView = background;
    __block BOOL executed = NO;
    [self.adapter reloadDataWithCompletion:^(BOOL finished) {
        XCTAssertTrue(self.adapter.collectionView.backgroundView.hidden, @"Background view should be hidden");
        XCTAssertEqualObjects(background, self.adapter.collectionView.backgroundView, @"Background view not correctly assigned");

        self.dataSource.objects = @[];
        [self.adapter reloadDataWithCompletion:^(BOOL finished2) {
            XCTAssertFalse(self.adapter.collectionView.backgroundView.hidden, @"Background view should be visible");
            XCTAssertEqualObjects(background, self.adapter.collectionView.backgroundView, @"Background view not correctly assigned");
            executed = YES;
        }];
    }];
    XCTAssertTrue(executed);
}

- (void)test_whenReloadingData_thatNewSectionControllersAreCreated {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter reloadDataWithCompletion:nil];
    IGListSectionController <IGListSectionType> *oldSectionController = [self.adapter sectionControllerForObject:@1];
    [self.adapter reloadDataWithCompletion:nil];
    IGListSectionController <IGListSectionType> *newSectionController = [self.adapter sectionControllerForObject:@1];
    XCTAssertNotEqual(oldSectionController, newSectionController);
}

- (void)test_whenSettingCollectionView_thenSettingDataSource_thatViewControllerIsSet {
    self.dataSource.objects = @[@0, @1, @2];
    UIViewController *controller = [UIViewController new];
    IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:[IGListReloadDataUpdater new]
                                                              viewController:controller
                                                            workingRangeSize:0];
    adapter.collectionView = self.collectionView;
    adapter.dataSource = self.dataSource;
    IGListSectionController <IGListSectionType> *sectionController = [adapter sectionControllerForObject:@1];
    XCTAssertEqual(controller, sectionController.viewController);
}

- (void)test_whenSettingCollectionView_thenSettingDataSource_thatCellExists {
    self.dataSource.objects = @[@1];
    IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:[IGListReloadDataUpdater new]
                                                              viewController:nil
                                                            workingRangeSize:0];
    adapter.collectionView = self.collectionView;
    adapter.dataSource = self.dataSource;
    [self.collectionView layoutIfNeeded];
    XCTAssertNotNil([self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
}

- (void)test_whenSettingDataSource_thenSettingCollectionView_thatCellExists {
    self.dataSource.objects = @[@1];
    IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:[IGListReloadDataUpdater new]
                                                              viewController:nil
                                                            workingRangeSize:0];
    adapter.dataSource = self.dataSource;
    adapter.collectionView = self.collectionView;
    [self.collectionView layoutIfNeeded];
    XCTAssertNotNil([self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
}

- (void)test_whenChangingCollectionViews_thatCellsExist {
    self.dataSource.objects = @[@1];
    IGListAdapterUpdater *updater = [[IGListAdapterUpdater alloc] init];
    IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:updater viewController:nil workingRangeSize:0];
    adapter.dataSource = self.dataSource;
    adapter.collectionView = self.collectionView;
    [self.collectionView layoutIfNeeded];
    XCTAssertNotNil([self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);

    IGListCollectionView *otherCollectionView = [[IGListCollectionView alloc] initWithFrame:self.collectionView.frame collectionViewLayout:self.collectionView.collectionViewLayout];
    adapter.collectionView = otherCollectionView;
    [otherCollectionView layoutIfNeeded];
    XCTAssertNotNil([otherCollectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
}

- (void)test_whenChangingCollectionViewsToACollectionViewInUseByAnotherAdapter_thatCollectionViewDelegateIsUpdated {
    IGListTestAdapterDataSource *dataSource1 = [[IGListTestAdapterDataSource alloc] init];
    dataSource1.objects = @[@1];
    IGListAdapterUpdater *updater1 = [[IGListAdapterUpdater alloc] init];
    IGListAdapter *adapter1 = [[IGListAdapter alloc] initWithUpdater:updater1 viewController:nil workingRangeSize:0];
    adapter1.dataSource = dataSource1;

    IGListTestAdapterDataSource *dataSource2 = [[IGListTestAdapterDataSource alloc] init];
    dataSource1.objects = @[@1];
    IGListAdapterUpdater *updater2 = [[IGListAdapterUpdater alloc] init];
    IGListAdapter *adapter2 = [[IGListAdapter alloc] initWithUpdater:updater2 viewController:nil workingRangeSize:0];
    adapter1.dataSource = dataSource2;

    // associate collection view with adapter1
    adapter1.collectionView = self.collectionView;
    XCTAssertEqual(self.collectionView.dataSource, adapter1);

    // associate collection view with adapter2
    adapter2.collectionView = self.collectionView;
    XCTAssertEqual(self.collectionView.dataSource, adapter2);

    // associate collection view with adapter1
    adapter1.collectionView = self.collectionView;
    XCTAssertEqual(self.collectionView.dataSource, adapter1);
}

- (void)test_whenCellsExtendBeyondBounds_thatVisibleSectionControllersAreLimited {
    // # of items for each object == [item integerValue], so @2 has 2 items (cells)
    self.dataSource.objects = @[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12];
    [self.adapter reloadDataWithCompletion:nil];
    XCTAssertEqual([self.collectionView numberOfSections], 12);
    NSArray *visibleSectionControllers = [self.adapter visibleSectionControllers];
    // UIWindow is 100x100, each cell is 100x10 so should have the following section/cell count: 1 + 2 + 3 + 4 = 10 (100 tall)
    XCTAssertEqual(visibleSectionControllers.count, 4);
    XCTAssertTrue([visibleSectionControllers containsObject:[self.adapter sectionControllerForObject:@1]]);
    XCTAssertTrue([visibleSectionControllers containsObject:[self.adapter sectionControllerForObject:@2]]);
    XCTAssertTrue([visibleSectionControllers containsObject:[self.adapter sectionControllerForObject:@3]]);
    XCTAssertTrue([visibleSectionControllers containsObject:[self.adapter sectionControllerForObject:@4]]);
}

- (void)test_whenCellsExtendBeyondBounds_thatVisibleCellsExistForSectionControllers {
    self.dataSource.objects = @[@2, @3, @4, @5, @6];
    [self.adapter reloadDataWithCompletion:nil];
    id sectionController2 = [self.adapter sectionControllerForObject:@2];
    id sectionController3 = [self.adapter sectionControllerForObject:@3];
    id sectionController4 = [self.adapter sectionControllerForObject:@4];
    id sectionController5 = [self.adapter sectionControllerForObject:@5];
    id sectionController6 = [self.adapter sectionControllerForObject:@6];
    XCTAssertEqual([self.adapter visibleCellsForSectionController:sectionController2].count, 2);
    XCTAssertEqual([self.adapter visibleCellsForSectionController:sectionController3].count, 3);
    XCTAssertEqual([self.adapter visibleCellsForSectionController:sectionController4].count, 4);
    XCTAssertEqual([self.adapter visibleCellsForSectionController:sectionController5].count, 1);
    XCTAssertEqual([self.adapter visibleCellsForSectionController:sectionController6].count, 0);
}

- (void)test_whenDataSourceAddsItems_thatEmptyViewBecomesVisible {
    self.dataSource.objects = @[];
    UIView *background = [UIView new];
    self.dataSource.backgroundView = background;
    [self.adapter reloadDataWithCompletion:nil];
    XCTAssertEqual(self.collectionView.backgroundView, background);
    XCTAssertFalse(self.collectionView.backgroundView.hidden);
    self.dataSource.objects = @[@2];
    [self.adapter reloadDataWithCompletion:nil];
    XCTAssertTrue(self.collectionView.backgroundView.hidden);
}

- (void)test_whenScrollViewDelegateSet_thatDelegateReceivesEvents {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UIScrollViewDelegate)];

    self.adapter.collectionViewDelegate = nil;
    self.adapter.scrollViewDelegate = mockDelegate;

    [[mockDelegate expect] scrollViewDidScroll:self.collectionView];

    [self.adapter scrollViewDidScroll:self.collectionView];

    [mockDelegate verify];
}

- (void)test_whenCollectionViewDelegateSet_thatDelegateReceivesEvents {
    // silence display handler asserts
    self.dataSource.objects = @[@1, @2];
    [self.adapter reloadDataWithCompletion:nil];

    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UICollectionViewDelegate)];

    self.adapter.collectionViewDelegate = mockDelegate;
    self.adapter.scrollViewDelegate = nil;

    NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:0];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:path];
    [[mockDelegate expect] collectionView:self.collectionView didEndDisplayingCell:cell forItemAtIndexPath:path];

    [self.adapter collectionView:self.collectionView didEndDisplayingCell:cell forItemAtIndexPath:path];

    [mockDelegate verify];
}

- (void)test_whenCollectionViewDelegateSet_withScrollViewDelegateSet_thatDelegatesReceiveUniqueEvents {
    // silence display handler asserts
    self.dataSource.objects = @[@1, @2];
    [self.adapter reloadDataWithCompletion:nil];

    id mockCollectionViewDelegate = [OCMockObject mockForProtocol:@protocol(UICollectionViewDelegate)];
    id mockScrollViewDelegate = [OCMockObject mockForProtocol:@protocol(UIScrollViewDelegate)];

    self.adapter.collectionViewDelegate = mockCollectionViewDelegate;
    self.adapter.scrollViewDelegate = mockScrollViewDelegate;

    NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:0];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:path];

    [[mockScrollViewDelegate expect] scrollViewDidScroll:self.collectionView];

    [[mockCollectionViewDelegate reject] scrollViewDidScroll:self.collectionView];
    [[mockCollectionViewDelegate expect] collectionView:self.collectionView didEndDisplayingCell:cell forItemAtIndexPath:path];

    [self.adapter scrollViewDidScroll:self.collectionView];
    [self.adapter collectionView:self.collectionView didEndDisplayingCell:cell forItemAtIndexPath:path];

    [mockScrollViewDelegate verify];
    [mockCollectionViewDelegate verify];
}

- (void)test_whenSupplementarySourceSupportsFooter_thatHeaderViewsAreNil {
    self.dataSource.objects = @[@1, @2];
    [self.adapter reloadDataWithCompletion:nil];

    IGTestSupplementarySource *supplementarySource = [IGTestSupplementarySource new];
    supplementarySource.collectionContext = self.adapter;
    supplementarySource.supportedElementKinds = @[UICollectionElementKindSectionFooter];

    IGListSectionController<IGListSectionType> *controller = [self.adapter sectionControllerForObject:@1];
    controller.supplementaryViewSource = supplementarySource;
    supplementarySource.sectionController = controller;

    [self.adapter performUpdatesAnimated:NO completion:nil];

    XCTAssertNotNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]]);
    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]]);
}

- (void)test_whenSupplementarySourceSupportsFooter_withNibs_thatHeaderViewsAreNil {
    self.dataSource.objects = @[@1, @2];
    [self.adapter reloadDataWithCompletion:nil];

    IGTestSupplementarySource *supplementarySource = [IGTestSupplementarySource new];
    supplementarySource.dequeueFromNib = YES;
    supplementarySource.collectionContext = self.adapter;
    supplementarySource.supportedElementKinds = @[UICollectionElementKindSectionFooter];

    IGListSectionController<IGListSectionType> *controller = [self.adapter sectionControllerForObject:@1];
    controller.supplementaryViewSource = supplementarySource;
    supplementarySource.sectionController = controller;

    [self.adapter performUpdatesAnimated:NO completion:nil];

    id view = [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    XCTAssertTrue([view isKindOfClass:IGTestNibSupplementaryView.class]);
    XCTAssertEqualObjects([[(IGTestNibSupplementaryView *)view label] text], @"Foo bar baz");

    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]]);
    XCTAssertNil([self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]]);
}

- (void)test_whenAdapterReleased_withSectionControllerStrongRefToCell_thatSectionControllersRelease {
    __weak id weakCollectionView = nil, weakAdapter = nil, weakSectionController = nil;

    @autoreleasepool {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        IGListCollectionView *collectionView = [[IGListCollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)
                                                                      collectionViewLayout:layout];
        weakCollectionView = collectionView;

        IGListTestAdapterDataSource *dataSource = [[IGListTestAdapterDataSource alloc] init];
        dataSource.objects = @[@0, @1, @2];

        IGListReloadDataUpdater *updater = [[IGListReloadDataUpdater alloc] init];
        IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:updater viewController:nil workingRangeSize:0];
        adapter.collectionView = collectionView;
        adapter.dataSource = dataSource;
        weakAdapter = adapter;

        IGListSectionController *sectionController = [adapter sectionControllerForObject:@1];
        weakSectionController = sectionController;

        // force the collection view to layout and generate cells
        [collectionView layoutIfNeeded];

        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]];
        XCTAssertNotNil(cell);
        // strongly attach the cell to an section controller
        objc_setAssociatedObject(sectionController, @"some_random_key", cell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // weak refs should exist at this point
        XCTAssertNotNil(weakCollectionView);
        XCTAssertNotNil(weakAdapter);
        XCTAssertNotNil(weakSectionController);
    }

    XCTAssertNil(weakCollectionView);
    XCTAssertNil(weakAdapter);
    XCTAssertNil(weakSectionController);
}

- (void)test_whenAdapterReleased_withSectionControllerStrongRefToCollectionView_thatSectionControllersRelease {
    __weak id weakCollectionView = nil, weakAdapter = nil, weakSectionController = nil;

    @autoreleasepool {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        IGListCollectionView *collectionView = [[IGListCollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)
                                                                      collectionViewLayout:layout];
        weakCollectionView = collectionView;

        IGListTestAdapterDataSource *dataSource = [[IGListTestAdapterDataSource alloc] init];
        dataSource.objects = @[@0, @1, @2];

        IGListReloadDataUpdater *updater = [[IGListReloadDataUpdater alloc] init];
        IGListAdapter *adapter = [[IGListAdapter alloc] initWithUpdater:updater viewController:nil workingRangeSize:0];
        adapter.collectionView = collectionView;
        adapter.dataSource = dataSource;
        weakAdapter = adapter;

        IGListSectionController *sectionController = [adapter sectionControllerForObject:@1];
        weakSectionController = sectionController;

        // force the collection view to layout and generate cells
        [collectionView layoutIfNeeded];

        // strongly attach the cell to an section controller
        objc_setAssociatedObject(sectionController, @"some_random_key", collectionView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // weak refs should exist at this point
        XCTAssertNotNil(weakCollectionView);
        XCTAssertNotNil(weakAdapter);
        XCTAssertNotNil(weakSectionController);
    }

    XCTAssertNil(weakCollectionView);
    XCTAssertNil(weakAdapter);
    XCTAssertNil(weakSectionController);
}

- (void)test_whenAdapterUpdatedTwice_withThreeSections_thatSectionsUpdatedFirstLast {
    self.dataSource.objects = @[@0, @1, @2];
    [self.adapter reloadDataWithCompletion:nil];

    XCTAssertTrue([[self.adapter sectionControllerForObject:@0] isFirstSection]);
    XCTAssertFalse([[self.adapter sectionControllerForObject:@1] isFirstSection]);
    XCTAssertFalse([[self.adapter sectionControllerForObject:@2] isFirstSection]);

    XCTAssertFalse([[self.adapter sectionControllerForObject:@0] isLastSection]);
    XCTAssertFalse([[self.adapter sectionControllerForObject:@1] isLastSection]);
    XCTAssertTrue([[self.adapter sectionControllerForObject:@2] isLastSection]);

    // update and shift objects to test that first/last flags are also updated
    self.dataSource.objects = @[@2, @0, @1];
    [self.adapter performUpdatesAnimated:NO completion:nil];

    XCTAssertFalse([[self.adapter sectionControllerForObject:@0] isFirstSection]);
    XCTAssertFalse([[self.adapter sectionControllerForObject:@1] isFirstSection]);
    XCTAssertTrue([[self.adapter sectionControllerForObject:@2] isFirstSection]);

    XCTAssertFalse([[self.adapter sectionControllerForObject:@0] isLastSection]);
    XCTAssertTrue([[self.adapter sectionControllerForObject:@1] isLastSection]);
    XCTAssertFalse([[self.adapter sectionControllerForObject:@2] isLastSection]);
}

@end
