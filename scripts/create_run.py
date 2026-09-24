#!/usr/bin/env python3
"""Open a release test run for a planned firmware version: a tracking issue plus one checklist sub-issue per feature."""

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / "features"
TESTS_REPO = "gaggimate/release-tests"
FIRMWARE_REPO = "jniebuhr/gaggimate"
PROJECT_TITLE = "Release Tests"
# Scenarios left out of the checklists: nightly-only behaviour, and checks that need the published release.
EXCLUDED_TAGS = {"@nightly", "@post-release"}

# Label name -> (colour, description); per-release and per-area labels are added at runtime.
BASE_LABELS = {
    "run": ("0e8a16", "Tracking issue for one release candidate"),
    "checklist": ("1d76db", "Checklist for one feature file"),
    "failure": ("d73a4a", "A failed release test"),
    "critical": ("b60205", "Contains or concerns @critical scenarios"),
}

TABLE_ROW = re.compile(r"^\|(.*)\|$")


@dataclass
class Scenario:
    name: str
    line: int
    tags: list
    outline: bool = False
    header: list = field(default_factory=list)
    rows: list = field(default_factory=list)

    def cases(self):
        return len(self.rows) if self.outline else 1


@dataclass
class Feature:
    path: Path
    name: str
    tags: list
    scenarios: list

    @property
    def area(self):
        return self.path.stem.split("_", 1)[1]

    def cases(self):
        return sum(s.cases() for s in self.scenarios)

    def critical_cases(self):
        return sum(s.cases() for s in self.scenarios if "@critical" in self.tags + s.tags)


def parse_feature(path):
    """Minimal Gherkin reader for the subset used in features/."""
    feature, pending_tags, scenarios = None, [], []
    current, in_examples = None, False
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@"):
            pending_tags += line.split()
            continue
        keyword, _, rest = line.partition(":")
        if keyword == "Feature":
            feature = Feature(path, rest.strip(), pending_tags, scenarios)
        elif keyword in ("Scenario", "Scenario Outline", "Example"):
            current = Scenario(rest.strip(), lineno, pending_tags, outline=keyword == "Scenario Outline")
            scenarios.append(current)
            in_examples = False
        elif keyword in ("Examples", "Scenarios"):
            in_examples = True
        elif keyword == "Background":
            current, in_examples = None, False
        elif in_examples and TABLE_ROW.match(line):
            cells = [c.strip() for c in TABLE_ROW.match(line).group(1).split("|")]
            if current.header:
                current.rows.append(dict(zip(current.header, cells)))
            else:
                current.header = cells
            continue
        else:
            continue
        pending_tags = []
    if feature is None:
        sys.exit(f"{path}: no Feature found")
    return feature


def load_features():
    return [parse_feature(p) for p in sorted(FEATURES_DIR.glob("*.feature"))]


def select(features, keep):
    """Copies of the features holding only the scenarios for which keep(all_tags) is true."""
    out = []
    for f in features:
        scenarios = [s for s in f.scenarios if keep(set(f.tags + s.tags))]
        if scenarios:
            out.append(Feature(f.path, f.name, f.tags, scenarios))
    return out


def plural(n, word):
    return f"{n} {word}{'' if n == 1 else 's'}"


def fmt_tags(tags):
    return " ".join(f"`{t}`" for t in tags)


def source_link(ref, path, line=None):
    url = f"https://github.com/{TESTS_REPO}/blob/{ref}/{path.relative_to(REPO_ROOT).as_posix()}"
    return f"{url}#L{line}" if line else url


def checklist_lines(feature, ref):
    out = []
    for s in feature.scenarios:
        head = f"{s.name} {fmt_tags(s.tags)}".strip() + f" · [source]({source_link(ref, feature.path, s.line)})"
        if not s.outline:
            out.append(f"- [ ] {head}")
            continue
        out.append(f"- **{head}**")
        out += [f"  - [ ] {' · '.join(f'{k}: {v}' for k, v in row.items() if v)}" for row in s.rows]
    return out


def checklist_body(ctx, feature):
    return "\n".join([
        f"Release **{ctx['version']}**, firmware [`{ctx['sha'][:7]}`]({ctx['commit_url']}), "
        f"feature [{feature.path.name}]({source_link(ctx['tests_ref'], feature.path)}).",
        "",
        f"{plural(feature.cases(), 'test case')}, {feature.critical_cases()} critical. "
        f"Feature tags: {fmt_tags(feature.tags) or 'none'}.",
        "",
        "Tick a box when it passes. For a failure, open a **Release test failure** issue and append ` → #N` to the line.",
        "Write `skipped: <reason>` after rows you have no hardware for.",
        "",
        *checklist_lines(feature, ctx["tests_ref"]),
    ]) + "\n"


def run_body(ctx, features, post_release):
    total = sum(f.cases() for f in features)
    critical = sum(f.critical_cases() for f in features)
    rows = "\n".join(f"| {f.path.name} | {f.name} | {f.cases()} | {f.critical_cases()} |" for f in features)
    pr = f"PR #{ctx['pr']} ({ctx['pr_url']}), flashed with its preview in the web installer" if ctx["pr"] else \
        f"**no open PR has this commit as its head**; open one (e.g. a draft PR from master into a branch at {ctx['last_tag']}) so " \
        f"`pr-flash.yml` builds a flashable image"
    nightly = "the nightly release is this commit" if ctx["nightly_sha"] == ctx["sha"] else \
        f"**the nightly release is at `{(ctx['nightly_sha'] or 'unknown')[:7]}`, not this commit.** " \
        f"Wait for `build-nightly.yml` on master, and do not merge anything else until the run is closed"
    previous = f"\nPrevious round for this version: #{ctx['previous_run']}.\n" if ctx["previous_run"] else ""
    post = "\n".join(line for f in post_release for line in checklist_lines(f, ctx["tests_ref"])) or "(no @post-release scenarios)"
    return f"""Release test run for **{ctx['version']}** on firmware [`{ctx['sha'][:7]}`]({ctx['commit_url']}) \
([changes since {ctx['last_tag']}]({ctx['compare_url']})). Scenarios from [{TESTS_REPO}@`{ctx['tests_ref'][:7]}`]\
(https://github.com/{TESTS_REPO}/tree/{ctx['tests_ref']}/features).
{previous}
> [!CAUTION]
> Publishing {ctx['version']} ships it to every user. Do not publish until the checklists below are done.

**{plural(total, 'test case')}**, **{critical}** critical, in {plural(len(features), 'checklist')} (sub-issues below).

### Builds under test
The {ctx['version']} binary is only built when the version is published. Both builds below are this exact commit.
- **USB flashing, functional and hardware tests:** {pr}. Same build flags as {ctx['version']}.
- **OTA and upgrade tests:** nightly channel; {nightly}. It differs from {ctx['version']} only by `NIGHTLY_BUILD`.
- Check the System tab: the version must end in `-g{ctx['sha'][:7]}` (the hash may be longer).

### How to run
1. Follow the minimum release pass in the [README](https://github.com/{TESTS_REPO}#minimum-release-pass).
2. Work through the sub-issues; close each one when every box is ticked or marked skipped.
3. Failures: open a **Release test failure** issue here. If it is a product bug, also file it on
   [{FIRMWARE_REPO}](https://github.com/{FIRMWARE_REPO}/issues) with the `release-test` label and link both ways.
4. If a fix lands, start a new round on the new commit with `scripts/create_run.py {ctx['version']}` and close this one.
5. When every `@critical` box is ticked and product bugs are fixed or accepted, commit `{ctx['sha'][:7]}` is
   cleared for release as {ctx['version']}. Publishing happens outside this workflow.
6. Once {ctx['version']} is published, run the after-release checks below, then close this issue.

### Hardware under test
| Role | Hardware | Firmware before | Tester |
|---|---|---|---|
| Reference rig display | | | |
| Reference rig controller | | | |
| Scale(s) | | | |
| Other displays | | | |
| Other controllers | | | |

### Checklists
| Feature file | Area | Cases | Critical |
|---|---|---|---|
{rows}

### After release
{post}
"""


class GitHub:
    def api(self, path, method="GET", payload=None, check=True):
        cmd = ["gh", "api", "-X", method, path]
        if payload is not None:
            cmd += ["--input", "-"]
        proc = subprocess.run(cmd, input=json.dumps(payload) if payload is not None else None,
                              capture_output=True, text=True)
        if proc.returncode != 0:
            if check:
                sys.exit(f"gh api {method} {path} failed: {proc.stderr.strip() or proc.stdout.strip()}")
            return None
        return json.loads(proc.stdout) if proc.stdout.strip() else None

    def graphql(self, query, **variables):
        cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
        for k, v in variables.items():
            cmd += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
        return json.loads(proc.stdout)["data"]

    def ensure_labels(self, repo, labels):
        existing = {l["name"] for l in self.api(f"repos/{repo}/labels?per_page=100")}
        for name, (color, desc) in labels.items():
            if name not in existing:
                self.api(f"repos/{repo}/labels", "POST", {"name": name, "color": color, "description": desc})


class Project:
    """Adds issues to the org's "Release Tests" board and fills its Release/Area/Kind fields."""

    FIELDS_QUERY = """query($org:String!,$number:Int!){organization(login:$org){projectV2(number:$number){id
      fields(first:50){nodes{... on ProjectV2Field{id name dataType}
      ... on ProjectV2SingleSelectField{id name options{id name}}}}}}}"""

    def __init__(self, gh, org, number):
        self.gh = gh
        data = gh.graphql(self.FIELDS_QUERY, org=org, number=number)["organization"]["projectV2"]
        self.id = data["id"]
        self.fields = {f["name"]: f for f in data["fields"]["nodes"] if f}

    @staticmethod
    def find_number(gh, org):
        query = """query($org:String!){organization(login:$org){projectsV2(first:50){nodes{number title}}}}"""
        for p in gh.graphql(query, org=org)["organization"]["projectsV2"]["nodes"]:
            if p["title"] == PROJECT_TITLE:
                return p["number"]
        return None

    def add(self, node_id, release, kind, area):
        item = self.gh.graphql(
            """mutation($p:ID!,$c:ID!){addProjectV2ItemById(input:{projectId:$p,contentId:$c}){item{id}}}""",
            p=self.id, c=node_id)["addProjectV2ItemById"]["item"]["id"]
        self._set_text(item, "Release", release)
        self._set_text(item, "Area", area)
        self._set_option(item, "Kind", kind)

    def _set_text(self, item, name, value):
        f = self.fields.get(name)
        if f and value:
            self.gh.graphql("""mutation($p:ID!,$i:ID!,$f:ID!,$v:String!){updateProjectV2ItemFieldValue(
                input:{projectId:$p,itemId:$i,fieldId:$f,value:{text:$v}}){projectV2Item{id}}}""",
                            p=self.id, i=item, f=f["id"], v=value)

    def _set_option(self, item, name, value):
        f = self.fields.get(name)
        option = next((o["id"] for o in (f or {}).get("options", []) if o["name"] == value), None)
        if option:
            self.gh.graphql("""mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue(
                input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}""",
                            p=self.id, i=item, f=f["id"], o=option)


def setup_project(gh):
    """Create the org's "Release Tests" board with Release/Area/Kind fields, linked to the tests repo."""
    org, name = TESTS_REPO.split("/")
    if Project.find_number(gh, org):
        sys.exit(f"project '{PROJECT_TITLE}' already exists in {org}")
    ids = gh.graphql("""query($org:String!,$name:String!){organization(login:$org){id}
        repository(owner:$org,name:$name){id}}""", org=org, name=name)
    project = gh.graphql("""mutation($o:ID!,$r:ID!,$t:String!){createProjectV2(
        input:{ownerId:$o,repositoryId:$r,title:$t}){projectV2{id number url}}}""",
                         o=ids["organization"]["id"], r=ids["repository"]["id"], t=PROJECT_TITLE)
    project = project["createProjectV2"]["projectV2"]
    for field_name in ("Release", "Area"):
        gh.graphql("""mutation($p:ID!,$n:String!){createProjectV2Field(
            input:{projectId:$p,dataType:TEXT,name:$n}){projectV2Field{... on ProjectV2Field{id}}}}""",
                   p=project["id"], n=field_name)
    gh.graphql("""mutation($p:ID!){createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:"Kind",
        singleSelectOptions:[{name:"Run",color:GREEN,description:"Tracking issue"},
        {name:"Checklist",color:BLUE,description:"Feature checklist"},
        {name:"Failure",color:RED,description:"Failed test"}]}){projectV2Field{... on ProjectV2SingleSelectField{id}}}}""",
               p=project["id"])
    print(f"created {project['url']} (number {project['number']})")


def tests_ref():
    git = lambda *a: subprocess.run(["git", *a], cwd=REPO_ROOT, capture_output=True, text=True).stdout.strip()
    sha = git("rev-parse", "HEAD")
    if not git("branch", "-r", "--contains", sha):
        print(f"warning: {TESTS_REPO} commit {sha[:7]} is not pushed; source links will 404", file=sys.stderr)
    if git("status", "--porcelain", "--", "features"):
        print("warning: features/ has uncommitted changes; checklists use them but link to HEAD", file=sys.stderr)
    return sha


def firmware_context(gh, version, ref, pr_override):
    """Resolve the commit under test and its builds; refuse a version that is already released (read-only check)."""
    if gh.api(f"repos/{FIRMWARE_REPO}/git/ref/tags/{version}", check=False):
        sys.exit(f"{version} is already released on {FIRMWARE_REPO}; plan a new version number")
    commit = gh.api(f"repos/{FIRMWARE_REPO}/commits/{ref}")
    sha = commit["sha"]
    last_tag = (gh.api(f"repos/{FIRMWARE_REPO}/releases/latest", check=False) or {}).get("tag_name", "")
    pr = gh.api(f"repos/{FIRMWARE_REPO}/pulls/{pr_override}") if pr_override else next(
        (p for p in gh.api(f"repos/{FIRMWARE_REPO}/commits/{sha}/pulls") or []
         if p["state"] == "open" and p["head"]["sha"] == sha), None)
    nightly = gh.api(f"repos/{FIRMWARE_REPO}/commits/nightly", check=False)
    return {
        "version": version,
        "sha": sha,
        "commit_url": commit["html_url"],
        "last_tag": last_tag or "the last release",
        "compare_url": f"https://github.com/{FIRMWARE_REPO}/compare/{last_tag}...{sha}",
        "pr": pr["number"] if pr else None,
        "pr_url": pr["html_url"] if pr else None,
        "nightly_sha": nightly["sha"] if nightly else None,
        "previous_run": None,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("version", nargs="?", help="planned firmware version, e.g. v1.9.0")
    ap.add_argument("--firmware", default="master", help=f"{FIRMWARE_REPO} branch or commit to test (default master)")
    ap.add_argument("--pr", type=int, help="PR whose flash preview is the USB build (default: open PR with this head)")
    ap.add_argument("--tags", help="only include scenarios with any of these tags, e.g. @smoke,@critical")
    ap.add_argument("--no-project", action="store_true", help="do not add issues to the Projects board")
    ap.add_argument("--dry-run", action="store_true", help="print the issue bodies instead of creating issues")
    ap.add_argument("--setup-project", action="store_true", help=f"one-time: create the '{PROJECT_TITLE}' board")
    args = ap.parse_args()

    gh = GitHub()
    if args.setup_project:
        setup_project(gh)
        return
    if not args.version or not re.fullmatch(r"v\d+\.\d+\.\d+", args.version):
        ap.error("version is required and must look like v1.9.0")

    tag_filter = {t if t.startswith("@") else f"@{t}" for t in args.tags.split(",")} if args.tags else set()
    features = load_features()
    checklists = select(features, lambda t: not t & EXCLUDED_TAGS and (not tag_filter or t & tag_filter))
    post_release = select(features, lambda t: "@post-release" in t)
    ctx = firmware_context(gh, args.version, args.firmware, args.pr)
    ctx["tests_ref"] = tests_ref()
    release_label = f"release:{args.version}"
    runs = gh.api(f"repos/{TESTS_REPO}/issues?state=all&labels=run,{release_label}&per_page=50", check=False) or []
    if any(ctx["sha"][:7] in r["title"] for r in runs):
        sys.exit(f"a run for {args.version} on {ctx['sha'][:7]} already exists: "
                 f"{next(r for r in runs if ctx['sha'][:7] in r['title'])['html_url']}")
    ctx["previous_run"] = runs[0]["number"] if runs else None
    title = f"Release test: {args.version} · firmware {ctx['sha'][:7]}" + \
        (f" ({', '.join(sorted(tag_filter))})" if tag_filter else "")

    if args.dry_run:
        print(f"# {title}\n\n{run_body(ctx, checklists, post_release)}")
        for f in checklists:
            print(f"\n# [{args.version}] {f.path.stem}: {f.name}\n\n{checklist_body(ctx, f)}")
        return

    labels = dict(BASE_LABELS)
    labels[release_label] = ("5319e7", f"Release test runs for {args.version}")
    for f in checklists:
        labels[f"area:{f.area}"] = ("c5def5", f"Scenarios from {f.path.name}")
    gh.ensure_labels(TESTS_REPO, labels)

    project = None
    if not args.no_project:
        org = TESTS_REPO.split("/")[0]
        try:
            number = Project.find_number(gh, org)
            project = Project(gh, org, number) if number else None
            if project is None:
                print(f"warning: no project '{PROJECT_TITLE}' in {org}; run --setup-project once", file=sys.stderr)
        except RuntimeError as e:
            print(f"warning: Projects board unavailable ({e.args[0].splitlines()[0]}); "
                  "run `gh auth refresh -s project`", file=sys.stderr)

    critical = ["critical"] if any(f.critical_cases() for f in checklists) else []
    run = gh.api(f"repos/{TESTS_REPO}/issues", "POST",
                 {"title": title, "body": run_body(ctx, checklists, post_release), "labels": ["run", release_label] + critical})
    print(f"run: {run['html_url']}")
    if project:
        project.add(run["node_id"], args.version, "Run", "")
    for f in checklists:
        f_labels = ["checklist", release_label, f"area:{f.area}"] + (["critical"] if f.critical_cases() else [])
        issue = gh.api(f"repos/{TESTS_REPO}/issues", "POST",
                       {"title": f"[{args.version}] {f.path.stem}: {f.name}", "body": checklist_body(ctx, f),
                        "labels": f_labels})
        gh.api(f"repos/{TESTS_REPO}/issues/{run['number']}/sub_issues", "POST", {"sub_issue_id": issue["id"]})
        if project:
            project.add(issue["node_id"], args.version, "Checklist", f.area)
        print(f"  {f.path.name}: {issue['html_url']} ({plural(f.cases(), 'case')})")
    for w in ([] if ctx["pr"] else ["no open PR has this commit as head; open one for the USB build"]) + \
            ([] if ctx["nightly_sha"] == ctx["sha"] else ["the nightly release is not this commit yet"]):
        print(f"warning: {w}", file=sys.stderr)


if __name__ == "__main__":
    main()
