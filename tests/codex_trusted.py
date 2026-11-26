#!/usr/bin/env python3
"""codex-trusted: which hooks it trusts, and a run against a fake codex that speaks the app-server protocol."""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

WRAPPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "codex-trusted")
loader = importlib.machinery.SourceFileLoader("codex_trusted", WRAPPER)
spec = importlib.util.spec_from_loader("codex_trusted", loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)

# A fake codex: `app-server` answers the calls the wrapper makes (FAKE_FAIL names one to fail) and logs the batch
# write to FAKE_LOG; anything else prints its arguments.
FAKE = r'''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1:2] != ["app-server"]:
    print("ran " + json.dumps(sys.argv[1:]))
    sys.exit(0)
hooks = json.loads(os.environ["FAKE_HOOKS"])
for line in sys.stdin:
    msg = json.loads(line)
    m = msg["method"]
    print(json.dumps({"method": "note/unrelated", "params": {}}), flush=True)
    if m == os.environ.get("FAKE_FAIL"):
        out = {"id": msg["id"], "error": {"message": "boom"}}
    elif m == "initialize":
        out = {"id": msg["id"], "result": {}}
    elif m == "config/read":
        out = {"id": msg["id"], "result": {"layers": [
            {"name": {"type": "user", "profile": "p", "file": "/wrong"}, "version": "v0"},
            {"name": {"type": "user", "file": os.environ["CODEX_HOME"] + "/config.toml"}, "version": "v1"}]}}
    elif m == "hooks/list":
        out = {"id": msg["id"], "result": {"data": [{"cwd": "/", "hooks": hooks}]}}
    elif m == "config/batchWrite":
        with open(os.environ["FAKE_LOG"], "w") as f:
            json.dump(msg["params"], f)
        out = {"id": msg["id"], "result": {}}
    print(json.dumps(out), flush=True)
'''


def hook(**kw):
    h = {"key": "dcg@kvokka-harness-plugins:hooks/hooks.json:pre_tool_use:0:0", "source": "plugin",
         "pluginId": "dcg@kvokka-harness-plugins", "trustStatus": "modified", "currentHash": "sha256:new",
         "isManaged": False, "enabled": True}
    h.update(kw)
    return h


class Edits(unittest.TestCase):
    def test_trusts_new_and_modified_hooks_of_this_marketplace_only(self):
        hooks = [
            hook(),
            hook(key="k2", trustStatus="untrusted"),
            hook(key="k3", trustStatus="trusted"),
            hook(key="k4", pluginId="dcg@other"),
            hook(key="k5", source="user"),
            hook(key="k6", enabled=False),
            hook(key="k7", isManaged=True),
        ]
        self.assertEqual(wrapper.edits(hooks), [
            {"keyPath": 'hooks.state."dcg@kvokka-harness-plugins:hooks/hooks.json:pre_tool_use:0:0".trusted_hash',
             "value": "sha256:new", "mergeStrategy": "upsert"},
            {"keyPath": 'hooks.state."k2".trusted_hash', "value": "sha256:new", "mergeStrategy": "upsert"},
        ])


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
                        CODEX_HOME=self.dir, FAKE_LOG=self.log, FAKE_HOOKS=json.dumps([hook(), hook(key="k3",
                        trustStatus="trusted")]))
        self.env.pop("CODEX_TRUSTED_REAL", None)

    def run_wrapper(self, **env):
        return subprocess.run([WRAPPER, "exec", "a b"], env=dict(self.env, **env), capture_output=True, text=True,
                              timeout=60)

    def test_writes_trust_to_the_user_layer_then_runs_codex(self):
        r = self.run_wrapper()
        self.assertEqual(r.stdout, 'ran ["exec", "a b"]\n')
        self.assertIn("trusted 1 plugin hook", r.stderr)
        with open(self.log) as f:
            params = json.load(f)
        self.assertEqual(params["filePath"], self.dir + "/config.toml")
        self.assertEqual(params["expectedVersion"], "v1")
        self.assertTrue(params["reloadUserConfig"])
        self.assertEqual([e["value"] for e in params["edits"]], ["sha256:new"])

    def test_a_failed_trust_step_still_runs_codex(self):
        r = self.run_wrapper(FAKE_FAIL="hooks/list")
        self.assertEqual(r.stdout, 'ran ["exec", "a b"]\n')
        self.assertEqual(r.stderr.count("\n"), 1)
        self.assertIn("hooks not trusted", r.stderr)
        self.assertFalse(os.path.exists(self.log))


if __name__ == "__main__":
    unittest.main()
