class Terminal < Desktop::Item
  # Copyright (c) 2011-2017 elementary LLC. (https://elementary.io)
  # From: https://github.com/elementary/terminal/blob/c3e36fb2ab64c18028ff2b4a6da5bfb2171c1c04/src/Widgets/TerminalWidget.vala
  USERCHARS       = "-[:alnum:]"
  USERCHARS_CLASS = "[#{USERCHARS}]"
  PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]"
  HOSTCHARS_CLASS = "[-[:alnum:]]"
  HOST            = "#{HOSTCHARS_CLASS}+(\\.#{HOSTCHARS_CLASS}+)*"
  PORT            = "(?:\\:[[:digit:]]{1,5})?"
  PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,;:@&=?/~#%\\E]"
  PATHTERM_CLASS  = "[^\\Q]'.}>) \t\r\n,\"\\E]"
  SCHEME          = "(?:news:|telnet:|nntp:|file:|https?:|ftps?:|sftp:|webcal:" \
                    "|irc:|sftp:|ldaps?:|nfs:|smb:|rsync:|ssh:|rlogin:|telnet:|git:" \
                    "|git\\+ssh:|bzr:|bzr\\+ssh:|svn:|svn\\+ssh:|hg:|mailto:|magnet:)"

  USERPASS = "#{USERCHARS_CLASS}+(?:#{PASSCHARS_CLASS}+)?"
  URLPATH  = "(?:(/#{PATHCHARS_CLASS}+(?:[(]#{PATHCHARS_CLASS}*[)])*#{PATHCHARS_CLASS}*)*#{PATHTERM_CLASS})?"

  URL_REGEX_STRINGS = {
    "#{SCHEME}//(?:#{USERPASS}\\@)?#{HOST}#{PORT}#{URLPATH}",
    "(?:www|ftp)#{HOSTCHARS_CLASS}*\\.#{HOST}#{PORT}#{URLPATH}",
    "(?:callto:|h323:|sip:)#{USERCHARS_CLASS}[#{USERCHARS}.]*(?:#{PORT}/[a-z0-9]+)?\\@#{HOST}",
    "(?:mailto:)?#{USERCHARS_CLASS}[#{USERCHARS}.]*\\@#{HOSTCHARS_CLASS}+\\.#{HOST}",
    "(?:news:|man:|info:)[[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+",
  }
end
