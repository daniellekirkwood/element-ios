/*
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MatrixKit.h"

/**
 The `GroupsViewController` screen is the view controller displayed when `Groups` tab is selected.
 */
@interface GroupsViewController : MXKGroupListViewController <MXKGroupListViewControllerDelegate>
{
@protected
    /**
     The group identifier related to the cell which is in editing mode (if any).
     */
    NSString *editedGroupId;
    
    /**
     Current alert (if any).
     */
    UIAlertController *currentAlert;
    
    /**
     The image view of the (+) button.
     */
    UIImageView* plusButtonImageView;
}

/**
 If YES, the table view will scroll at the top on the next data source refresh.
 It comes back to NO after each refresh.
 */
@property (nonatomic) BOOL shouldScrollToTopOnRefresh;

/**
 Tell whether the search bar at the top of the groups table is enabled. YES by default.
 */
@property (nonatomic) BOOL enableSearchBar;


+ (instancetype)instantiate;

@end
