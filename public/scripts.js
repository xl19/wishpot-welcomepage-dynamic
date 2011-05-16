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
