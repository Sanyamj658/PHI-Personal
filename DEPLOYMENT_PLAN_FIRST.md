# Salesforce Deployment Plan

## 1. Purpose
This document provides the deployment plan for releasing the Salesforce changes to Production in a controlled and secure manner.

## 2. Scope
The deployment includes the following components:
- Apex classes
- Visualforce/LWC related metadata
- Apex test classes
- Permission sets and profile updates
- Custom notification types
- Related configuration metadata

## 3. Deployment Objective
To deploy the approved Salesforce changes from the development environment to Production with minimal risk and without impacting business operations.

## 4. Deployment Type
- Metadata deployment
- Change set / metadata API based deployment
- No expected downtime

## 5. Pre-Deployment Checklist
Before deployment, confirm the following:
- All code is reviewed and approved
- All Apex test classes are updated
- Test classes pass successfully
- Minimum code coverage requirement is met
- Required metadata is included in the deployment package
- Permission assignments are prepared
- All dependent components are deployed

## 6. Deployment Components
### Apex Classes
- Relevant Apex controller classes
- Helper classes
- Service classes
- Utility classes

### Lightning / UI Components
- LWC components
- Visualforce pages (if applicable)
- Lightning pages / tabs / flexipages

### Metadata
- Permission Sets
- Custom Labels
- Static Resources
- Custom Notification Types
- Custom Metadata (if applicable)

## 7. Deployment Steps
### Step 1: Validate the deployment package
- Confirm all required metadata is included
- Validate in Production using a deployment validation run
- Resolve any validation errors

### Step 2: Deploy Apex components
- Deploy all Apex classes and test classes

### Step 3: Deploy UI components and metadata
- Deploy Lightning Web Components / Visualforce components
- Deploy related metadata files

### Step 4: Assign permissions
- Update and assign permission sets
- Verify access for required users

### Step 5: Post-deployment validation
- Verify functionality in Production
- Validate page load and data access
- Test key business flows

## 8. Testing Before Deployment
- Unit testing completed
- Integration testing completed
- Apex tests passing
- Business smoke testing completed

## 9. Rollback Plan
If issues are found after deployment:
- Revert the deployment using the last known good package
- Restore prior metadata if required
- Keep the previous version available until the issue is resolved

## 10. Post-Deployment Activities
- Monitor logs and exceptions
- Verify key user flows
- Confirm notifications and email behavior
- Validate permissions and access
- Close deployment with stakeholder confirmation

## 11. Notification Type
The deployment includes the following notification type:

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

## 12. Success Criteria
The deployment is considered successful when:
- Deployment completes without errors
- Apex tests pass
- Business functionality works as expected in Production
- Users can access the updated functionality
