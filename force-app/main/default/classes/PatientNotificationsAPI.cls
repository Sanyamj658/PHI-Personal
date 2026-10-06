// REST API to fetch and mark as read the in-app notifications of a patient App User.
@RestResource(urlMapping='/v1/patient-notifications')
global with sharing class PatientNotificationsAPI {
    // Returns the latest 200 notifications (optionally unread only) with the unread count for the App User.
    @HttpGet
    global static void getNotifications() {
        try {
            RestRequest req = RestContext.request;
            String email = req.params.get('email');
            String dobStr = req.params.get('dob');

            // Email and DOB are required to identify the user.
            if (String.isBlank(email) || String.isBlank(dobStr)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'EMAIL_DOB_REQUIRED', 'email and dob parameter is required')
                );
                return;
            }

            // Find the active App User (a QueryException here means no user was found).
            Date dob = Date.valueOf(dobStr);
            App_User__c appUser = [
                SELECT Id
                FROM App_User__c
                WHERE Email__c = :email.trim().toLowerCase() AND dob__c = :dob AND Status__c = 'Active'
                LIMIT 1
            ];

            // Optionally return unread notifications only.
            Boolean unreadOnly = req.params.get('unread_only') == 'true';
            List<App_Notification__c> notifications;

            if (unreadOnly) {
                notifications = [
                    SELECT Id, Title__c, Body__c, Is_Read__c,
                        Related_Record_Id__c, CreatedDate
                    FROM App_Notification__c
                    WHERE App_User__c = :appUser.Id
                    AND Is_Read__c = false
                    ORDER BY CreatedDate DESC
                    LIMIT 200
                ];
            } else {
                notifications = [
                    SELECT Id, Title__c, Body__c, Is_Read__c,
                        Related_Record_Id__c, CreatedDate
                    FROM App_Notification__c
                    WHERE App_User__c = :appUser.Id
                    ORDER BY CreatedDate DESC
                    LIMIT 200
                ];
            }

            // Build the response list and count unread notifications.
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            Integer unreadCount = 0;

            for (App_Notification__c n : notifications) {
                if (!n.Is_Read__c) unreadCount++;
                items.add(new Map<String, Object>{
                    'id' => n.Id,
                    'title' => n.Title__c,
                    'body' => n.Body__c,
                    'isRead' => n.Is_Read__c,
                    'relatedRecordId' => n.Related_Record_Id__c,
                    'createdDate' => String.valueOf(n.CreatedDate)
                });
            }

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(new Map<String, Object>{
                    'notifications' => items,
                    'unreadCount' => unreadCount,
                    'total' => items.size()
                })
            );
        } catch (QueryException qe) {
            // No matching App User found for this email.
            BaseRestResource.sendResponse(
                BaseRestResource.errorResponse(404, 'USER_NOT_FOUND', 'No app user found for this email')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e));
        }
    }

    // Marks notifications as read, either all unread ones for the user or the given ids.
    @HttpPost
    global static void markRead() {
        try {
            String body = RestContext.request.requestBody != null ? RestContext.request.requestBody.toString() : '{}';
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);

            List<App_Notification__c> toUpdate = new List<App_Notification__c>();
            // markAllRead with email and DOB marks every unread notification of that user.
            Boolean markAll = payload.containsKey('markAllRead') && payload.get('markAllRead') == true;

            String email = (String) payload.get('email');
            String dobStr = (String) payload.get('dob');

            if (markAll && String.isNotBlank(email) && String.isNotBlank(dobStr)) {
                Date dob = Date.valueOf(dobStr);
                List<App_User__c> users = [
                    SELECT Id
                    FROM App_User__c
                    WHERE Email__c = :email.trim().toLowerCase() AND Dob__c = :dob AND Status__c = 'Active'
                    LIMIT 1
                ];

                if (!users.isEmpty()) {
                    toUpdate = [
                        SELECT Id
                        FROM App_Notification__c
                        WHERE App_User__c = :users[0].Id
                        AND Is_Read__c = false
                    ];
                }
            } else {
                // Otherwise mark only the notification ids sent by the app.
                List<Object> idsRaw = (List<Object>) payload.get('ids');

                if (idsRaw != null && !idsRaw.isEmpty()) {
                    List<Id> ids = new List<Id>();
                    for (Object o : idsRaw) {
                        try {
                            // Skip values that are not valid Salesforce Ids.
                            ids.add((Id) String.valueOf(o));
                        } catch (Exception ex) {
                        }
                    }

                    if (!ids.isEmpty()) {
                        toUpdate = [
                            SELECT Id
                            FROM App_Notification__c
                            WHERE Id IN :ids
                        ];
                    }
                }
            }

            // Flag all selected notifications as read and save them.
            for (App_Notification__c n : toUpdate) {
                n.Is_Read__c = true;
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(new Map<String, Object>{ 'updatedCount' => toUpdate.size() }, toUpdate.size() + ' notification(s) marked as read')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e));
        }
    }
}