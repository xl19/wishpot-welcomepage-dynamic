function appendDetailsToForm(session)
{
	if(null != session)
	{
		var forms = document.getElementsByTagName('form');
		var iuid = document.createElement('input');
		iuid.setAttribute("type", "hidden");
		iuid.setAttribute("name", "uid");
		iuid.setAttribute("value", session.uid);
		for(var i=0; i<forms.length; i++)
			forms[i].appendChild(iuid);
	}
}

function attachOnload(myFunction)
{
  if (window.addEventListener) // W3C standard
    window.addEventListener('load', myFunction, false); // NB **not** 'onload'
  else if (window.attachEvent) // Microsoft
    window.attachEvent('onload', myFunction);
}

function replaceTags(tagCollection, replacementNode)
{
  for(var i=0;i<tagCollection.length;i++)
  {
    tagCollection[i].parentNode.insertBefore(replacementNode, tagCollection[i]);
    tagCollection[i].parentNode.removeChild(tagCollection[i]);
  }
}

function parseVenpopML()
{
  //for markup that requires facebook
  if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined')
  {
    var tags = document.getElementsByTagName('vp:pagename');
    if(null != tags && tags.length > 0 && VP.PageId != null)
    {
      FB.api('/'+VP.PageId, function(response) {
        if(response != undefined)
          replaceTags(tags, document.createTextNode(response.name));
      });
    }
  }  
}

attachOnload(function(){
    if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined')
      FB.Canvas.setSize();
});
