@isTest
public class CustomLookUpControllerTest {
	@isTest
    public static void testSearch(){
        system.assertEquals(0, customLookUpController.fetchLookUpValues('teste', 'Account').size());
        
        Account acc = new Account();
        acc.name='Dreamforce';
        insert acc;
        
        system.assertEquals(1, customLookUpController.fetchLookUpValues('Dreamforce', 'Account').size());
        
    }
}