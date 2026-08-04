/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of GeneralLookup Visualforce Page.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 12-May-2025    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class GeneralLookupCtrl {
    public String lkId { get; set; }
    public String lkName { get; set; }
    public String lkSearch { get; set; }
    public String objectApiName { get; set; }
    public String objectLabel { get; set; }
    public List<SObject> relatedRecordList { get; set; }

    public GeneralLookupCtrl() {
        lkId = '';
        lkName = '';
        lkSearch = '';
        objectApiName = '';
        objectLabel = '';
        relatedRecordList = new List<SObject>();
        try {
            if (ApexPages.currentPage().getParameters().containsKey('object') && String.isNotBlank(ApexPages.currentPage().getParameters().get('object'))) {
                objectApiName = ApexPages.currentPage().getParameters().get('object').replaceAll('%', ' ');
                if (ApexPages.currentPage().getParameters().containsKey('label') && String.isNotBlank(ApexPages.currentPage().getParameters().get('label'))) {
                    objectLabel = ApexPages.currentPage().getParameters().get('label').replaceAll('%', ' ');
                }
            } else {
                objectApiName = 'Account';
                objectLabel = 'Medical Provider';
            }
            String lookupName = ApexPages.currentPage().getParameters().get('lknm');
            if (String.isNotBlank(lookupName)) {
                lkName = lookupName.replaceAll('%', ' ');
            }
            String lookupId = ApexPages.currentPage().getParameters().get('lkid');
            if (String.isNotBlank(lookupId)) {
                lkId = lookupId.replaceAll('%', ' ');
            }
            String lookupSearch = ApexPages.currentPage().getParameters().get('lksrch');
            if (String.isNotBlank(lookupSearch)) {
                lkSearch = lookupSearch.replaceAll('%', ' ');
            }
            onGo();
        } 
        catch (Exception e) {
            System.debug('Exception ' + e.getmessage());
        }
    }

    public PageReference onGo() {
        String queryStr = '';
        try {
            lkSearch = String.isNotBlank(lkSearch) ? lkSearch.trim() : '';
            if (String.isNotBlank(objectApiName)) {
                queryStr += 'SELECT Id, Name FROM ' + objectApiName;
                if (String.isNotBlank(lkSearch)) {
                    queryStr += ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(lkSearch) + '%\'';
                } 
                queryStr += (String.isNotBlank(lkSearch) ? ' ORDER BY CreatedDate DESC LIMIT 50 ' : ' ORDER BY CreatedDate DESC LIMIT 200 ');
                relatedRecordList.clear();
                relatedRecordList = Database.query(queryStr);
            }              
        } 
        catch (Exception e) {
            System.debug('Exception: '+e.getMessage());
        }
        return null;
    }
}