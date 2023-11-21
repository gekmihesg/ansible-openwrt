import os
from ansible.plugins.action import ActionBase
from ansible.plugins.vars import BaseVarsPlugin
try:
    from ansible.utils.collection_loader import resource_from_fqcr
except ImportError:
    resource_from_fqcr = lambda x: x

def _fix_module_args(module_args):
    for k, v in module_args.items():
        if v is None:
            module_args[k] = False
        elif isinstance(v, dict):
            _fix_module_args(v)
        elif isinstance(v, list):
            module_args[k] = [False if i is None else i for i in v]

def _configure_module(self, module_name, module_args, task_vars=None):
    if task_vars is None:
        task_vars = dict()
    if self._task.delegate_to:
        real_vars = task_vars.get('ansible_delegated_vars', dict()).get(self._task.delegate_to, dict())
    else:
        real_vars = task_vars
    if real_vars.get('ansible_connection', '') not in ('local',) and \
            'openwrt' in real_vars.get('group_names', list()):
        leaf_module_name = resource_from_fqcr(module_name)
        openwrt_module = self._shared_loader_obj.module_loader.find_plugin('openwrt_' + leaf_module_name, '.sh')
        if openwrt_module:
            module_name = os.path.basename(openwrt_module)[:-3]
    else:
        openwrt_module = None
    (module_style, module_shebang, module_data, module_path) = \
            self.__configure_module(module_name, module_args, task_vars)
    if openwrt_module:
        with open(_wrapper_file, 'r') as f:
            wrapper_data = f.read()
        if type(module_data) is bytes:
            module_data = module_data.decode()
        module_data = wrapper_data.replace('\n. "$_script"\n', '\n' + module_data + '\n')
        _fix_module_args(module_args)
    return (module_style, module_shebang, module_data, module_path)

if ActionBase._configure_module != _configure_module:
    _wrapper_file = os.path.join(os.path.dirname(__file__), '..', 'files', 'wrapper.sh')
    ActionBase.__configure_module = ActionBase._configure_module
    ActionBase._configure_module = _configure_module

class VarsModule(BaseVarsPlugin):
    def get_vars(*args, **kwargs):
        return dict()
