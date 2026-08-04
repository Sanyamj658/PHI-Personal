({
    doInit: function(component, event, helper) {
        if (!component.get("v.isOpen")) {
            const pageRef = component.get("v.pageReference");
            if (pageRef && pageRef.state && pageRef.state.inContextOfRef) {
                let base64Context = pageRef.state.inContextOfRef;
                if (base64Context.startsWith("1.")) {
                    base64Context = base64Context.substring(2);
                }
                const addressableContext = JSON.parse(window.atob(base64Context));
                const parentId = addressableContext.attributes.recordId;
                component.set("v.parentId", parentId);
                component.set("v.isOpen", true);
            }
        }
    },
    handlePageChange : function(component, event, helper) {
        const pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state && pageRef.state.inContextOfRef) {
            let base64Context = pageRef.state.inContextOfRef;
            if (base64Context.startsWith("1.")) {
                base64Context = base64Context.substring(2);
            }
            const addressableContext = JSON.parse(window.atob(base64Context));
            const parentId = addressableContext.attributes.recordId;
            component.set("v.parentId", parentId);
            component.set("v.isOpen", true);
        }
    },
    closeModal: function(component, event, helper) {
        var navService = component.find("navService");
        var parentId = component.get("v.parentId");
        var pageReference = {
            type: "standard__recordPage",
            attributes: {
                recordId: parentId, 
                actionName: "view"
            }
        };
        component.set("v.isOpen", false);
        navService.navigate(pageReference);
    }
})