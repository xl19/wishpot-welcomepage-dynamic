/***************************************/
/* This file relies on jQuery					 */
/***************************************/

function appendDetailsToForm(session)
{
	if(null != session)
	{
		jQuery('form').append("<input type=\"hidden\" name=\"uid\" value=\""+session.uid+"\" />");
	}

	jQuery('form').append("<input type=\"hidden\" name=\"cloned_signed_request\" value=\""+VP.FbRequest+"\" />");
}

function trace(msg)
{
	//if(console) { console.log(msg); }
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

function findTag(venpopTagName)
{
	var goodTags = document.getElementsByTagName('vp:'+venpopTagName);
	if(goodTags.length > 0) return goodTags;
	return document.getElementsByTagName(venpopTagName);
}

function replaceTag(replacementNode, tag)
{
	tag.parentNode.insertBefore(replacementNode, tag);
	tag.parentNode.removeChild(tag);
}

var _listXsl = null;

function parseVenpopML()
{
	trace("Parsing Venpop Markup");
  
  //lists - strip namespace for ie
  var listTags = findTag('list');
	if(null != listTags)
	{
		trace("Found "+listTags.length+" list tags");
		jQuery.ajax({ url:"/list.xsl", dataType: 'xml', success: function(data, textStatus, jqXHR) { _listXsl = data; }});
		
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
	}else{trace("Found no list tags");}
}

function replaceListNode(data, textStatus, jqXHR)
{
	var resultDocument = null;
	// code for IE
	if (window.ActiveXObject)
	{
	  trace("Creating XML ActiveXObject...")
	  var xmldoc = new ActiveXObject("Microsoft.XMLDOM");
	  xmldoc.async=false;
	  xmldoc.load(data);
		trace("Transforming with xsl: ")
		trace(_listXsl);
    	resultDocument=xmldoc.transformNode(_listXsl);
		trace(typeof(resultDocument));
	  //document.getElementById("example").innerHTML=resultDocument;
	}
	// code for Mozilla, Firefox, Opera, etc.
	else if (document.implementation && document.implementation.createDocument)
	{
	  xsltProcessor=new XSLTProcessor();
	  xsltProcessor.importStylesheet(_listXsl);
	  resultDocument = xsltProcessor.transformToFragment(data,document);
	}
	var cols = jQuery(this).attr('cols');
	if(cols) {jQuery(resultDocument).children().removeClass('size4').addClass('size'+cols);}
	jQuery(this).replaceWith(resultDocument);
	initFluidLists();
	resizeFacebook();
	correctErroredImages();
}

function handleAjaxError(data, textStatus, jqXHR)
{
	trace("error from xhr: "+textStatus);
	trace(data);
}

//Wrap any call that requires facebook to be init'ed in this function
//we settimeout if we need to wait, due to timing issues seen with the fb api
function requireFacebookInit(func)
{
	if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined' && WPJS.FbJsHasInited) { trace('fb loaded, not firing fbinit.'); func(); }
	else { trace('will wait for fbInit to fire.'); jQuery('body').bind('fbInit', function(){window.setTimeout(func, 500);}); }
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

