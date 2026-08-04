# Salesforce Deployment Plan

## Visualforce to Lightning Web Component (LWC) Migration

## 1. Document Purpose
This document outlines the deployment strategy for migrating the existing Visualforce experience to a Lightning Web Component (LWC). The goal is to replace the legacy user interface with a modern Lightning Experience while preserving existing business functionality.

---

## 2. Scope

### In Scope
- Deployment of new Lightning Web Components
- Deployment of Apex controllers and helper classes
- Deployment of Apex test classes
- Permission Set updates
- Lightning App Builder changes
- Lightning tabs

---

## 3. Deployment Overview

| Item | Details |
|------|---------|
| Existing Solution | Visualforce Page |
| New Solution | Lightning Web Component |
| Deployment Type | Metadata Deployment |
| Deployment Method | Change Set / Metadata API |
| Downtime | No expected downtime |
| Rollback Supported | Yes |

---

## 4. Deployment Components

### Lightning Web Components
- LWC bundle
- Supporting child components
- CSS files
- HTML templates
- JavaScript controllers

### Apex Classes
- CallQueueCtrl_Lightning
- Helper classes
- Service classes
- Utility classes

### Apex Test Classes
- Unit test classes
- Integration test classes

### Metadata
- Permission Sets
- Custom Labels
- Static Resources
- Lightning Pages
- Tabs
- FlexiPages
- Custom Metadata (if applicable)

### Google Sheet Mapping Link
- Add the Google Sheet mapping link here for component and object mapping.

---

## 5. Environment Deployment Flow
Developer Sandbox -> Production

---

## 6. Pre-Deployment Activities
Before deployment, the following activities must be completed:

### Code Validation
- Code review completed
- Static code analysis completed

### Testing
- Unit testing completed
- Integration testing completed
- All Apex tests passing
- Minimum 75% code coverage achieved

---

## 7. Deployment Steps

### Step 1 – Validate Deployment Package
- Verify all metadata components
- Validate deployment in Production
- Resolve validation errors before deployment

### Step 2 – Deploy Apex Components
Deploy:
- Apex controllers
- Helper classes
- Service classes
- Utility classes

### Step 3 – Deploy Lightning Web Components
Deploy all LWC bundles, including:
- HTML
- JavaScript
- CSS
- XML configuration

### Step 4 – Deploy Supporting Metadata
Deploy:
- Permission Sets
- Tabs
- Lightning Record Pages

### Step 5 – Assign Permissions
- Assign or update Permission Sets
- Verify access to:
  - Apex classes
  - Lightning components
  - Objects
  - Fields

### Step 6 – Lightning Page Activation
- Activate Lightning Record Pages
- Verify App Builder assignments

### Step 7 – Visualforce Transition
After successful validation and user approval:
- Back up the Visualforce page and related items
- Remove the Visualforce tab
- Remove Visualforce navigation from the app

If needed, keep the Visualforce page available temporarily as a rollback option.

---

## 8. Deployment Validation
The following validation activities must be completed immediately after deployment.

### Functional Validation
- Component loading
- Record retrieval
- Save functionality
- Update functionality
- Navigation
- Queue refresh
- Error handling
- Browser compatibility

---

## 9. Rollback Plan
- After client approval, remove the Visualforce page from Production
- Until then, users can continue using the Visualforce page as before
- If issues arise, the Visualforce page remains available as a fallback

---

## 10. Post-Deployment Activities
After successful deployment:
- Execute smoke testing
- Validate production logs
- Monitor Apex exceptions
- Verify the browser console for JavaScript errors
- Confirm user access
- Monitor performance
- Close deployment activity

---

## 11. Success Criteria
The deployment will be considered successful when:
- Deployment completes successfully
- All Apex tests pass
- The Lightning Web Component functions as expected

---

## Notification Type
The following custom notification type should be included in deployment:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomNotificationType xmlns="http://soap.sforce.com/2006/04/metadata">
    <customNotifTypeName>Patient Document Request</customNotifTypeName>
    <desktop>true</desktop>
    <masterLabel>Patient Document Request</masterLabel>
    <mobile>true</mobile>
    <slack>false</slack>
</CustomNotificationType>
```

### Notification Type Details
- Name: Patient Document Request
- Desktop: Enabled
- Mobile: Enabled
- Slack: Disabled

---

## Notes
- Deploy after business hours to minimize user impact
- Keep the Visualforce page available until business confirmation is received
- Monitor production logs for at least 48 hours after deployment
