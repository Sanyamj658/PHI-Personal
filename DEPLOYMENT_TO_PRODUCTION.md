# Deployment: PassageHiStage → Production

## Purpose
This document describes the steps to validate and deploy the mobile-facing Apex REST APIs and related services to Production, plus pre/post-deploy checks and verification commands.

## Components to deploy
- Apex classes (REST endpoints & services):
  - MobileTokenAPI
  - MobileLogoutAPI
  - MobileDocumentsAPI
  - PatientAppRegister
  - PatientAppDataService
  - PatientNotificationsAPI
  - PatientDocumentRequestAPI
  - RequestOTPResource
  - VerifyOTPResource (if present)
  - BaseRestResource
  - NotificationService
  - FirebaseService
  - FirebaseNotificationQueueable
  - Notification-related handlers and trigger handlers:
    - AppUserNotificationHandler
    - AppUserInvitationController
    - PatientAppMatchingBatch
    - DocumentSharingController
    - CaseDocumentSharingController
    - TaskTriggerHandler
    - TaskNotificationHandler

- Custom Metadata / Settings / Remote Sites / Email Templates / Org-Wide Addresses
  - `FCM_Config__mdt` (must contain `Client_Email__c`, `Private_Key__c`, `Project_ID__c`)
  - Email Template named `App_Invitation_Template` (used by AppUserInvitationController)
  - OrgWideEmailAddress for the verified sender email used in code
  - Remote Site Settings or Named Credentials for `https://oauth2.googleapis.com` and `https://fcm.googleapis.com` (if not using Named Credential)

- Custom objects and fields (ensure schema exists in Production):
  - `App_User__c` (Email__c, DOB__c, Device_Token__c, Patient__c, Status__c)
  - `Shared_Document__c` (App_User__c, Content_Document_Id__c, Visible_On_Mobile__c)
  - `App_Notification__c` (App_User__c, Title__c, Body__c, Type__c, Related_Record_Id__c, Related_Record_Type__c, Is_Read__c)
  - Claim/Claim Payment objects referenced in `PatientAppDataService` (Claim__c, Claim_Payment__c)

## Pre-deploy checklist (production org)
- [ ] Confirm metadata for all classes and files are included in the deployment (force-app folder or package.xml).
- [ ] Ensure `FCM_Config__mdt` is prepared (do NOT include private key in VCS; create/verify it in Production via UI or secure CI secret injection).
- [ ] Verify `App_Invitation_Template` email template exists in Production.
- [ ] Verify Org-Wide Email Address exists and is verified.
- [ ] Add Remote Site/Named Credential entries for Google APIs if required.
- [ ] Confirm test classes exist and have sufficient coverage (>75% org-wide) and the critical tests pass locally.
- [ ] Identify required Permission Sets / Profiles for any UI/Apex access (if exposed to users).
- [ ] Freeze non-essential metadata changes and inform stakeholders of deployment window.

## Recommended test classes to run (validate coverage for changed code)
- BaseRestResourceTest
- FirebaseServiceTest
- FirebaseNotificationQueueable_Test
- MobileTokenAPITest
- MobileDocumentsAPITest
- MobileLogoutAPITest
- PatientAppRegisterTest
- PatientAppDataServiceTest
- PatientNotificationsAPITest
- PatientDocumentRequestAPITest
- PatientAppMatchingBatchTest
- NotificationServiceTest
- AppUserInvitationControllerTest
- AppUserNotificationHandlerTest
- DocumentSharingControllerTest
- TaskNotificationHandlerTest
- TaskTriggerHandlerTest

Note: If you cannot run specific tests in isolation due to dependencies, run `RunLocalTests` during validation.

## Deployment via SFDX (validate then deploy)
1. Authenticate to Production (if not already):

```bash
sfdx auth:web:login -a PROD
```

2. Validate (check-only) deploy with local tests:

```bash
sfdx force:source:deploy -p force-app -u PROD -l RunLocalTests --checkonly --wait 60
```

3. If validation succeeds, deploy to Production (run all local tests):

```bash
sfdx force:source:deploy -p force-app -u PROD -l RunLocalTests --wait 60
```

Alternative: use `force:mdapi:deploy` with a packaged `zip` if your CI pipeline builds MDAPI format.

## Quick manual post-deploy verification
- Apex Tests: Confirm successful run in Production (Apex Test Execution UI).
- REST endpoints: exercise the mobile endpoints with sample requests (use an OAuth token from a connected app or a valid session):

Save Device Token (POST):
```bash
curl -X POST \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  https://<mydomain>.my.salesforce.com/services/apexrest/saveDeviceToken \
  -d '{"email":"test@example.com","token":"abc123","dob":"1980-01-01"}'
```

Get Shared Documents (GET):
```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://<mydomain>.my.salesforce.com/services/apexrest/mobile/documents/?appUserId=<ID>"
```

Patient Register (POST):
```bash
curl -X POST \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  https://<mydomain>.my.salesforce.com/services/apexrest/v1/patient-register \
  -d '{"firstName":"John","lastName":"Doe","email":"john@example.com","dateOfBirth":"01/01/1980"}'
```

- Verify responses follow the standard wrapper: `success`, `message`, `errorCode`, `data`.
- Confirm `FCM_Config__mdt` is present and values are correct (Project ID, Client Email). Do not store private keys in VCS.
- Send a test notification by creating an `App_Notification__c` record or invoking NotificationService locally via anonymous Apex (use caution). Verify FCM calls appear in logs.
- Verify Email Template `App_Invitation_Template` sends correctly by triggering `AppUserInvitationController.sendInvitationEmail(contactId)` in a sandbox test.

## Rollback strategy
- If a deploy fails validation, fix issues and re-run validation.
- If production deploy introduces regressions, revert the metadata to the previous commit and re-deploy.
- Keep previous validated zip or CI build artifacts to re-deploy a known-good version.

## Post-deploy notes & operational items
- Ensure monitoring/logging for REST exceptions (Apex Exception Email or Platform Events) is enabled.
- Inform mobile engineering to update endpoints and re-run integration tests.
- Schedule a short smoke-test window to verify end-to-end flows (register, login, token save, notification receipt, document share).

---

If you want, I can:
- Create a CI-ready `deploy-prod.sh` script with the exact `sfdx` commands above.
- Produce a change-set/package.xml for MDAPI deployments.
- Add sample Postman collection for the mobile endpoints.


