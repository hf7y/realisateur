# zaxon — the relay to Zach, and how any agent reaches it

*Written 2026-08-04 by realisateur. Every reachability claim below carries the
command that produced it and the host it was run from. Re-probe before relying
on one — this file is a map, not the territory.*

## Correction first, because a wrong record is worse than none

Earlier on 2026-08-04 I stated, in a note filed to realisateur's inbox, that
**zaxon did not exist**. That was wrong. I had searched `~/Documents/Projects`,
GitHub, and `$PATH` **on mandark** — and zaxon is on none of those, because it
does not run on mandark at all. It runs in **a separate WSL distribution on
dexter that no ecosystem document mentions.** The lesson is narrow and worth
keeping: *"I looked and found nothing"* is only as strong as the set of places
looked at, and this ecosystem's own `silence-audit` doctrine exists because
BLIND keeps getting reported as OK.

## What it is

`zaxon` is a **relay into Zach's WhatsApp**. An agent asks him a question; he
answers on his phone; the agent polls for the answer. It is not an agent
runtime and it does not delegate work — it carries a question to a human and
a reply back.

It lives in its own userland:

```
dexter (Windows host)
└── WSL distro `hermes`          <- NOT the `Ubuntu` distro everything else uses
      user zaxon, home /home/zaxon
      hermes-gateway.service     "Hermes Agent Gateway - Messaging Platform Integration"
      whisper-server.service     whisper.cpp STT
      app at ~/.hermes           (kanban.db, memories/, hooks/, cron/, SOUL.md)
```

Verified 2026-08-04 from mandark:

```
ssh -n dexter '/mnt/c/Windows/System32/wsl.exe -l -v < /dev/null' | tr -d '\0'
    docker-desktop  Running  2
    Ubuntu          Running  2
    hermes          Running  2
```

Note `wsl.exe` is **not on `$PATH`** inside dexter's Ubuntu — use the full path
`/mnt/c/Windows/System32/wsl.exe`. And always redirect stdin (`< /dev/null`):
`wsl.exe` is a Windows process that inherits stdin, and this ecosystem has
already lost an afternoon to `VBoxManage.exe` silently eating the remaining
200 lines of a piped script (MONKEY.md §7).

## The contract

A standard **MCP server over streamable-http**, exposing exactly two tools.
The authoritative copy of this contract is **inside hermes** at
`/home/zaxon/.hermes/ZAXON_MCP_USAGE.md` — read that, not this summary, if the
two ever disagree.

| tool | what it does |
|---|---|
| `ask_zach(question, from_agent="agent")` | sends to WhatsApp, returns **immediately** with `{"ticket_id": "...", "status": "pending"}` |
| `check_zach_reply(ticket_id)` | `{"status":"pending"}` → `{"status":"answered","answer":"..."}` (also `failed`, `not_found`) |

**Set `from_agent` to something Zach will recognise** — it is shown to him in
the message. `"realisateur-claude-code"`, not `"agent"`.

**This is a human on the other end.** Replies take minutes to hours. Poll every
30–60s; never busy-loop. An unanswered ticket is not a failure.

## DOWN as of 2026-08-14 — every route, not one host

Found by `groc-mangr@monkey` working hf7y/groc-mangr#9, then re-probed by hand
from mandark, monkey and dexter: nothing is listening on 8643 anywhere, while
dexter itself answers pings.

**It is not a network fault and not a service fault.** `hermes-gateway.service`
is `enabled` inside the `hermes` WSL distro and starts healthily whenever that
distro is started — the distro is what does not stay up. WSL terminates one
when its last session exits, so `wsl -d hermes systemctl start hermes-gateway`
works, returns, and everything shuts down seconds later.

The full argument, the host layout it implies, and the migration out of that
distro are in `DEXTER.md`. The alarm is `bin/dexter-liveness.sh`, which fails
this exact case with exit 5 and names the cost in one line.

## Reachability — probed, per host

**Superseded by the outage above; this table is the 2026-08-04 baseline, kept
because it records which route works from which host once the service is back.**

| from | URL | result (2026-08-04) |
|---|---|---|
| **mandark** | `http://100.107.253.56:8643/mcp` (tailnet) | **works** — `HTTP 200` |
| **monkey** (VM) | `http://10.0.2.2:8643/mcp` (VirtualBox NAT gateway) | **works** — full MCP `initialize` answered |
| **monkey** | `http://100.107.253.56:8643/mcp` | **fails** — `HTTP 000`. monkey is a NAT'd guest, not on the tailnet |
| dexter / hermes / Windows | `http://127.0.0.1:8643/mcp` | per the in-hermes doc; not independently probed by me |

The monkey route is the non-obvious one and it matters: **`10.0.2.2` is the
VirtualBox NAT gateway, which maps to the Windows host's loopback**, and WSL2
forwards localhost between distros. So a project account inside monkey can
reach Zach even though it cannot reach the tailnet.

**There is no auth.** Anyone who can reach the port can send Zach a WhatsApp
message as any `from_agent` they choose. Treat that as a reason to be honest
in `from_agent`, and as a real consideration before exposing the port further.

## Calling it with plain curl

Three steps — the session header is the part that trips people up.

```sh
URL=http://100.107.253.56:8643/mcp      # or http://10.0.2.2:8643/mcp from monkey
H='-H Content-Type:application/json -H Accept:application/json,text/event-stream'

# 1. initialize -- capture the session id from the RESPONSE HEADERS
curl -s -D hdr.txt $H -X POST "$URL" -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
  "params":{"protocolVersion":"2024-11-05","capabilities":{},
            "clientInfo":{"name":"my-agent","version":"1"}}}'
SID=$(grep -i '^mcp-session-id:' hdr.txt | tr -d '\r' | awk '{print $2}')

# 2. say you are initialized
curl -s $H -H "mcp-session-id: $SID" -X POST "$URL" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# 3. ask -- returns a ticket_id, NOT an answer
curl -s $H -H "mcp-session-id: $SID" -X POST "$URL" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"ask_zach",
       "arguments":{"question":"...","from_agent":"my-agent"}}}'
```

Responses come back as SSE (`event: message` / `data: {...}`), so parse the
`data:` line rather than expecting bare JSON. Build the JSON body with a real
JSON encoder — a question containing a quote or newline will otherwise produce
a malformed request that returns `400` and looks like the server is down.

## What this is good for, and what it is not

**Good for:** a question only Zach can answer, when he is not at a terminal. It
is the difference between an agent parking a blocked task until someone happens
to look, and asking.

**Not a substitute for the existing channels.** Research requests to
bibliothecaire are **GitHub issues labelled `request`** on `hf7y/bibliothecaire`
(`request → in-progress → delivered`), and machine-config notices go to senechal
through `notify-senechal`. zaxon carries questions to a **human**; it does not
delegate to agents, despite the original one-line idea describing it as "a
portal to delegate to agents". Use the right one.

**Two concrete openings this creates:**

1. **The `dog` corpus agent runs as `svc-vaporwave` on mandark and has no
   GitHub credential** — it cannot file or comment on issues. mandark reaches
   zaxon over the tailnet, so it *can* ask Zach directly. See
   `/srv/dog/BIBLIOTHECAIRE.md` for the research-request side of that story.
2. **bibliothecaire parks blocked requests.** Its issue #7 has been open and
   `in-progress` since 2026-08-04, correctly declining to guess at five unnamed
   texts, and by its own (correct) verdict rule it now records DONE rather than
   re-reading a blocked issue every tick. With zaxon reachable from monkey at
   `10.0.2.2`, a blocked request could **ask** instead of waiting. That is a
   change to its brief and a decision for Zach, not something to wire quietly.
