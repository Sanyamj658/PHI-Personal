@isTest
public class GeneralLookupCtrlTest {
    
    @isTest
    static void testInit_createTask() {
        Test.setCurrentPageReference(new PageReference('/apex/GeneralLookup'));
        
        ApexPages.currentPage().getParameters().put('lksrch', 'Test');
        ApexPages.currentPage().getParameters().put('object', 'Account');
        ApexPages.currentPage().getParameters().put('lknm', 'Test%Account');
        ApexPages.currentPage().getParameters().put('lkid', '001xxxxxxxxxxxx');
        ApexPages.currentPage().getParameters().put('label', 'Medical%Provider');
        
        GeneralLookupCtrl lookupCtrl = new GeneralLookupCtrl();
        
        Assert.areEqual('Test', lookupCtrl.lkSearch, 'lkSearch should be set to "Test"');
        Assert.areEqual('Account', lookupCtrl.objectApiName, 'objectApiName should be "Account"');
        Assert.areEqual('Medical Provider', lookupCtrl.objectLabel, 'objectLabel should be "Medical Provider"');
        Assert.areEqual('Test Account', lookupCtrl.lkName, 'lkName should be "Test Account"');
        Assert.areEqual('001xxxxxxxxxxxx', lookupCtrl.lkId, 'lkId should match inserted account Id');
    }
}