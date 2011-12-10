/***************************************/
/* This file relies on jQuery					 */
/***************************************/

function appendDetailsToForm(session)
{
	if(null != session)
	{
		jQuery('form').append("<input type=\"hidden\" name=\"uid\" value=\""+session.uid+"\" />");
	}
}

/***************************************/
/* Venpop markup parsing and replacing */
/***************************************/
function replaceTags(tagCollection, replacementNode)
{
  for(var i=0;i<tagCollection.length;i++)
  {
		replaceTag(replacementNode, tagCollection[i]);
  }
}

function replaceTag(replacementNode, tag)
{
	tag.parentNode.insertBefore(replacementNode, tag);
  tag.parentNode.removeChild(tag);
}

var _listXsl = null;

function parseVenpopML()
{
	//console.log("Parsing Venpop Markup");
   var tags = document.getElementsByTagName('vp:pagename');
   if(null != tags && tags.length > 0 && VP.PageId != null)
   {
			requireFacebookInit(function(){
      	FB.api('/'+VP.PageId, function(response) {
	        if(response != undefined)
	          replaceTags(tags, document.createTextNode(response.name));
      	});
			});
   }
  
  //lists
  var listTags = document.getElementsByTagName('vp:list');
	if(null != listTags)
	{
		jQuery.ajax({ url:"/list.xsl", dataType: 'xml', success: function(data, textStatus, jqXHR) { _listXsl = data; }});
	    if ('XDomainRequest' in window && window.XDomainRequest !== null) {
		//http://graphicmaniacs.com/note/getting-a-cross-domain-json-with-jquery-in-internet-explorer-8-and-later/
		// override default jQuery transport for IE
		jQuery.ajaxSettings.xhr = function() {
		    try { 
			  var xdr = new XDomainRequest(); 
			  if (xdr) {
			     xdr.onerror = function () {}; //these callbacks all workaround ie9 bugs
			     xdr.ontimeout = function () {};
			     xdr.onprogress = function () {};
			     xdr.timeout = 10000;
			  }
			  return xdr;
			}
		    catch(e) { }
		};
		// also, override the support check
		jQuery.support.cors = true;
	    }
		for(var i=0; i<listTags.length;i++)
		{
			jQuery.ajax({ 
				url: "//www.wishpot.com/public/rss/list.aspx?list="+listTags[i].getAttribute('id')+"&limit="+ listTags[i].getAttribute('count'),
				dataType: 'xml',
				beforeSend: function( xhr ) {
				    listTags[i].innerHTML="<img src=\"/ajax-loader.gif\" />";
				    try { xhr.overrideMimeType( 'text/xml' ); } catch(e) { /*errors in IE*/ }
				},
				context: listTags[i],
				success: replaceListNode,
				error: function(data, textStatus, jqXHR) {
					this.innerHTML = textStatus;
					handleAjaxError(data, textStatus, jqXHR)
				}
			});
	  }
	}
}

function replaceListNode(data, textStatus, jqXHR)
{
	var resultDocument = null;
	// code for IE
	if (window.ActiveXObject)
	{
	  resultDocument=listXml.transformNode(_listXsl);
	  //document.getElementById("example").innerHTML=ex;
	}
	// code for Mozilla, Firefox, Opera, etc.
	else if (document.implementation && document.implementation.createDocument)
	{
	  xsltProcessor=new XSLTProcessor();
	  xsltProcessor.importStylesheet(_listXsl);
	  resultDocument = xsltProcessor.transformToFragment(data,document);
	}
	jQuery(this).replaceWith(resultDocument);
	initFluidLists();
	resizeFacebook();
}

function handleAjaxError(data, textStatus, jqXHR)
{
	console.log("error from xhr: "+textStatus);
	console.log(data);
}

//Wrap any call that requires facebook to be init'ed in this function
function requireFacebookInit(func)
{
	if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined') { func(); }
	else {	jQuery('body').bind('fbInit', func); }
}

//This is a best-effort resize.  if facebook isn't loaded, is a no-op (which is okay, since)
//we do a resize when fb loads)
function resizeFacebook()
{
	if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined')
    FB.Canvas.setSize();
}


/***************************************/
/* Script that runs immediately				 */
/***************************************/
parseVenpopML();

jQuery(document).load(function(){
    resizeFacebook();
});

