({
	handleOnClickFile : function(component, event, helper){
        
        $A.get('e.lightning:openFiles').fire({
            recordIds: [component.find("outerDiv").getElement().name]
        });
        
    },
    
    handleOnClickAttachment : function(component, event, helper){
        debugger;
        window.open("/clientaccess/servlet/servlet.FileDownload?file=" + component.find("outerDiv").getElement().name);
    }
})