#!/usr/bin/env python3
"""codex-trusted: which hooks it trusts, and runs against a fake codex that speaks the app-server protocol."""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
WRAPPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "codex-trusted")
loader = importlib.machinery.SourceFileLoader("codex_trusted", WRAPPER)
spec = importlib.util.spec_from_loader("codex_trusted", loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)

# A fake codex. `app-server` keeps the state of FAKE_HOOKS and FAKE_MARKETPLACES (the loaded ones) in memory:
# marketplace/upgrade loads one of FAKE_FETCHABLE, plugin/install installs a plugin, config/batchWrite trusts the hooks
# it names and logs its params to FAKE_LOG. FAKE_FAIL names a method that fails. Anything else prints its arguments.
FAKE = r'''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1:2] != ["app-server"]:
    print("ran " + json.dumps(sys.argv[1:]))
    sys.exit(0)
hooks = json.loads(os.environ["FAKE_HOOKS"])
loaded = json.loads(os.environ["FAKE_MARKETPLACES"])
fetchable = json.loads(os.environ.get("FAKE_FETCHABLE", "[]"))
for line in sys.stdin:
    msg = json.loads(line)
    m, p, result = msg["method"], msg["params"], {}
    print(json.dumps({"method": "note/unrelated", "params": {}}), flush=True)
    if m == os.environ.get("FAKE_FAIL"):
        print(json.dumps({"id": msg["id"], "error": {"message": "boom"}}), flush=True)
        continue
    if m == "config/read":
        result = {"layers": [
            {"name": {"type": "user", "profile": "p", "file": "/wrong"}, "version": "v0"},
            {"name": {"type": "user", "file": os.environ["CODEX_HOME"] + "/config.toml"}, "version": "v1"}]}
    elif m == "hooks/list":
        result = {"data": [{"cwd": "/", "hooks": hooks}]}
    elif m == "plugin/list":
        result = {"marketplaces": loaded, "marketplaceLoadErrors": []}
    elif m == "marketplace/upgrade":
        loaded += [mk for mk in fetchable if mk["name"] == p["marketplaceName"]]
    elif m == "plugin/install":
        for mk in loaded:
            for pl in mk["plugins"]:
                if mk["path"] == p["marketplacePath"] and pl["name"] == p["pluginName"]:
                    pl["installed"] = True
    elif m == "config/batchWrite":
        with open(os.environ["FAKE_LOG"], "w") as f:
            json.dump(p, f)
        keys = {e["keyPath"].split('"')[1] for e in p["edits"]}
        for h in hooks:
            if h["key"] in keys:
                h["trustStatus"] = "trusted"
    print(json.dumps({"id": msg["id"], "result": result}), flush=True)
'''

OURS = {"kvokka-harness-plugins"}


def hook(**kw):
    h = {"key": "dcg@kvokka-harness-plugins:hooks/hooks.json:pre_tool_use:0:0", "source": "plugin",
         "pluginId": "dcg@kvokka-harness-plugins", "trustStatus": "modified", "currentHash": "sha256:new",
         "isManaged": False, "enabled": True}
    h.update(kw)
    return h


def marketplace(name, *plugins):
    return {"name": name, "path": "/m/" + name, "plugins": [
        {"id": "%s@%s" % (p, name), "name": p, "enabled": True, "installed": installed} for p, installed in plugins]}


class Edits(unittest.TestCase):
    def test_trusts_new_and_modified_hooks_of_the_chosen_marketplaces_only(self):
        hooks = [
            hook(),
            hook(key="k2", trustStatus="untrusted"),
            hook(key="k3", trustStatus="trusted"),
            hook(key="k4", pluginId="dcg@other"),
            hook(key="k5", source="user"),
            hook(key="k6", enabled=False),
            hook(key="k7", isManaged=True),
            hook(key="k8", pluginId="ponytail@ponytail"),
        ]
        self.assertEqual(wrapper.edits(hooks, OURS), [
            {"keyPath": 'hooks.state."dcg@kvokka-harness-plugins:hooks/hooks.json:pre_tool_use:0:0".trusted_hash',
             "value": "sha256:new", "mergeStrategy": "upsert"},
            {"keyPath": 'hooks.state."k2".trusted_hash', "value": "sha256:new", "mergeStrategy": "upsert"},
        ])
        self.assertEqual([e["keyPath"] for e in wrapper.edits(hooks, OURS | {"ponytail"})][-1],
                         'hooks.state."k8".trusted_hash')

    def test_reads_the_marketplaces_from_the_environment(self):
        os.environ["CODEX_TRUSTED_MARKETPLACES"] = "kvokka-harness-plugins, ponytail"
        try:
            self.assertEqual(wrapper.marketplaces(), {"kvokka-harness-plugins", "ponytail"})
        finally:
            del os.environ["CODEX_TRUSTED_MARKETPLACES"]
        self.assertEqual(wrapper.marketplaces(), OURS)


class Run(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        os.mkdir(os.path.join(self.dir, "bin"))
        fake = os.path.join(self.dir, "bin", "codex")
        with open(fake, "w") as f:
            f.write(FAKE)
        os.chmod(fake, 0o755)
        self.log = os.path.join(self.dir, "log.json")
        self.env = dict(os.environ, PATH=os.path.join(self.dir, "bin") + os.pathsep + os.path.dirname(sys.executable),
                        CODEX_HOME=self.dir, FAKE_LOG=self.log,
                        FAKE_HOOKS=json.dumps([hook(), hook(key="k3", trustStatus="trusted")]),
                        FAKE_MARKETPLACES=json.dumps([marketplace("kvokka-harness-plugins", ("dcg", True))]))
        for name in ("CODEX_TRUSTED_REAL", "CODEX_TRUSTED_MARKETPLACES"):
            self.env.pop(name, None)

    def run_wrapper(self, **env):
        return subprocess.run([WRAPPER, "exec", "a b"], env=dict(self.env, **env), capture_output=True, text=True,
                              timeout=60)

    def test_writes_trust_to_the_user_layer_then_runs_codex(self):
        r = self.run_wrapper()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, 'ran ["exec", "a b"]\n')
        self.assertIn("trusted 1 hook(s)", r.stderr)
        with open(self.log) as f:
            params = json.load(f)
        self.assertEqual(params["filePath"], self.dir + "/config.toml")
        self.assertEqual(params["expectedVersion"], "v1")
        self.assertTrue(params["reloadUserConfig"])
        self.assertEqual([e["value"] for e in params["edits"]], ["sha256:new"])

    def test_fetches_a_marketplace_and_installs_its_enabled_plugins(self):
        r = self.run_wrapper(CODEX_TRUSTED_MARKETPLACES="kvokka-harness-plugins ponytail",
                             FAKE_FETCHABLE=json.dumps([marketplace("ponytail", ("ponytail", False))]))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, 'ran ["exec", "a b"]\n')
        self.assertIn("fetched marketplace ponytail, installed ponytail@ponytail, trusted 1 hook(s)", r.stderr)

    def test_all_in_place_runs_codex_quietly(self):
        r = self.run_wrapper(FAKE_HOOKS=json.dumps([hook(trustStatus="trusted")]))
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, 'ran ["exec", "a b"]\n', ""))

    def test_a_hook_left_untrusted_stops_codex_loudly(self):
        r = self.run_wrapper(FAKE_FAIL="config/batchWrite")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stdout, "")
        self.assertIn("codex is not started", r.stderr)
        self.assertIn("hook dcg@kvokka-harness-plugins:hooks/hooks.json:pre_tool_use:0:0 is not trusted", r.stderr)
        self.assertIn("boom", r.stderr)

    def test_a_plugin_left_uninstalled_stops_codex_loudly(self):
        r = self.run_wrapper(FAKE_FAIL="plugin/install", FAKE_MARKETPLACES=json.dumps(
            [marketplace("kvokka-harness-plugins", ("dcg", True), ("cache-warm", False))]))
        self.assertEqual(r.returncode, 1)
        self.assertIn("plugin cache-warm@kvokka-harness-plugins is not installed", r.stderr)

    def test_a_marketplace_that_does_not_load_stops_codex_loudly(self):
        r = self.run_wrapper(CODEX_TRUSTED_MARKETPLACES="kvokka-harness-plugins ponytail")
        self.assertEqual(r.returncode, 1)
        self.assertIn("marketplace ponytail does not load", r.stderr)

    def test_a_broken_app_server_stops_codex_loudly(self):
        r = self.run_wrapper(FAKE_FAIL="hooks/list")
        self.assertEqual((r.returncode, r.stdout), (1, ""))
        self.assertIn("hooks/list", r.stderr)


if __name__ == "__main__":
    unittest.main()
