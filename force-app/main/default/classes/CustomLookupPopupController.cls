public class CustomLookupPopupController {
    public String entity { get; set; }                      // Object API name (e.g., Account, Patient__c)
    public String searchKeyword { get; set; }               // Text to search
    public List<SObject> searchResults { get; set; }        // Result list
    public String selectedRecordId { get; set; }            // Chosen record Id
    public String selectedRecordName { get; set; }          // Chosen record Name

    public CustomLookupPopupController() {
        entity = ApexPages.currentPage().getParameters().get('entity');
        searchResults = new List<SObject>();
    }

    public void search() {
        if (String.isBlank(entity) || String.isBlank(searchKeyword)) return;

        Set<String> allowedEntities = new Set<String>{ 'Account', 'Contact', 'Insurance_Company__c' };
        if (!allowedEntities.contains(entity)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid entity type.'));
            return;
        }

        try {
            String searchTerm = '%' + searchKeyword + '%';
            String query = 'SELECT Id, Name FROM ' + entity + ' WHERE Name LIKE :searchTerm LIMIT 50';
            searchResults = Database.query(query);
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Search failed: ' + e.getMessage()));
        }
    }

    public PageReference selectRecord() {
        return null; // Selection handled by JavaScript callback
    }
}