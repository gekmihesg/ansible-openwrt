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
module: uci
short_description: Controls OpenWRTs UCI
description:
  - The M(uci) module is a Ansible wrapper for OpenWRTs C(uci).
  - It supports all the command line functionality plus some extra commands.
author: Markus Weippert (@gekmihesg)
options:
  command:
    description:
      - Command to execute. Execution takes place in a shell.
    default: set if value else get
    choices:
      - add
      - add_list
      - batch
      - changes
      - commit
      - del_list
      - export
      - find
      - get
      - import
      - rename
      - reorder
      - revert
      - section
      - set
      - show
    aliases:
      - cmd
  config:
    description:
      - Config part of the I(key).
    default: extracted from I(key)
  find:
    description:
      - Value(s) to match sections against.
      - Option value to find if I(option) is set. May be list.
      - Dict of options/values if I(option) is not set. Values may be list.
      - Lists are compared in order.
      - Required when I(command=find) or I(command=section)
    aliases:
      - find_by
      - search
  keep_keys:
    description:
      - Space seperated list or list of keys not in I(value) or I(find) to
        keep when I(replace=yes).
    aliases:
      - keep
  key:
    description:
      - The C(uci) key to operate on.
      - Takes precedence over I(config), I(section) and I(option)
    default: I(config).I(section).I(option)
  merge:
    description:
      - Whether to merge or replace when I(command=import)
    type: bool
    default: false
  name:
    description:
      - New name when I(command=rename) or I(command=add).
      - Desired name when I(command=section). If a matching section is
        found it is renamed, if not it is created with that name.
  option:
    description:
      - Option part of the I(key).
    default: extracted from I(key)
  replace:
    description:
      - When I(command=set) or I(command=section), whether to delete all
        options not mentioned in I(keep_keys), I(value) or find when
        I(set_find=true).
    type: bool
    default: false
  section:
    description:
      - Section part of the I(key).
    default: extracted from I(key)
  set_find:
    description:
      - When I(command=section) whether to set the options used to search
        a matching section in the newly created section when no match was
        found.
    type: bool
    default: false
  type:
    description:
      - Section type for I(command=section), I(command=find) and
        I(command=add).
    default: I(section)
  unique:
    description:
      - When I(command=add_list), whether to add the value if it is already
        contained in the list.
    type: bool
    default: false
  value:
    description:
      - The value for various commands.
'''
EXAMPLES = '''
# Find a section of type wifi-iface with matching name or matching attributes.
# If not found create it and set the attributes from find.
# Unconditionally set the attributes from value and delete all other options.
- uci:
    command: section
    config: wireless
    type: wifi-iface
    name: ap0
    find:
      device: radio0
      ssid: My SSID
    value:
      encryption: none
    replace: yes

# commit changes and notify
- uci: cmd=commit
  notify: restart wifi
'''
RETURN = '''
result:
    description: output of the C(uci) command
    returned: always
    type: string
    sample: cfg12523
result_list:
    description: the list form of result
    returned: when I(command=get)
    type: list of string
    sample: ['0.pool.ntp.org','1.pool.ntp.org']
config:
    description: config part of I(key)
    returned: when given
    type: string
    sample: wireless
section:
    description: section part of I(key)
    returned: when given
    type: string
    sample: @wifi-iface[0]
option:
    description: option part of I(key)
    returned: when given
    type: string
    sample: ssid
command:
    description: command executed
    returned: always
    type: string
    sample: section
'''

