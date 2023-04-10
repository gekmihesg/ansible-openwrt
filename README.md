Ansible Role: openwrt
=====================

Manage OpenWRT and derivatives with Ansible but without Python.

By putting a host in the inventory group `openwrt`, some modules are replaced with a shell version running on a standard OpenWRT installation, trying to preserve most of the original functionality. Hosts, that are not in this group are not affected. This makes it possible to have tasks mixed with OpenWRT and other platforms.
There are also some new, OpenWRT specific modules included (like `uci`).
**Not all argument combinations are tested!** Some cases have only been translated from Python for completeness' sake.

Currently, the following modules have been implemented:
 * command
 * copy
 * fetch (implicit)
 * file
 * lineinfile
 * nohup (new)
 * opkg
 * ping
 * service
 * setup
 * shell (implicit)
 * slurp
 * stat
 * sysctl
 * template (implicit)
 * uci (new)
 * wait\_for\_connection (implicit)

To achieve all this, some monkey patching is involved (in case you wonder about the `vars_plugins`).

Compatibility
-------------

This role was tested successfully with:
 * LEDE 17.01 (manually)
 * OpenWRT 18.06
 * OpenWRT 19.07
 * OpenWRT 21.02
 * OpenWRT 22.03

__Recent versions of OpenSSH's__ scp utility [silently do sftp protocol](https://forum.openwrt.org/t/ash-usr-libexec-sftp-server-not-found-when-using-scp/125772), which OpenWRT may not have installed. If your playbooks fail with "/usr/libexec/sftp-server: not found" add "ansible_scp_extra_args: -O" to your playbook variables.

Requirements
------------

Some modules optionally require a way to generate SHA1 hashes or encode data Base64. In case of Base64, there is a very slow `hexdump | awk` implementation included. For SHA1 there is no workaround.
The modules will try to find usable system commands for SHA1 (`sha1sum`, `openssl`) and Base64 (`base64`, `openssl`, workaround) when needed. If no usable commands are found, most things will still work, but the fetch module for example has to be run with `validate_checksum: no`, will always download the file and return `changed: yes`.
Therefore it is recommended to install `coreutils-sha1sum` and `coreutils-base64`, if the commands are not already provided by busybox. The role does that automatically by default (see below).

Role Variables
--------------

    openwrt_install_recommended_packages:
        Checks for some commands and installs the corresponding packages if they are
        missing. See requirements above. (default: yes)

    openwrt_scp_if_ssh:
        Whether to use scp instead of sftp for OpenWRT systems. Value can be `yes`,
        `no` or `smart`. Ansible defaults to `smart` but this role defaults to `yes`
        because OpenWRT does not offer sftp by default. (default: yes)

    openwrt_remote_tmp:
        Ansibles remote_tmp setting for OpenWRT systems. Defaults to /tmp to avoid
        flash wear on target device. (default: /tmp)

    openwrt_wait_for_connection, openwrt_wait_for_connection_timeout:
        Whether to wait for the host (default: yes) and how long (300) after a
        network or wifi restart (see handlers).

    openwrt_ssh, openwrt_scp, openwrt_ssh_host, openwrt_ssh_user, openwrt_user_host:
        Helper shortcuts to do things like
        "command: {{ openwrt_scp }} {{ openwrt_user_host|quote }}:/etc/rc.local /tmp"

Example Playbook
----------------

Inventory:

```ini
[aps]
ap1.example.com
ap2.example.com
ap3.example.com

[routers]
router1.example.com

[openwrt:children]
aps
routers
```

Playbook:

```yaml
- hosts: openwrt
  roles:
    - gekmihesg.openwrt
  tasks:
    - name: copy openwrt image
      command: "{{ openwrt_scp }} image.bin {{ openwrt_user_host|quote }}:/tmp/sysupgrade.bin"
      delegate_to: localhost
    - name: start sysupgrade
      nohup:
        command: sysupgrade -q /tmp/sysupgrade.bin
    - name: wait for reboot
      wait_for_connection:
        timeout: 300
        delay: 60
    - name: install mdns
      opkg:
        name: mdns
        state: present
    - name: enable and start mdns
      service:
        name: mdns
        state: started
        enabled: yes
    - name: copy authorized keys
      copy:
        src: authorized_keys
        dest: /etc/dropbear/authorized_keys
    - name: revert pending changes
      uci:
        command: revert
    - name: configure wifi device radio0
      uci:
        command: set
        key: wireless.radio0
        value:
          phy: phy0
          type: mac80211
          hwmode: 11g
          channel: auto
    - name: configure wifi interface
      uci:
        command: section
        config: wireless
        type: wifi-iface
        find_by:
          device: radio0
          mode: ap
        value:
          ssid: MySSID
          encryption: psk2+ccmp
          key: very secret
    - name: commit changes
      uci:
        command: commit
      notify: reload wifi
```

Running the modules outside of a playbook is possible like this:

```bash
$ export ANSIBLE_LIBRARY=~/.ansible/roles/gekmihesg.openwrt/library
$ export ANSIBLE_VARS_PLUGINS=~/.ansible/roles/gekmihesg.openwrt/vars_plugins
$ ansible -i openwrt-hosts -m setup all
```

License
-------

GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

Developing
----------

Writing custom modules for this framework isn't to hard. The modules are wrapped into a wrapper script, that provides some common functions for parameter parsing, json handling, response generation, and some more.
All modules must match `openwrt_<module_name>.sh`. If module\_name is not one of Ansibles core modules, there must also be a `<module_name>.py`. This does not have to have any functionality (it may have some for non OpenWRT systems) and can contain the documentation.

Make sure to install the `requirements.txt` packages in your virtual environment and, with the venv activated, run:

```bash
$ molecule test
```

before commiting and submitting your PR.

Writing tests for your new module is also highly recommended.
