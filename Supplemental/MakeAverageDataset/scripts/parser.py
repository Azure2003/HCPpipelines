#!/usr/bin/env python3
import re
import sys
import json
import itertools


# ============================================================
# AST NODE
# ============================================================

def node(t, name=None):
    return {
        "type": t,
        "name": name,
        "attrs": {},
        "children": []
    }


def strip(s):
    return s.strip()


def is_block_start(line):
    return re.match(r"^([A-Za-z0-9_\-]+)\s*\{$", line)


def is_block_end(line):
    return line == "}"


def is_kv(line):
    return re.match(r"^[A-Za-z0-9_\-]+\s*=\s*.+$", line)


def parse_kv(line):
    k, v = line.split("=", 1)
    return k.strip(), v.strip()


# ============================================================
# PARSER (AST ONLY)
# ============================================================

def parse(path):
    root = node("root")
    stack = [root]
    globals_ = {}
    subject_mode = False

    with open(path) as f:
        for raw in f:
            line = strip(raw)

            if not line or line.startswith("#"):
                continue

            # -------------------------
            # BLOCK START
            # -------------------------
            m = is_block_start(line)
            if m:
                name = m.group(1)
                current = stack[-1]

                # subject block inside job or label
                if name == "subject" and current["type"] in ("job", "label"):
                    subject_mode = True
                    current["attrs"]["subject"] = {}
                    continue
                if name == "subject" and current["type"] == "root":
                    subject_mode = True
                    globals_["subject"] = {}
                    continue

                n = node(name, name)
                current["children"].append(n)
                stack.append(n)
                continue

            # -------------------------
            # BLOCK END
            # -------------------------
            if is_block_end(line):
                if subject_mode:
                    subject_mode = False
                    continue

                if len(stack) > 1:
                    stack.pop()
                continue

            # -------------------------
            # KEY = VALUE
            # -------------------------
            if not is_kv(line):
                continue
            k, v = parse_kv(line)
            if subject_mode:
                current = stack[-1]
                if current["type"] == "root":
                    globals_["subject"][k] = v
                else:
                    current["attrs"]["subject"][k] = v
                continue
            current = stack[-1]
            if current["type"] == "root":
                globals_[k] = v
                continue
            current["attrs"][k] = v

    root["globals"] = globals_
    return root


# ============================================================
# PASS 2 — Resolve context nodes
# ============================================================

def resolve_template(template, variables):
    """
    Given a template string like "/data/{file}/something"
    and variables like {"file": ["wmparc", "wmparc_1.25"]},
    return all cartesian combinations joined with @.
    """
    slots = re.findall(r"\{(\w+)\}", template)
    relevant = {s: variables[s] for s in slots if s in variables}

    if not relevant:
        return template

    keys = list(relevant.keys())
    values = [relevant[k] for k in keys]

    results = []
    for combo in itertools.product(*values):
        filled = template
        for k, v in zip(keys, combo):
            filled = filled.replace(f"{{{k}}}", v)
        results.append(filled)

    return "@".join(results)


def pass2(ast):
    """
    Resolve context nodes inside any direct child of root.
    - Variable scope: globals < subject block < label attrs
    - Excluding 'subjects' from interpolation variables
    """
    globals_ = ast.get("globals", {})

    for parent in ast["children"]:
        label_subject = parent["attrs"].get("subject") or globals_.get("subject", {})
        subject_vars = {k: [v] for k, v in label_subject.items()} if isinstance(label_subject, dict) else {}

        variables = {
            k: v.split("@")
            for k, v in {**globals_, **parent["attrs"]}.items()
            if k != "subjects" and not (k == "subject" and isinstance(v, dict))
        }
        variables = {**variables, **subject_vars}

        for child in parent["children"]:
            if child["type"] != "context":
                continue

            for attr_key, attr_val in child["attrs"].items():
                child["attrs"][attr_key] = resolve_template(attr_val, variables)

    return ast


# ============================================================
# PASS 3 — Expand jobs
# ============================================================

def resolve_single(template, binding):
    """Replace all {var} slots in template with a single binding dict (no expansion)."""
    result = template
    for k, v in binding.items():
        result = result.replace(f"{{{k}}}", v)
    return result


def pass3(ast):
    globals_ = ast.get("globals", {})
    emitted_jobs = []

    for parent in ast["children"]:
        # Pull subject block from label level if present
        label_subject = parent["attrs"].get("subject", {})
        subject_vars = {k: [v] for k, v in label_subject.items()} if isinstance(label_subject, dict) else {}

        # Build variable scope: globals < subject block < label attrs, exclude subjects
        variables = {
            k: v.split("@")
            for k, v in {**globals_, **parent["attrs"]}.items()
            if k != "subjects" and not (k == "subject" and isinstance(v, dict))
        }
        variables = {**variables, **subject_vars}

        subjects = parent["attrs"].get("subjects", "").split("@")

        # Pull context attrs to merge into each job
        context_attrs = next(
            (c["attrs"] for c in parent["children"] if c["type"] == "context"),
            {}
        )

        for child in parent["children"]:
            if child["type"] != "job":
                continue

            # subject block can come from job or fall back to label
# subject block can come from job, label, or globals
            subject_block = (
                child["attrs"].get("subject")
                or parent["attrs"].get("subject")
                or globals_.get("subject")
            )
            has_subject_block = isinstance(subject_block, dict) and len(subject_block) > 0

            # Flatten: context attrs + job string attrs (skip subject{} block)
            merged_attrs = {
                **context_attrs,
                **{
                    k: v for k, v in child["attrs"].items()
                    if not (k == "subject" and isinstance(v, dict))
                }
            }

            # Find all {var} slots across merged attrs, excluding {subject}
            all_slots = set()
            for val in merged_attrs.values():
                for slot in re.findall(r"\{(\w+)\}", val):
                    if slot != "subject":
                        all_slots.add(slot)

            # Build expansion axes for non-subject vars
            axes_keys = [s for s in all_slots if s in variables]
            axes_vals = [variables[k] for k in axes_keys]

            combos = list(itertools.product(*axes_vals)) if axes_keys else [()]

            for combo in combos:
                binding = dict(zip(axes_keys, combo))

                resolved = {
                    k: resolve_single(v, binding)
                    for k, v in merged_attrs.items()
                }

                if has_subject_block:
                    # Get subject block from job or fall back to label
                    resolved["subject"] = subject_block
                else:
                    resolved = {
                        k: "@".join(
                            resolve_single(v, {**binding, "subject": s})
                            for s in subjects
                        ) if "{subject}" in v else v
                        for k, v in resolved.items()
                    }

                resolved["type"] = parent["type"]
                emitted_jobs.append(resolved)

    return emitted_jobs


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    ast = parse(sys.argv[1])
    print("=== AST ===", file=sys.stderr)
    print(json.dumps(ast, indent=2), file=sys.stderr)
    ast = pass2(ast)
    print("=== PASS 2 ===", file=sys.stderr)
    print(json.dumps(ast, indent=2), file=sys.stderr)
    jobs = pass3(ast)
    print("=== PASS 3 ===", file=sys.stderr)
    print(json.dumps(jobs, indent=2), file=sys.stderr)
    for job in jobs:
        for k, v in job.items():
            if k == "subject" and isinstance(v, dict):
                print(f"subject_pattern={v.get('pattern', '').strip(chr(34))}")
                print(f"subject_root={v.get('root', '')}")
            else:
                print(f"{k}={v}")
        print()