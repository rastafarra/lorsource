<%@ page contentType="text/html; charset=koi8-r"%>
<%@ page import="java.net.URLEncoder,java.sql.Connection,java.sql.ResultSet,java.sql.Statement,java.sql.Timestamp,java.util.ArrayList,java.util.Collections,java.util.Iterator" errorPage="error.jsp" buffer="200kb"%>
<%@ page import="java.util.List"%>
<%@ page import="javax.servlet.http.HttpServletResponse"%>
<%@ page import="ru.org.linux.site.*"%>
<%@ page import="ru.org.linux.util.BadImageException"%>
<%@ page import="ru.org.linux.util.ImageInfo"%>
<%@ page import="ru.org.linux.util.StringUtil"%>
<% Template tmpl = new Template(request, config, response); %>
<%= tmpl.head() %>
<%
  Connection db = null;
  try {
    int groupId = Integer.parseInt(request.getParameter("group"));
    boolean showDeleted = request.getParameter("deleted") != null;

    if (showDeleted && !"POST".equals(request.getMethod())) {
      response.setHeader("Location", tmpl.getRedirectUrl() + "/group.jsp?group=" + groupId);
      response.setStatus(HttpServletResponse.SC_MOVED_PERMANENTLY);

      showDeleted = false;
    }

    if (showDeleted && !Template.isSessionAuthorized(session)) {
      throw new AccessViolationException("�� �� ������������");
    }


    if (request.getParameter("group") == null) {
      throw new MissingParameterException("group");
    }

    final boolean firstPage;
    final int offset;

    if (request.getParameter("offset") != null) {
      offset = Integer.parseInt(request.getParameter("offset"));
      firstPage = false;
    } else {
      firstPage = true;
      offset = 0;
    }

    String returnUrl;
    if (offset > 0) {
      returnUrl = "group.jsp?group=" + groupId + "&amp;offset=" + offset;
    } else {
      returnUrl = "group.jsp?group=" + groupId;
    }

    db = tmpl.getConnection("group");
    db.setAutoCommit(false);

    Group group = new Group(db, groupId);

    Statement st = db.createStatement();

    ResultSet rs;
    if (showDeleted) {
      rs = st.executeQuery("SELECT count(topics.id) FROM topics,groups,sections WHERE (topics.moderate OR NOT sections.moderate) AND groups.section=sections.id AND topics.groupid=" + groupId + " AND groups.id=" + groupId);
    } else {
      rs = st.executeQuery("SELECT count(topics.id) FROM topics,groups,sections WHERE (topics.moderate OR NOT sections.moderate) AND groups.section=sections.id AND topics.groupid=" + groupId + " AND groups.id=" + groupId + " AND NOT topics.deleted");
    }

    int count = 0;
    int pages = 0;
    int topics = tmpl.getProf().getIntProperty("topics");

    if (rs.next()) {
      count = rs.getInt("count");
      pages = count / topics;
      if (count % topics != 0) {
        count = (pages + 1) * topics;
      }
    }
    rs.close();

    int section = group.getSectionId();
    if (section == 0) {
      throw new BadGroupException();
    }
    if (group.isLinksUp()) {
      throw new BadGroupException();
    }

    if (firstPage || offset>=pages*topics) {
      response.setDateHeader("Expires", System.currentTimeMillis()+90*1000);
    } else {
      response.setDateHeader("Expires", System.currentTimeMillis()+30*24*60*60*1000L);
    }

    out.print("<title>" + group.getSectionName() + " - " + group.getTitle() + " (��������� " + (count - offset) + '-' + (count - offset - topics) + ")</title>");
    out.print("<link rel=\"parent\" title=\"" + group.getTitle() + "\" href=\"view-section.jsp?section=" + group.getSectionId() + "\">");
%>
<%=   tmpl.DocumentHeader() %>
<div class=messages>
<div class=nav>
<form action="group.jsp">

<div class="color1">
  <table width="100%" cellspacing=1 cellpadding=1 border=0><tr class=body>
    <td align=left valign=middle>
      <a href="view-section.jsp?section=<%= group.getSectionId() %>"><%= group.getSectionName() %></a> - <strong><%= group.getTitle() %></strong>
    </td>

    <td align=right valign=middle>
      [<a style="text-decoration: none" href="faq.jsp">FAQ</a>]
      [<a style="text-decoration: none" href="rules.jsp">������� ������</a>]
<%
  User currentUser = User.getCurrentUser(db, session);

  if (group.isTopicPostingAllowed(currentUser)) {
    if (section==3) {
      if (tmpl.getProfileName()!=null) {
        out.print("[<a style=\"text-decoration: none\" href=\"http://images.linux.org.ru/addsshot.php?profile="+URLEncoder.encode(tmpl.getProfileName())+"\">�������� �����������</a>]");
      } else {
         out.print("[<a style=\"text-decoration: none\" href=\"http://images.linux.org.ru/addsshot.php\">�������� �����������</a>]");
      }
    } else {
%>
      [<a style="text-decoration: none" href="add.jsp?group=<%= groupId %>&amp;return=<%= URLEncoder.encode(returnUrl) %>">�������� ���������</a>]
<%
    }
  }
%>
      <select name=group onChange="submit()" title="������� �������">
<%
	Statement sectionListSt = db.createStatement();
	ResultSet sectionList = sectionListSt.executeQuery("SELECT id, title FROM groups WHERE section="+section+" order by id");

	while (sectionList.next()) {
		int id = sectionList.getInt("id");
%>
        <option value=<%= id %> <%= id==groupId?"selected":"" %> ><%= sectionList.getString("title") %></option>
<%
	}

	sectionList.close();
	sectionListSt.close();
%>
      </select>
     </td>
    </tr>
 </table>
</div>
</form>

</div>
</div>

<%
	out.print("<h1>");

	out.print(group.getSectionName()+": "+group.getTitle()+"</h1>");

	if (group.getImage()!=null) {
          out.print("<div align=center>");
          try {
            ImageInfo info=new ImageInfo(tmpl.getObjectConfig().getHTMLPathPrefix()+tmpl.getStyle()+group.getImage());
	    out.print("<img src=\"/" + tmpl.getStyle() + group.getImage() + "\" " + info.getCode() + " border=0 alt=\"������ " + group.getTitle() + "\">");
          } catch (BadImageException ex) {
            out.print("[bad image]");
          }
          out.print("</div>");
        }

	String des=tmpl.getObjectConfig().getStorage().readMessageNull("grinfo", String.valueOf(groupId));
	if (des!=null) {
		out.print("<em>");
		out.print(des);
		out.print("</em>");
	}
%>
<div class=forum>
<table width="100%" class="message-table">
<thead>
<tr><th>���������
<%
  if (!tmpl.isSearchMode()) {
	out.print("<span style=\"font-weight: normal\">[�������: ");

        out.print("<b>���� ��������</b> <a href=\"group-lastmod.jsp?group="+groupId +"\" style=\"text-decoration: underline\">���� ���������</a>");

	out.print("]</span>");
   }
%></th><th>����� �������<br>�����/����/���</th></tr>
</thead>
<tbody>
<%
  String delq = showDeleted ? "" : " AND NOT deleted ";

  if (firstPage) {
    rs = st.executeQuery("SELECT topics.title as subj, lastmod, nick, topics.id as msgid, deleted, topics.stat1, topics.stat3, topics.stat4 FROM topics,groups,users, sections WHERE sections.id=groups.section AND (topics.moderate OR NOT sections.moderate) AND topics.userid=users.id AND topics.groupid=groups.id AND groups.id=" + groupId + delq + " AND postdate>(CURRENT_TIMESTAMP-'3 month'::interval) ORDER BY msgid DESC LIMIT " + topics);
  } else {
    rs = st.executeQuery("SELECT topics.title as subj, lastmod, nick, topics.id as msgid, deleted, topics.stat1, topics.stat3, topics.stat4 FROM topics,groups,users, sections WHERE sections.id=groups.section AND (topics.moderate OR NOT sections.moderate) AND topics.userid=users.id AND topics.groupid=groups.id AND groups.id=" + groupId + delq + " ORDER BY msgid ASC LIMIT " + topics + " OFFSET " + offset);
  }

  List outputList = new ArrayList();
  double messages = tmpl.getProf().getIntProperty("messages");

  while (rs.next()) {
    StringBuffer outbuf = new StringBuffer();
    int stat1 = rs.getInt("stat1");

    Timestamp lastmod = rs.getTimestamp("lastmod");
    if (lastmod == null) {
      lastmod = new Timestamp(0);
    }

    outbuf.append("<tr><td>");
    if (rs.getBoolean("deleted")) {
      outbuf.append("[X] ");
    }
    if (tmpl.isSearchMode()) {
      outbuf.append("<a href=\"view-message.jsp?msgid=").append(rs.getInt("msgid")).append("\" rev=contents>").append(StringUtil.makeTitle(rs.getString("subj"))).append("</a>");
    } else {
      outbuf.append("<a href=\"jump-message.jsp?msgid=").append(rs.getInt("msgid")).append("&amp;lastmod=").append(lastmod.getTime()).append("\" rev=contents>").append(StringUtil.makeTitle(rs.getString("subj"))).append("</a>");
    }

    int pagesInCurrent = (int) Math.ceil(stat1 / messages);
    if (!tmpl.isSearchMode() && pagesInCurrent > 1 ) {
      outbuf.append("&nbsp;(���.");
      for (int i = 0; i < pagesInCurrent; i++) {
        outbuf.append(" <a href=\"").append("jump-message.jsp?msgid=").append(rs.getInt("msgid")).append("&amp;lastmod=").append(lastmod.getTime()).append("&amp;page=").append(i).append("\">").append(i + 1).append("</a>");
      }
      outbuf.append(')');
    }

    outbuf.append(" (").append(rs.getString("nick")).append(')');
    outbuf.append("</td>");

    outbuf.append("<td align=center>");
    int stat3 = rs.getInt("stat3");
    int stat4 = rs.getInt("stat4");

    if (stat1 > 0) {
      outbuf.append("<b>").append(stat1).append("</b>/");
    } else {
      outbuf.append("-/");
    }

    if (stat3 > 0) {
      outbuf.append("<b>").append(stat3).append("</b>/");
    } else {
      outbuf.append("-/");
    }

    if (stat4 > 0) {
      outbuf.append("<b>").append(stat4).append("</b>");
    } else {
      outbuf.append('-');
    }


    outbuf.append("</td></tr>");

    outputList.add(outbuf.toString());
  }
  rs.close();

  if (!firstPage) {
    Collections.reverse(outputList);
  }

  for (Iterator i = outputList.iterator(); i.hasNext();) {
    out.print((String) i.next());
  }
%>
</tbody>
<tfoot>
<%
        out.print("<tr><td colspan=2><p>");

	out.print("<div style=\"float: left\">");

        // �����
        if (firstPage)
          out.print("");
	else if (offset==pages*topics)
          out.print("<a href=\"group.jsp?group="+groupId +(showDeleted?"&amp;deleted=t":"")+"\">������</a> ");
        else
          out.print("<a rel=prev rev=next href=\"group.jsp?group="+groupId +"&amp;offset="+(offset+topics)+(showDeleted?"&amp;deleted=t":"")+"\">�����</a>");
	out.print("</div>");

        // ������
	out.print("<div style=\"float: right\">");

        if (firstPage) {
          out.print("<a rel=next rev=prev href=\"group.jsp?group="+groupId +"&amp;offset="+(pages*topics)+(showDeleted?"&amp;deleted=t":"")+"\">�����</a>");
	} else if (offset==0 && !firstPage)
          out.print("<b>������</b>");
	else
          out.print("<a rel=next rev=prev href=\"group.jsp?group="+groupId +"&amp;offset="+(offset-topics)+(showDeleted?"&amp;deleted=t":"")+"\">������</a>");
	out.print("</div>");

%>
</tfoot>
</table>
</div>
<div align=center><p>
<%
  for (int i=0; i<=pages+1; i++) {
    if (firstPage) {
      if (i!=0 && i!=(pages+1) && i>7)
        continue;
    } else {
      if (i!=0 && i!=(pages+1) && Math.abs((pages+1-i)*topics-offset)>7*topics)
        continue;
    }

    if (i==pages+1) {
      if (offset!=0 || firstPage)
        out.print("[<a href=\"group.jsp?group="+groupId+"&amp;offset=0"+(showDeleted?"&amp;deleted=t":"")+"\">�����</a>] ");
      else
        out.print("[<b>�����</b>] ");
    } else if (i==0) {
        if (firstPage)
          out.print("[<b>������</b>] ");
        else
          out.print("[<a href=\"group.jsp?group="+groupId+(showDeleted?"&amp;deleted=t":"")+"\">������</a>] ");
    } else if ((pages+1-i)*topics==offset)
      out.print("[<b>"+(pages+1-i)+"</b>] ");
    else {
      out.print("[<a href=\"group.jsp?group="+groupId+"&amp;offset="+((pages+1-i)*topics)+(showDeleted?"&amp;deleted=t":"")+"\">"+(pages+1-i)+"</a>] ");
    }
  }
%>
<p>

<% if (tmpl.isSessionAuthorized(session) && !tmpl.isSearchMode() && !showDeleted) { %>
  <hr>
  <form action="group.jsp" method=POST>
  <input type=hidden name=group value=<%= groupId %>>
  <input type=hidden name=deleted value=1>
  <% if (!firstPage) { %>
    <input type=hidden name=offset value="<%= offset %>">
  <% } %>
  <input type=submit value="�������� ��������� ���������">
  </form>
  <hr>
<% } %>

</div>
<%
	st.close();
	db.commit();
%>
<%
  } finally {
    if (db!=null) db.close();
  }
%>
<%= tmpl.DocumentFooter() %>
