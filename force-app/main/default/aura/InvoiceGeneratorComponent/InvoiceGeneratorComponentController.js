({
    handleGenerateInvoice : function(component, event, helper) {
        debugger;
        console.log('contactId'+ component.get("v.contactId"));
        console.log('recordId:= '+ component.get("v.recordId"));
        var action = component.get("c.generatePdF");
        // set param to method 

        action.setParams({
            'contactId': component.get("v.contactId"),
            'startDate' : component.get("v.startDate"),
            'endDate' : component.get("v.endDate"),
            'discAmt' : component.get("v.discAmt"),
            'discDesc' : component.get("v.discDesc"),
            'attorneyId' : component.get("v.selectedLookUpRecord").Id
        });
        // set a callBack    
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var storeResponse = response.getReturnValue();
                console.log('Response ::'+ storeResponse);
            }
            window.open('/'+component.get("v.contactId"),'_top')
        });
        // enqueue the Action  
        $A.enqueueAction(action);
    },
    onStartDateChange : function(component, event, helper) {
        debugger;
        component.set("v.startDate",component.find("startDate").get("v.value"));
    },
    onEndDateChange : function(component, event, helper) {
        debugger;
        component.set("v.endDate",component.find("endDate").get("v.value"));
    },
    onDiscDescChange : function(component, event, helper) {
        debugger;
        component.set("v.discDesc",component.find("discDesc").get("v.value"));
    },
    onDiscAmtChange : function(component, event, helper) {
        debugger;
        component.set("v.discAmt",component.find("discAmt").get("v.value"));
    }
})