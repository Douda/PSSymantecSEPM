# Deep Modules

> **PS Sidebar**: In PowerShell modules, depth means few exported cmdlets with rich parameter sets, backed by many Private functions that handle the complexity. `Get-SEPComputers` is deep — one cmdlet, multiple parameters, handles pagination, filtering, and type decoration — all hidden from the caller. The user calls one command and gets objects. That's the goal.

---

From "A Philosophy of Software Design":

**Deep module** = small interface + lots of implementation

```
┌──────────────────────────────────────┐
│   Small Interface (public cmdlets)   │  ← Few exported commands, simple params
├──────────────────────────────────────┤
│                                      │
│                                      │
│  Deep Implementation (Private/)      │  ← Complex logic hidden from caller
│                                      │
│                                      │
└──────────────────────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid)

```
┌──────────────────────────────────────────────┐
│  Large Interface (many exported cmdlets)     │  ← One-off wrappers, thin
├──────────────────────────────────────────────┤
│  Thin Implementation                         │  ← Just passes through
└──────────────────────────────────────────────┘
```

When designing cmdlets, ask:

- Can I reduce the number of exported commands? (Combine 3 thin `Get-` cmdlets into one with parameter sets?)
- Can I simplify the parameters? (Parameter sets instead of 15 optional switches?)
- Can I hide more complexity inside Private functions?

> **PS Sidebar**: A shallow PowerShell module exposes one cmdlet per API endpoint, each ~15 lines, all copying the same `begin` block. A deep module has fewer cmdlets but each does more. The `begin` block is extracted; pagination is handled; PSTypeNames are decorated. The Private/ folder is where the real code lives — the Public/ folder is just the interface.
