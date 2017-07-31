#!/usr/bin/python
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)
ANSIBLE_METADATA = {
    'metadata_version': '1.0',
    'status': ['preview'],
    'supported_by': '@gekmihesg'
}
DOCUMENTATION = '''
---
module: nohup
short_description: Starts a command in background and returns
description:
  - The M(nohup) module start runs a command in a shell using OpenWRTs C(start-stop-daemon).
  - The module will dispatch the command and return.
author: Markus Weippert (@gekmihesg)
options:
  command:
    description:
      - command to execute. Execution takes place in a shell.
    required: true
    aliases:
      - cmd
  delay:
    description:
      - seconds to wait, before command is run.
    default: 0
note:
  - This module does not support check_mode.
'''
EXAMPLES = '''
- name: wait 3 seconds, then restart network
  nohup:
    command: /etc/init.d/network restart
    delay: 3
'''
