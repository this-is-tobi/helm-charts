"""Write the pod's settings.yml: the chart's settings with the Secret values set at the given paths.

Run by the render-settings init container as
  render-settings.py <dotted.path>=<ENVIRONMENT_VARIABLE>...
SearXNG only reads a few settings from its environment and cannot include a second file.
"""
import os
import shutil
import sys

import yaml

SOURCE, TARGET = "/config", "/rendered"

for name in os.listdir(SOURCE):
    if not name.startswith("."):
        shutil.copyfile(os.path.join(SOURCE, name), os.path.join(TARGET, name))

with open(os.path.join(SOURCE, "settings.yml")) as source:
    settings = yaml.safe_load(source)

for spec in sys.argv[1:]:
    path, variable = spec.split("=", 1)
    *parents, leaf = path.split(".")
    node = settings
    for key in parents:
        node = node.setdefault(key, {})
    node[leaf] = os.environ[variable]

with open(os.path.join(TARGET, "settings.yml"), "w") as target:
    yaml.safe_dump(settings, target, allow_unicode=True, sort_keys=False)
