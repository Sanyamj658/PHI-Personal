import { LightningElement, track, api, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { createRecord } from 'lightning/uiRecordApi';
import CONTENT_VERSION_OBJECT from '@salesforce/schema/ContentVersion';
import jsPDFResource from '@salesforce/resourceUrl/jsPDF';
import jsPDF_AutoTable from '@salesforce/resourceUrl/jsPDF_AutoTable';
import passageHILogo from "@salesforce/resourceUrl/passageHiLogo";
//import { CloseActionScreenEvent } from "lightning/actions";

import fetchClaimDetails from '@salesforce/apex/jsPDFHandler.fetchClaimDetails';
//import sendEmailWithContentVersionAttachment from '@salesforce/apex/jsPDFHandler.sendEmailWithContentVersionAttachment';

export default class JsPDFRequirement extends LightningElement {

  comment1 = '';
  comment2 = '';
  patientEmail;
  isRefreshClicked = false;

  @api recordId;
  @track jsPDFInitialized = false;

  // Rendered callback - Done operation after component renders.
  renderedCallback() {

    // if jsPDFInitialized = true 
    if (this.jsPDFInitialized)
      return;

    this.jsPDFInitialized = true;

    // Loaded the jsPDF Resource and Table
    Promise.all([
      loadScript(this, jsPDFResource)
        .then(() => {
          // jsPDF is loaded successfully, now load jspdf-autotable
          return loadScript(this, jsPDF_AutoTable);
        })
    ])
      .then(() => {
        // jsPDF and jsPDF_AutoTable are now available
        console.log('jsPDF and jsPDF_AutoTable loaded successfully');
        const urlParams = new URLSearchParams(window.location.search);
        this.recordId = urlParams.get('recordId');
        console.log('recordId: ', this.recordId);
      })
      .catch(error => {
        console.error('Error loading jsPDF or jsPDF_AutoTable: ' + error.message);
      });
  }

  //Store the comments value
  handleComments(event) {
    const inputName = event.target.name;
    const inputValue = event.target.value;

    if (inputName === 'comment1')
      this.comment1 = inputValue;
    else if (inputName === 'comment2')
      this.comment2 = inputValue;

    console.log('comment-1: ', this.comment1);
    console.log('comment-2: ', this.comment2);
  }

  async handleGeneratePDF() {
    this.isRefreshClicked = true; // Show the spinner

    //Imperative Method to get the Claim Payment record....
    const claimData = await fetchClaimDetails({ recordId: this.recordId });
    console.log('claimData: ', claimData);

    if (claimData) {
      const claimName = claimData.Name;
      const medicalProviderName = claimData.Medical_Provider__r.Name;
      const medicalProviderShippingStreet = claimData.Medical_Provider__r.ShippingStreet;
      const medicalProviderShippingPostalCode = claimData.Medical_Provider__r.ShippingPostalCode;
      const medicalProviderShippingCity = claimData.Medical_Provider__r.ShippingCity;
      const medicalProviderShippingState = claimData.Medical_Provider__r.ShippingState;
      const medicalProviderShippingCountry = claimData.Medical_Provider__r.ShippingCountry;
      const invoiceDescription = claimData.Medical_Provider__r.invoice_description__c;
      const patientName = claimData.Patient__r.Name;
      const fromDOS = claimData.From_DOS__c;
      const toDOS = claimData.To_DOS__c;
      const finalPaymentSummaryNo = claimData.Final_Payment_Summary_Num__c;

      //Table Values 
      const totalCharge = claimData.Total_Charge__c;
      const totalAmountPaid = claimData.Total_Amount_Paid__c;
      const totalAmountUnpaid = claimData.Total_Amount_Unpaid__c;

      this.patientEmail = claimData.Patient__r.Email;

      //Date
      // const originalDate = claimData.CreatedDate.substring(0, 10);
      // const parsedDate = new Date(originalDate);
      // const month = String(parsedDate.getMonth() + 1).padStart(2, '0'); // Adding 1 because months are zero-based
      // const day = String(parsedDate.getDate()).padStart(2, '0');
      // const year = parsedDate.getFullYear();
      // const createdDate = `${month}/${day}/${year}`;


      try {
        var props = {
          outputType: "save", // save // blob
          returnJsPDFDocObject: true,
          fileName: "Invoice 2021",
          orientationLandscape: false,
          compress: true,
          logo: {
            src: passageHILogo + '/PassageHILogo.png', //https://scontent.fjai2-1.fna.fbcdn.net/v/t39.30808-6/300448659_508933181039961_1902738159535031195_n.png?_nc_cat=104&ccb=1-7&_nc_sid=a2f6c7&_nc_ohc=OhVCrN7hy1cAX-F_m_v&_nc_ht=scontent.fjai2-1.fna&oh=00_AfBUwPfgFSPsOHUlleSth9TXRF2VCUqHMX-dsmeneLZgRw&oe=651D5FE6",
            type: 'PNG', //optional, when src= data:uri (nodejs case)
            width: 100, //aspect ratio = width/height
            height: 18.5,
            margin: {
              top: 8, //negative or positive num, from the current position
              left: 92 //negative or positive num, from the current position
            }
          },
          business: {
            name: "Passage Health International LLC",
            address: "5900 N ANDREWS AVE. STE 802",
            phone: "FORT LAUDERDALE FL. 33309",
            email: "954-526-9751, EXT 301",
            email_1: "954-376-6163 FAX",
            website: "Tax ID 46-2794441",
          },
          contact: {
            label: "Final Payment Summary",
            name: "BILL TO",
            medicalProviderName: medicalProviderName,
            shippingStreet: medicalProviderShippingStreet,
            shippingPostalCode: medicalProviderShippingPostalCode,
            shippingCity: medicalProviderShippingCity,
            shippingState: medicalProviderShippingState,
            shippingCountry: medicalProviderShippingCountry,
            invoiceDescription: invoiceDescription,
          },
          patientName: {
            label: "PATIENT NAME ",
            name: patientName,
          },
          claim: {
            label: "CLAIM NUMBER: ",
            name: claimName,
          },
          invoice: {
            label: "Final Payment Summary No: ",
            summaryNo: finalPaymentSummaryNo,
            dateLabel: "DATE",
            createdDate: new Date().toLocaleDateString(),
            headerBorder: false,
            tableBodyBorder: false,
            header: [
              {
                title: "Activity",
                style: {
                  width: 20
                }
              },
              {
                title: "From Date of Service",
                style: {
                  width: 40
                }
              },
              {
                title: "To Date of Service",
                style: {
                  width: 38
                }
              },
              {
                title: "Total Charges",
                style: {
                  width: 30
                }
              },
              {
                title: "Total Amount Paid",
                style: {
                  width: 35
                }
              },
              {
                title: "Write Off / Adjustments"
              }
            ],
            table: Array.from(Array(1), (item, index) => ([
              "Billing",
              fromDOS,
              toDOS,
              totalCharge,
              totalAmountPaid,
              totalAmountUnpaid,
            ]))
          },
          comment: {
            comment1: this.comment1,
            comment2: this.comment2,
          }
        };

        jsPDFInvoiceTemplate(props);
        // var blobValue = await jsPDFInvoiceTemplate(props).blob;     // Convert the returnObj into Blob form.
        //  this.uploadFile(blobValue); // Capture the contentVersionId

        setTimeout(() => {
          //Type, Message, Icon, Time
          this.template.querySelector('c-common-toast').showToast('success', 'Invoice downloaded successfully.', 'utility:success', 1500);
          this.isRefreshClicked = false; // Hide the spinner
        }, 1500);
      }
      catch (error) {
        console.log(error);
        this.isRefreshClicked = false;
        //Type, Message, Icon, Time
        this.template.querySelector('c-common-toast').showToast('error', 'An error occurred.', 'utility:error', 2000);
      }
    }

    this.resetInputValues();
    //To close the quick action modal
    //this.dispatchEvent(new CloseActionScreenEvent());
  }

  //Variables used in the below function(s).
  fileData;
  file = { name: 'Invoice.pdf' };

  async uploadFile(blobValue) {
    // const file = blobValue;
    // var reader = new FileReader()   // FileReader() read the contents of files

    // reader.onload = async () => {
    //   var base64 = reader.result.split(',')[1];
    //   this.fileData = {
    //     'filename': 'Invoice',
    //     'base64': base64
    //   };
    //   console.log(this.fileData);

    //   try {
    //     const contentVersionId = await this.upload();
    //     console.log('contentVersionId: ', contentVersionId);

    //     //Send Invoice to patient's emailId
    //     if (contentVersionId)
    //       this.sendEmail(contentVersionId);
    //   }
    //   catch (error) {
    //     console.error('Error uploading file:', error);
    //   }
    // };
    // reader.readAsDataURL(file);

    const file = blobValue;
    var reader = new FileReader()
    reader.onload = () => {
      var base64 = reader.result.split(',')[1]
      this.fileData = {
        'filename': 'Invoice',
        'base64': base64
      }
      console.log(this.fileData);
      this.upload();

    }
    reader.readAsDataURL(file);
  }

  async upload() {
    const contentVersion = {
      Title: "ClaimwriteOffInvoice.pdf",
      VersionData: this.fileData.base64,
      PathOnClient: `/${this.file.name}`
    };
    console.log('contentVersion: ', contentVersion);

    try {
      const result = await createRecord({ apiName: CONTENT_VERSION_OBJECT.objectApiName, fields: contentVersion });
      console.log('File uploaded successfully:', result.id);
      return result.id;
    }
    catch (error) {
      console.error('Error uploading file:', error);
      return error;
    }
  }

  /* sendEmail(contentVersionId) {
     try {
       console.log('patientEmail: ', this.patientEmail);
       const recipientEmail = this.patientEmail;
       const emailSubject = 'Write off Invoice';
       const emailBody = 'Please find the attachment below';
 
       // Call the Apex method to send the email
       sendEmailWithContentVersionAttachment({ contentVersionId, recipientEmail, emailSubject, emailBody });
       console.log('Email sent successfully!');
     }
     catch (error) {
       console.error('Error sending email:', error);
       throw error;
     }
   }
   */

  resetInputValues() {
    this.comment1 = '';
    this.comment2 = '';
  }

}

// Function to create an Invoice Template ---> (jsPDF)
function jsPDFInvoiceTemplate(props) {
  const param = {
    outputType: props.outputType || "save",
    returnJsPDFDocObject: props.returnJsPDFDocObject || false,
    fileName: props.fileName || "",
    orientationLandscape: props.orientationLandscape || false,
    compress: props.compress || false,
    logo: {
      src: props.logo?.src || "",
      type: props.logo?.type || "",
      width: props.logo?.width || "",
      height: props.logo?.height || "",
      margin: {
        top: props.logo?.margin?.top || 0,
        left: props.logo?.margin?.left || 0,
      },
    },
    business: {
      name: props.business?.name || "",
      address: props.business?.address || "",
      phone: props.business?.phone || "",
      email: props.business?.email || "",
      email_1: props.business?.email_1 || "",
      website: props.business?.website || "",
    },
    contact: {
      label: props.contact?.label || "",
      name: props.contact?.name || "",
      medicalProviderName: props.contact?.medicalProviderName || "",
      shippingStreet: props.contact?.shippingStreet || "",
      shippingPostalCode: props.contact?.shippingPostalCode || "",
      shippingCity: props.contact?.shippingCity || "",
      shippingState: props.contact?.shippingState || "",
      shippingCountry: props.contact?.shippingCountry || "",
      invoiceDescription: props.contact?.invoiceDescription || "",
    },
    patientName: {
      label: props.patientName?.label || "",
      name: props.patientName?.name || "",
    },
    claim: {
      label: props.claim?.label || "",
      name: props.claim?.name || "",
    },
    invoice: {
      label: props.invoice?.label || "",
      summaryNo: props.invoice?.summaryNo || "",
      dateLabel: props.invoice?.dateLabel || "",
      createdDate: props.invoice?.createdDate || "",
      headerBorder: props.invoice?.headerBorder || false,
      tableBodyBorder: props.invoice?.tableBodyBorder || false,
      header: props.invoice?.header || [],
      table: props.invoice?.table || [],
    },
    comment: {
      comment1: props.comment?.comment1 || "",
      comment2: props.comment?.comment2 || "",
    }
  };

  // Check so that each column in the table having values.
  if (param.invoice.table && param.invoice.table.length) {
    if (param.invoice.table[0].length != param.invoice.header.length)
      throw Error("Length of header and table column must be equal.");
  }

  const options = {
    orientation: param.orientationLandscape ? "landscape" : "",
    compress: param.compress
  };

  var doc = new jspdf.jsPDF(options);

  var docWidth = doc.internal.pageSize.width; //210 ----> width default
  var docHeight = doc.internal.pageSize.height; // 297 ----> height default

  const colorBlack = "#000000";
  const colorGray = "#4d4e53";

  // let textWidth = 0;

  var currentHeight = 15; //starting at 15mm
  var pdfConfig = {
    headerTextSize: 10,
    labelTextSize: 12,
    fieldTextSize: 10,
    lineHeight: 6,
    subLineHeight: 4,
  };

  doc.setFontSize(pdfConfig.headerTextSize);
  doc.setTextColor(colorBlack);
  //doc.setFont("Times", "Roman"); //Bold
  doc.setFont("times", "normal");


  doc.text(10, currentHeight, param.business.name);
  doc.setFontSize(pdfConfig.fieldTextSize);

  if (param.logo.src) {
    var imageHeader = '';
    if (typeof window === "undefined") {
      imageHeader = param.logo.src;
    }
    else {
      imageHeader = new Image();
      imageHeader.src = param.logo.src;
    }

    if (param.logo.type)
      doc.addImage(
        imageHeader,
        param.logo.type,
        10 + param.logo.margin.left,
        currentHeight - 10 + param.logo.margin.top,
        param.logo.width,
        param.logo.height
      );
    else
      doc.addImage(
        imageHeader,
        10 + param.logo.margin.left,
        currentHeight - 5 + param.logo.margin.top,
        param.logo.width,
        param.logo.height
      );
  }

  doc.setTextColor(colorBlack);

  currentHeight += pdfConfig.subLineHeight;
  doc.text(10, currentHeight, param.business.address);

  currentHeight += pdfConfig.subLineHeight;
  doc.text(10, currentHeight, param.business.phone);

  doc.setFontSize(pdfConfig.fieldTextSize);
  currentHeight += pdfConfig.subLineHeight;
  doc.text(10, currentHeight, param.business.email);

  currentHeight += pdfConfig.subLineHeight;
  doc.text(10, currentHeight, param.business.email_1);

  currentHeight += pdfConfig.subLineHeight;
  doc.text(10, currentHeight, param.business.website);

  //line breaker after logo & business info
  currentHeight += pdfConfig.subLineHeight;
  doc.line(10, currentHeight, docWidth - 10, currentHeight);

  //Contact part
  doc.setTextColor(colorBlack);
  doc.setFontSize(pdfConfig.fieldTextSize);
  currentHeight += pdfConfig.lineHeight;

  if (param.contact.label) {
    doc.setFontSize(13);
    doc.text(10, currentHeight, param.contact.label);
    currentHeight += (pdfConfig.lineHeight);
  }

  if (param.invoice && param.invoice.label && param.invoice.summaryNo) {
    doc.text(docWidth - 30, currentHeight, param.invoice.label, "right");
    doc.text(docWidth - 10, currentHeight, param.invoice.summaryNo, "right");
  }
  currentHeight += pdfConfig.subLineHeight + 5;

  if (param.claim && param.claim.label && param.claim.name) {

    /*
    //Calculate its width
    const labelWidth = doc.getTextWidth(param.claim.label);
    const nameWidth = doc.getTextWidth(param.claim.name);

    textWidth = Math.floor(labelWidth + nameWidth);
    console.log(`Width of the Claim text: ${textWidth}`);
    */

    doc.text(10, currentHeight, param.claim.label).setFontSize(12);
    doc.text(50, currentHeight, param.claim.name);
    currentHeight += (pdfConfig.lineHeight * 2);
  }

  doc.setTextColor(colorBlack);
  doc.setFontSize(pdfConfig.headerTextSize);

  if (param.contact.name) {
    doc.setFontSize(13);
    doc.setFont(undefined, 'bold').text(10, currentHeight, param.contact.name).setFont(undefined, 'normal');
  }

  currentHeight += pdfConfig.subLineHeight + 2;

  doc.setTextColor(colorBlack);
  doc.setFontSize(pdfConfig.fieldTextSize - 2);
  doc.setFontSize(12);

  if (param.contact.medicalProviderName) {
    doc.text(10, currentHeight, param.contact.medicalProviderName);
    currentHeight += pdfConfig.subLineHeight;
  }

  if (param.contact.shippingStreet) {
    // Split the text into lines if it contains multiple lines.
    const shippingStreetLines = param.contact.shippingStreet.split('\n');

    // Right Side 'Terms' and 'Due Date' Text
    doc.text(docWidth - 58, currentHeight, "TERMS", "right");
    doc.text(docWidth - 15, currentHeight, "Due on receipt", "right");

    // Right side 'due-date' and 'terms' values...
    if (param.invoice.dateLabel && param.invoice.createdDate) {
      doc.text(docWidth - 60, currentHeight + 5, param.invoice.dateLabel, "right");
      doc.text(docWidth - 20, currentHeight + 5, param.invoice.createdDate, "right");
    }

    // Display the shipping address (Line by line)
    for (const line of shippingStreetLines) {
      const words = line.split(' ');
      let currentLine = '';
      for (const word of words) {
        if (currentLine.length + word.length + 1 <= 33)  // Maximum width > = textWidth (Claim text)
        {
          currentLine += currentLine === '' ? word : ` ${word}`;  // If first word then direct print word else with space. (First line)
        } else {
          doc.text(10, currentHeight, currentLine);
          currentHeight += pdfConfig.subLineHeight;
          currentLine = word;
        }
      }
      
      // Print the remaing lines...
      if (currentLine.length > 0) {
        doc.text(10, currentHeight, currentLine);
        currentHeight += pdfConfig.subLineHeight;
      }
    }
  }


  if (param.contact.shippingPostalCode) {
    doc.text(10, currentHeight, param.contact.shippingPostalCode);
    currentHeight += pdfConfig.subLineHeight;
  }

  if (param.contact.shippingCity) {
    doc.text(10, currentHeight, param.contact.shippingCity);
    currentHeight += pdfConfig.subLineHeight;
  }

  if (param.contact.shippingState) {
    doc.text(10, currentHeight, param.contact.shippingState);
    currentHeight += pdfConfig.subLineHeight;
  }

  if (param.contact.shippingCountry) {
    doc.text(10, currentHeight, param.contact.shippingCountry);
    currentHeight += pdfConfig.subLineHeight;
  }

  if (param.contact.invoiceDescription) {
    doc.text(10, currentHeight, param.contact.invoiceDescription);
    currentHeight += pdfConfig.subLineHeight;
  }
  //end contact part

  //Patient Name  
  if (param.patientName && param.patientName.label && param.patientName.name) {
    //doc.text(“INVOICE”, 90, 20,) means doc.text(“text”,length from page left, length from page top)
    currentHeight += 6;
    doc.setFont(undefined, 'bold').text(param.patientName.label, 10, currentHeight).setFont(undefined, 'normal');
    doc.setFontSize(11);
    currentHeight += 5;
    doc.text(param.patientName.name, 10, currentHeight);
  }

  // ================================ TABLE PART ================================
  currentHeight += pdfConfig.subLineHeight;
  const header = param.invoice.header.map(column => column.title); //Table Headers
  const data = param.invoice.table;  //Table Values
  var config = {      //Table configuration
    autoSize: true,
    printHeaders: true,
    tableWidth: 190,
    startY: currentHeight,
    styles: { halign: 'center' },
    margin: {
      left: 10,
    },
  };

  doc.autoTable(header, data, config);
  currentHeight += 10;

  doc.setTextColor(colorBlack);
  doc.setFontSize(pdfConfig.labelTextSize);
  currentHeight += pdfConfig.lineHeight;

  doc.setTextColor(colorBlack);
  currentHeight += pdfConfig.subLineHeight;
  currentHeight += pdfConfig.subLineHeight;
  doc.setFontSize(pdfConfig.labelTextSize);


  //#region COMMENTS ...
  var addComments = () => {
    doc.setFontSize(pdfConfig.labelTextSize);
    doc.setTextColor(colorBlack);

    //Text comment - 1
    currentHeight += pdfConfig.subLineHeight + 3;
    doc.setFontSize(12).setFont(undefined, 'bold').text('COMMENTS 1', 10, currentHeight).setFont(undefined, 'normal').line(10, currentHeight + 1, 10 + (doc.getTextWidth("COMMENTS 1") + 1), currentHeight + 1);
    currentHeight += 6;

    // Value of comment - 1
    if (param.comment.comment1)
      doc.setFontSize(11).text(param.comment.comment1, 10, currentHeight);
    else
      doc.setFontSize(11).text('-', 10, currentHeight);

    currentHeight += pdfConfig.subLineHeight + 5;

    //Text comment - 2
    doc.setFontSize(12).setFont(undefined, 'bold').text('COMMENTS 2', 10, currentHeight).setFont(undefined, 'normal').line(10, currentHeight + 1, 10 + (doc.getTextWidth("COMMENTS 2") + 1), currentHeight + 1);
    currentHeight += 6;

    //Value of comment - 2
    if (param.comment.comment2)
      doc.setFontSize(11).text(param.comment.comment2, 10, currentHeight);
    else
      doc.setFontSize(11).text('-', 10, currentHeight);

    //Last 2 lines
    currentHeight += pdfConfig.subLineHeight;
    doc.line(10, currentHeight, docWidth - 10, currentHeight);
    doc.line(10, currentHeight + 1, docWidth - 10, currentHeight + 1);
  };

  addComments();   //Function to display comment(s) section in the UI

  if (param.outputType === "save") {
    doc.save(param.fileName);
  }
  else {
    console.error('Error in downloading PDF');
  }

  /*
  let returnObj = {
    pagesNumber: doc.getNumberOfPages(),    // Add 'number of pages' in returnObj.
  };

  if (param.returnJsPDFDocObject) {
    returnObj = {
      ...returnObj,
      jsPDFDocObject: doc,                  // Add 'jsPDFDocObject' in returnObj.
    };
  }

  if (param.outputType === "save") {
    doc.save(param.fileName);
  }
  else if (param.outputType === "blob") {
    const blobOutput = doc.output("blob");
    returnObj = {
      ...returnObj,                         // Add 'blobOutput' in returnObj.
      blob: blobOutput,
    };
  }
  else if (param.outputType === "datauristring") {
    returnObj = {
      ...returnObj,
      dataUriString: doc.output("datauristring", {
        filename: param.fileName,
      }),
    };
  }
  else if (param.outputType === "arraybuffer") {
    returnObj = {
      ...returnObj,
      arrayBuffer: doc.output("arraybuffer"),
    };
  }
  else
    doc.output(param.outputType, {
      filename: param.fileName,
    });

  console.log('returnObj: ', returnObj);
  return returnObj;
  */
}