/*
 * Copyright 1998-2010 Linux.org.ru
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

package ru.org.linux.spring;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import org.springframework.context.support.ApplicationObjectSupport;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.view.RedirectView;

import ru.org.linux.site.*;

@Controller
public class EditController extends ApplicationObjectSupport {
  @RequestMapping(value = "/edit.jsp", method = RequestMethod.GET)
  public ModelAndView showForm(
    HttpServletRequest request,
    @RequestParam("msgid") int msgid)
    throws Exception {

    Template tmpl = Template.getTemplate(request);
    HttpSession session = request.getSession();

    if (!tmpl.isSessionAuthorized()) {
      throw new AccessViolationException("Not authorized");
    }

    Map<String, Object> params = new HashMap<String, Object>();

    Connection db = null;
    try {
      db = LorDataSource.getConnection();

      Message message = new Message(db, msgid);
      params.put("message", message);

      Group group = new Group(db, message.getGroupId());
      params.put("group", group);

      User user = User.getCurrentUser(db, session);

      if (!message.isEditable(db, user)) {
        throw new AccessViolationException("это сообщение нельзя править");
      }

      params.put("newMsg", message);

      params.put("commit", !message.isCommited() && message.getSection().isPremoderated() && user.canModerate());

      List<EditInfoDTO> editInfoList = message.loadEditInfo(db);
      if (editInfoList!=null) {
        params.put("editInfo", editInfoList.get(0));
      }

      return new ModelAndView("edit", params);
    } finally {
      if (db != null) {
        db.close();
      }
    }
  }

  @RequestMapping(value = "/edit.jsp", method = RequestMethod.POST)
  public ModelAndView edit(
    HttpServletRequest request,
    @RequestParam("msgid") int msgid,
    @RequestParam(value="lastEdit", required=false) Long lastEdit,
    @RequestParam(value="bonus", required=false, defaultValue="3") int bonus)
    throws Exception {

    Template tmpl = Template.getTemplate(request);
    HttpSession session = request.getSession();

    if (!tmpl.isSessionAuthorized()) {
      throw new AccessViolationException("Not authorized");
    }

    Map<String, Object> params = new HashMap<String, Object>();

    Connection db = null;
    try {
      db = LorDataSource.getConnection();
      db.setAutoCommit(false);

      Message message = new Message(db, msgid);
      params.put("message", message);

      Group group = new Group(db, message.getGroupId());
      params.put("group", group);

      User user = User.getCurrentUser(db, session);

      if (!message.isEditable(db, user)) {
        throw new AccessViolationException("это сообщение нельзя править");
      }

      if (!message.isExpired()) {
        String title = request.getParameter("title");
        if (title == null || title.trim().length() == 0) {
          throw new BadInputException("заголовок сообщения не может быть пустым");
        }
      }

      List<EditInfoDTO> editInfoList = message.loadEditInfo(db);

      boolean preview = request.getParameter("preview") != null;
      if (preview) {
        params.put("info", "Предпросмотр");
      }

      if (editInfoList!=null) {
        EditInfoDTO dbEditInfo = editInfoList.get(0);
        params.put("editInfo", dbEditInfo);

        if (lastEdit == null || dbEditInfo.getEditdate().getTime()!=lastEdit) {
          params.put("info", "Сообщение было отредактировано независимо");
          preview = true;
        }
      }

      boolean commit = request.getParameter("commit") != null;

      if (commit) {
        user.checkCommit();
        if (message.isCommited()) {
          throw new BadInputException("сообщение уже подтверждено");
        }
      }

      Message newMsg = new Message(db, message, request);

      boolean modified = false;

      if (!message.getTitle().equals(newMsg.getTitle())) {
        modified = true;
      }

      boolean messageModified = false;
      if (!message.getMessage().equals(newMsg.getMessage())) {
        messageModified = true;
      }

      if (message.getLinktext() == null) {
        if (newMsg.getLinktext() != null) {
          modified = true;
        }
      } else if (!message.getLinktext().equals(newMsg.getLinktext())) {
        modified = true;
      }

      if (message.isHaveLink()) {
        if (message.getUrl() == null) {
          if (newMsg.getUrl() != null) {
            modified = true;
          }
        } else if (!message.getUrl().equals(newMsg.getUrl())) {
          modified = true;
        }
      }

      if (message.isExpired() && (modified || messageModified)) {
        throw new AccessViolationException("нельзя править устаревшие сообщения");
      }

      if (!preview) {
        PreparedStatement pst = db.prepareStatement("UPDATE topics SET title=?, linktext=?, url=? WHERE id=?");

        pst.setString(1, newMsg.getTitle());
        pst.setString(2, newMsg.getLinktext());
        pst.setString(3, newMsg.getUrl());
        pst.setInt(4, message.getId());

        if (modified) {
          pst.executeUpdate();
        }

        if (messageModified) {
          newMsg.updateMessageText(db, user);
        }

        List<String> oldTags = message.getTags().getTags();
        List<String> newTags = Tags.parseTags(newMsg.getTags().toString());

        boolean modifiedTags = Tags.updateTags(db, message.getId(), newTags);
        if (modifiedTags && message.isCommited()) {
          Tags.updateCounters(db, oldTags, newTags);
        }

        params.put("modifiedTags", modifiedTags);
        params.put("modified", modified || messageModified || modifiedTags);

        if (commit) {
          message.commit(db, user, bonus);
        }

        if (modified || messageModified || modifiedTags || commit) {
          if (modified || messageModified || modifiedTags) {
            logger.info("сообщение " + message.getId() + " исправлено " + session.getValue("nick"));
          }

          db.commit();
          return new ModelAndView(new RedirectView(message.getLinkLastmod()));
        } else {
          params.put("info", "nothing changed");
        }
      }

      params.put("newMsg", newMsg);

      return new ModelAndView("edit", params);
    } finally {
      if (db != null) {
        db.close();
      }
    }
  }
}
