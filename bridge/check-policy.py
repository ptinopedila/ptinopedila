"""Compare both compiled policies, including conditional rules and role memberships."""
import hashlib
import sys

import setools

TYPE = "systemd_clonesetup_generator_exec_t"
FILE_PERMS = {"getattr", "link", "open", "read", "relabelto", "rename", "setattr"}


def rule_text(rule):
    try:
        return f"{rule} [{rule.conditional}] {rule.conditional_block}"
    except (AttributeError, setools.exception.RuleNotConditional):
        return str(rule)


def summary(values):
    rows = sorted(values)
    return len(rows), hashlib.sha256("\n".join(rows).encode()).hexdigest()


def inspect(policy, bridge):
    types = list(policy.types())
    added = {}
    old_rules = []
    for rule in policy.terules():
        if TYPE not in (str(rule.source), str(rule.target)):
            old_rules.append(rule_text(rule))
            continue
        assert str(rule.ruletype) == "allow"
        assert rule_text(rule) == str(rule), "unexpected conditional permission"
        key = (str(rule.source), str(rule.target), str(rule.tclass))
        assert key not in added
        added[key] = set(rule.perms)

    expected = {
        ("initrc_t", TYPE, "file"): FILE_PERMS,
        (TYPE, "fs_t", "filesystem"): {"associate"},
    }
    assert added == (expected if bridge else {}), added
    new = [t for t in types if str(t) == TYPE]
    assert len(new) == int(bridge)
    if bridge:
        assert not new[0].ispermissive and not list(new[0].aliases())
        assert not list(new[0].attributes())
        # The policy compiler can omit object_r from the explicit role map.
        assert all(str(r) == "object_r" for r in policy.roles() if TYPE in map(str, r.types()))

    return {
        "existing types and their aliases": summary(
            f"{t}:{','.join(sorted(map(str, t.aliases())))}" for t in types if str(t) != TYPE
        ),
        "permissive domains": summary(str(t) for t in types if t.ispermissive),
        "attribute members": summary(
            f"{a}:{','.join(sorted(map(str, a.expand())))}" for a in policy.typeattributes()
        ),
        "role members": summary(
            f"{r}:{','.join(sorted(str(t) for t in r.types() if str(t) != TYPE))}"
            for r in policy.roles()
        ),
        "existing type enforcement rules": summary(old_rules),
        "role rules": summary(map(str, policy.rbacrules())),
        "MLS rules": summary(map(str, policy.mlsrules())),
        "constraints": summary(map(str, policy.constraints())),
        "booleans": summary(f"{b}={b.state}" for b in policy.bools()),
    }


if __name__ == "__main__":
    original, candidate = map(setools.SELinuxPolicy, sys.argv[1:])
    before = inspect(original, False)
    after = inspect(candidate, True)
    for field, value in before.items():
        assert value == after[field], f"changed {field}"
        print(f"{value[0]} {field} preserved")
