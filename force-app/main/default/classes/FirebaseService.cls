// Service for sending Firebase (FCM) push notifications using a service-account OAuth token.
public class FirebaseService {
    // Sends a single push notification; runs as a future method so callouts are allowed.
    @future(callout=true)
    public static void sendNotification(String deviceToken, String title, String body) {
        try {
            // Read the Firebase credentials from custom metadata.
            List<Firebase_Configuration__mdt> config = [
                SELECT Client_Email__c, Private_Key__c, Project_ID__c
                FROM Firebase_Configuration__mdt
                LIMIT 1
            ];

            if (config.isEmpty()) {
                return;
            }

            // Get an OAuth access token for FCM.
            String accessToken = getAccessToken(config[0].Client_Email__c, config[0].Private_Key__c);
            if (accessToken == null) {
                System.debug('[FirebaseService] Failed to get access token');
                return;
            }

            sendFcmMessage(config[0].Project_ID__c, accessToken, deviceToken, title, body);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'FirebaseService.sendNotification failed: ' + ex.getMessage());
        }
    }
    
    // Queues the bulk notification job so the callouts run asynchronously.
    public static void sendBulkNotifications(String serializedPayloads) {
        try {
            System.enqueueJob(new FirebaseNotificationQueueable(serializedPayloads));
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'FirebaseService.sendBulkNotifications failed: ' + ex.getMessage());
        }
    }
    
    // Sends all queued notifications synchronously; called from the queueable job.
    public static void sendBulkNotificationsSync(String serializedPayloads) {
        try {
            if (String.isBlank(serializedPayloads)) {
                return;
            }

            List<Firebase_Configuration__mdt> configs = [
                SELECT Client_Email__c, Private_Key__c, Project_ID__c
                FROM Firebase_Configuration__mdt
                LIMIT 1
            ];
            Firebase_Configuration__mdt config = configs.isEmpty() ? new Firebase_Configuration__mdt() : configs[0];

            String accessToken = getAccessToken(config.Client_Email__c, config.Private_Key__c);
            if (accessToken == null) {
                System.debug('[FirebaseService] sendBulkNotifications: failed to get access token');
                return;
            }

            List<Object> payloads;
            try {
                payloads = (List<Object>) JSON.deserializeUntyped(serializedPayloads);
            } catch (Exception e) {
                System.debug('[FirebaseService] sendBulkNotifications: payload parse error - ' + e.getMessage());
                return;
            }

            // Send each payload individually so one failure does not stop the rest.
            for (Object item : payloads) {
                try {
                    Map<String, Object> p = (Map<String, Object>) item;
                    String deviceToken = (String) p.get('deviceToken');
                    String title = (String) p.get('title');
                    String body = (String) p.get('body');
                    if (String.isBlank(deviceToken)) {
                        continue;
                    }
                    sendFcmMessage(config.Project_ID__c, accessToken, deviceToken, title, body);
                } catch (Exception e) {
                    System.debug('[FirebaseService] sendBulkNotifications: message send error - ' + e.getMessage());
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'FirebaseService.sendBulkNotificationsSync failed: ' + ex.getMessage());
        }
    }
    
    // ─── Private helpers ─────────────────────────────────────────────────────
    
    // Builds the FCM v1 request and posts it to Firebase.
    private static void sendFcmMessage(String projectId, String accessToken,
                                       String deviceToken, String title, String body) {
                                           String fcmUrl = 'https://fcm.googleapis.com/v1/projects/' + projectId + '/messages:send';
                                           
                                           Map<String, Object> notification = new Map<String, Object>{
                                               'title' => title,
                                                   'body'  => body
                                                   };
                                                       Map<String, Object> message = new Map<String, Object>{
                                                           'token'        => deviceToken,
                                                               'notification' => notification
                                                               };
                                                                   Map<String, Object> payload = new Map<String, Object>{
                                                                       'message' => message
                                                                           };
                                                                               
                                                                               HttpRequest req = new HttpRequest();
                                           req.setEndpoint(fcmUrl);
                                           req.setMethod('POST');
                                           req.setHeader('Authorization', 'Bearer ' + accessToken);
                                           req.setHeader('Content-Type', 'application/json');
                                           req.setBody(JSON.serialize(payload));
                                           req.setTimeout(30000);
                                           
                                           try {
                                               Http http = new Http();
                                               HttpResponse res = http.send(req);
                                               System.debug('[FirebaseService] FCM response: ' + res.getStatusCode() + ' - ' + res.getBody());
                                           } catch (Exception e) {
                                               System.debug('[FirebaseService] FCM HTTP error: ' + e.getMessage());
                                           }
                                       }
    
    // Builds a signed JWT from the service-account key and exchanges it for a Google OAuth access token.
    public static String getAccessToken(String clientEmail, String privateKey) {
        try {
            
            if (String.isBlank(clientEmail) || String.isBlank(privateKey)) {
                return null;
            }
            // Build JWT Header
            String header       = '{"alg":"RS256","typ":"JWT"}';
            String encodedHeader = base64UrlEncode(Blob.valueOf(header));
            
            // Build JWT Claim
            Long now    = DateTime.now().getTime() / 1000;
            Long expiry = now + 3600;
            String claims = '{"iss":"' + clientEmail + '",' +
                '"scope":"https://www.googleapis.com/auth/firebase.messaging",' +
                '"aud":"https://oauth2.googleapis.com/token",' +
                '"exp":' + expiry + ',' +
                '"iat":' + now + '}';
            String encodedClaims = base64UrlEncode(Blob.valueOf(claims));
            
            // Sign JWT
            String signingInput = encodedHeader + '.' + encodedClaims;
            String cleanedKey = privateKey
                .replace('-----BEGIN PRIVATE KEY-----', '')
                .replace('-----END PRIVATE KEY-----', '')
                .replace('\\n', '')
                .replace('\n', '')
                .replace('\r', '')
                .replace(' ', '')
                .trim();
            
            Blob privateKeyBlob  = EncodingUtil.base64Decode(cleanedKey);
            Blob signature       = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);
            String encodedSig    = base64UrlEncode(signature);
            String jwt           = signingInput + '.' + encodedSig;
            
            // Exchange JWT for OAuth token
            HttpRequest tokenReq = new HttpRequest();
            tokenReq.setEndpoint('https://oauth2.googleapis.com/token');
            tokenReq.setMethod('POST');
            tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            tokenReq.setBody(
                'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + jwt
            );
            tokenReq.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(tokenReq);
            
            Map<String, Object> tokenResponse =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) tokenResponse.get('access_token');
            
        } catch (Exception e) {
            System.debug('[FirebaseService] getAccessToken error: ' + e.getMessage());
            return null;
        }
    }
    
    // Converts base64 to URL-safe base64 as required for JWT segments.
    private static String base64UrlEncode(Blob input) {
        return EncodingUtil.base64Encode(input)
            .replace('+', '-')
            .replace('/', '_')
            .replace('=', '');
    }  
}