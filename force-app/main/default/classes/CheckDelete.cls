public class CheckDelete
{
   private ApexPages.standardcontroller stdCtrl;

   public CheckDelete(ApexPages.Standardcontroller std)
   {
      stdCtrl=std;
   }

   public PageReference checkDelete()
   {
      User u = [SELECT userroleid from user where id=: UserInfo.getUserId()];
      if (u.userroleid == '00EG000000131JW')
      {
          return stdCtrl.delete();
          return new PageReference('/apex/ClaimAdmin');

      }
      else
      {
         return null;
      }
   }
}