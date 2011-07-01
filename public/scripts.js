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

attachOnload(function(){
    if(typeof(FB) != 'undefined' && typeof(FB.Canvas) != 'undefined')
      FB.Canvas.setSize();
});
