---
name: Bug report
about: Create a report to help us improve

---

<!--
Kamailio Project uses GitHub Issues only for bugs in the code or feature requests. Please use this template only for bug reports.

If you have questions about using Kamailio or related to its configuration file, ask on sr-users mailing list:

  * https://lists.kamailio.org/mailman3/postorius/lists/sr-users.lists.kamailio.org/

If you have questions about developing extensions to Kamailio or its existing C code, ask on sr-dev mailing list:

  * https://lists.kamailio.org/mailman3/postorius/lists/sr-dev.lists.kamailio.org/

Please try to fill this template as much as possible for any issue. It helps the developers to troubleshoot the issue.

Note that an issue report may be closed automatically after about 2 months
if there is no interest from developers or community users on pursuing it, being
considered expired. In such case, it can be reopened by writing a comment that includes
the token `/notexpired`. About two weeks before considered expired, the issue is
marked with the label `stale`, trying to notify the submitter and everyone else
that might be interested in it. To remove the label `stale`, write a comment that
includes the token `/notstale`. Also, any comment postpone the `expire` timeline,
being considered that there is interest in pursuing the issue.

If there is no content to be filled in a section, the entire section can be removed.

You can delete the comments from the template sections when filling.

You can delete next line and everything above before submitting (it is a comment).
-->

### Description

<!--
Explain what you did, what you expected to happen, and what actually happened.
-->

### Troubleshooting

#### Reproduction

<!--
If the issue can be reproduced, describe how it can be done.
-->

#### Debugging Data

<!--
If you got a core dump, use gdb to extract troubleshooting data - full backtrace,
local variables and the list of the code at the issue location.

  gdb /path/to/kamailio /path/to/corefile
  bt full
  info locals
  list

If you are familiar with gdb, feel free to attach more of what you consider to
be relevant.
-->

```
(paste your debugging data here)
```

#### Log Messages

<!--
Check the syslog file and if there are relevant log messages printed by Kamailio, add them next, or attach to issue, or provide a link to download them (e.g., to a pastebin site).
-->

```
(paste your log messages here)
```

#### SIP Traffic

<!--
If the issue is exposed by processing specific SIP messages, grab them with ngrep or save in a pcap file, then add them next, or attach to issue, or provide a link to download them (e.g., to a pastebin site).
-->

```
(paste your sip traffic here)
```

### Possible Solutions

<!--
If you found a solution or workaround for the issue, describe it. Ideally, provide a pull request with a fix.
-->

### Additional Information

  * **Kamailio Version** - output of `kamailio -v`

```
(paste your output here)
```

* **Operating System**:

<!--
Details about the operating system, the type: Linux (e.g.,: Debian 8.4, Ubuntu 16.04, CentOS 7.1, ...), MacOS, xBSD, Solaris, ...;
Kernel details (output of `lsb_release -a` and `uname -a`)
-->

```
(paste your output here)
```
