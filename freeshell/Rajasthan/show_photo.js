function show_photo(name, alt, width, height)
{
	var text="";
	text += "<html><head><title>" + alt + "</title>";
	text += "<link rel=\"stylesheet\" type=\"text/css\" href=\"rajasthan.css\">";
	text += "</head>";
	text += "<body class=\"photo\">";

	text += "<p><img src=\"big/" + name + ".jpg\" alt=\"" + alt + "\" id=\"main-image\" height=\"" + height + "\" width=\"" + width + "\"><br>";
	text += alt + "</p>";
	text += "</body></html>";

	var mywin = open("blank.html", "photoWindow",
		"width=" + (width+20) + ",height=" + (height+72) + ",status=no,menubar=no,toolbar=no,scrollbars=yes");

	var doc = mywin.document;

	doc.write(text);

	return false;
}
