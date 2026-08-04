({
	makeServerCall : function(component, name, params, callbackMethod) {
		var action = component.get("c." + name);
        action.setParams(params);
        
        action.setCallback(this,function(response){
         	var state = response.getState();
            if(state === 'SUCCESS'){
                callbackMethod(response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
	},
    

    getRelatedFilesId : function(component, id ){
        var imageExtensions = ['jpg', 'png'];
        
        this.makeServerCall(component, 'getRelatedFileIds', 
                              {parentId: id},
                              (value) => {
                                  var files = [];
                                  
                                  console.log(value.length);
                                  
                                  value.forEach( item => {
                                      if(item["ParentId"]){
                                      	item["IsAttachment"] = true;
                                        item["Title"] = item["Name"];
                                        item["FileExtension"] = "attachment";
                                  	  }
                            		  else{
                                          var size = item["ContentSize"];
                                          
                                          item["ContentSize"] =(size/1024 < 1024 ) ? (Math.round(size/1024)) + 'KB' :  (size/(1024 * 1024)).toFixed(1) + 'MB';
                                          
    								  }	
    									 
     								  if(imageExtensions.indexOf(item["FileExtension"])!= -1){
                                        item["ShowPreview"] = true;
                                      }
                                         
                                      files.push(item);
                                  });

                                files.sort(function(f1, f2){
                                    if(f1["CreatedDate"] > f2["CreatedDate"]){
                                        return -1;
                                    }
                                    else if(f1["CreatedDate"] < f2["CreatedDate"]){
                                        return 1;
                                    }
                                    return 0;
                                });
                                  component.set("v.files", files);
        						  component.set("v.showSpinner",false);
                              });	
    }
})