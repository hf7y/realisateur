"""Parallel clone: identical protocol, ONE structural tweak -- sensors fail
toward OK (silent) instead of toward ALARM. Tests whether pattern 14's
claim that fail-toward-alarm is the expensive direction is actually true."""
import os, supervisor
supervisor.MUTATIONS = [(f"failOK_{t}", dict(m, fail_toward_ok=True))
                        for t, m in supervisor.MUTATIONS]
supervisor.main()
