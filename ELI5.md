# ELI5 — the whole thing, small words

Start here. `TECHNICAL-MANUAL.md` is the how, `PHILOSOPHY-AND-CRITIQUE.md`
is the why and the what-went-wrong. This page is the story.

---

## The smoke alarm that says "fine"

You have a house with lots of rooms. In each room something might catch
fire. You have one smoke alarm, and it can say exactly two things:

- **"fine"**
- **"FIRE!"**

Here is the problem. The alarm can only smell **some** of the rooms.
There's a hallway it was never plugged into. And when you ask it about a
room down that hallway, it can't say *"I can't smell that room"* — because
that isn't one of its two words. So it says the closest thing it has.

It says **"fine."**

The room might be fine. The room might not exist. The room might be
burning. All three come out of the alarm as the same word. Three different
worlds, one word. Once that happens, nobody downstairs can ever tell them
apart again. The information is gone before anyone makes a decision.

**That's the whole idea.** Everything else is checking it carefully.

---

## The real thing this is about

`scheduler status` is a program that tells Zach how his projects are
doing. It only looks in one place on the computer (`$HOME`). Some projects
live somewhere else, under a different user account. It never looks there.
And it has no way to say "didn't look" — so those projects show up looking
healthy.

They might be healthy. Nobody knows. That's the point.

---

## So we built a toy world

Not a fix — a **toy**. Like a dollhouse version of the whole setup, made
of nothing but arithmetic. It has:

- **18 pretend projects**, some of which break on their own
- **A pretend alarm** that can only smell some of them
- **A pretend Zach**, who only has time to deal with 2 things per turn
- **A clock** that ticks 200 times

Then we ran it thousands of times to see what happens.

## And we built eleven different houses

Each house tries a different idea for fixing the alarm. Then we let all
eleven run side by side, in the exact same world, with the exact same
fires, and see which house catches the most.

The ideas came from three people who **disagree with each other on
purpose**:

| Who | What they'd say |
|---|---|
| **Ashby** (the cybernetics guy) | "Teach the alarm a third word: *dunno*." |
| **Perrow** (the disasters guy) | "More alarms make things WORSE. They break too, and then you're chasing ghosts. Just make the house burn slower." |
| **Hayek** (the economics guy) | "Stop trying to hear from far away. Let each room put out its own fire." |

We used three because if you only ask people who agree with you, you learn
nothing. We wanted the toy to be able to **prove us wrong**.

---

## The promise we made before looking

Here's the important bit, and it's the part people skip.

**Before** running anything, we wrote down what we expected — and, for
each guess, exactly what result would mean **"you were wrong."** Then we
locked it in a box. The box is a program (`prereg.py`) and it genuinely
refuses to let you change your guess later. It won't even accept a guess
unless you tell it how you could lose.

Why? Because otherwise you run the experiment, see the numbers, and go
"ah yes, that's what I meant all along." Everyone does this. It feels like
thinking. It isn't.

---

## What the toy said

**Guess 1: more alarms won't help.** ✅ Right, completely.

One alarm and four alarms got **exactly the same score**. Not close —
identical. Because all four alarms were plugged into the same hallway, so
all four miss the same rooms. Four alarms that are all blind in the same
place are just one alarm that costs four times as much.

> This is the useful one. Zach's ecosystem has a plan to add more alarms
> and compare their answers. It would not have helped. They'd all agree,
> and they'd all be wrong together.

**Guess 2: teaching it "dunno" will help a lot.** ✅ Right. Big.

Undetected trouble dropped by about 92%. We even tried it with the "dunno"
being mostly useless — the alarm says dunno and only 1 time in 5 does
anyone bother to go look — and it *still* beat the old alarm easily.

**Guess 3: extra alarms that can break are worse than none.** ✅ Right.

They cry wolf, Zach runs upstairs, nothing's burning, and now he trusts
the alarm less and has less time. Worse than having no extra alarms at all.

**Guess 4: making the house burn slower beats fixing the alarm.** ❌ Wrong.

This was the cleanest lesson of the night. Burning slower gives you more
time to react **to fires you noticed**. It does absolutely nothing about
fires you never noticed. Those are two different problems and we'd been
treating them as one.

**Guess 5: "each room fixes itself" beats a better alarm.** ❌ Mostly wrong
— but wrong in an interesting way.

Rooms fixing themselves won when there were **lots of little fires**, or
when Zach was **very busy**. The better alarm won when the problem was
that **rooms kept moving to the other hallway** — because a room can't
notice that *it* is the one that wandered off. Nobody guessed that. It's
the best thing we learned.

**Guess 6: do both.** ✅ Right, and it wasn't close.

Rooms fixing themselves *and* an alarm that says "dunno" was far better
than either alone.

---

## Now the part where I tell on myself

The toy ran all night and finished with no errors. Green lights all the
way. And it was **wrong in four different ways** that only showed up when
someone sat down and read the output by hand.

**1. I labelled the wrong house "the real one."**

The house I called "this is how things are today" had an alarm that,
when confused, screams **"FIRE!"** But the real `scheduler status` does the
opposite — when confused it says **"fine."**

I built the honest version as a side experiment and called it a tweak. It
was the real one the whole time. I didn't notice until I sat down to write
this. When you use the honest one, guess 2 stops being right *always* and
becomes right *most of the time, except in two specific situations*. Still
good! But "always" and "mostly" are different sentences, and I would have
said "always."

**2. I ran the same test five times and counted it as five tests.**

Same starting numbers every round, so I got the same answer five times.
The scoreboard said "50 wins!" It was ten wins, written down five times
each. I wrote that scoreboard.

**3. One of my measuring sticks was broken, and it read zero.**

There's a counter for "times the alarm said fine when it shouldn't have."
It read **0** for the entire night. Not because it never happened —
because in that house it was *impossible*, so the counter could never move.

A zero that means "never happened" and a zero that means "this can't be
measured" look identical.

**That is literally the exact bug this whole study is about.** The study
did it. To itself. In its own report. And I stared at it for two hours.

**4. One of my ten experiments didn't test anything.**

Changed a setting that has nothing to do with alarms. Ten percent of the
night, spent asking a question nobody had.

---

## The one sentence

Late in the night, comparing the two houses, this fell out:

> The house whose alarm **quietly says "fine" when it's confused** gets a
> **perfect score** on every number you'd put on a dashboard — zero false
> alarms, perfect trust, no wasted time — while missing 688 problems and
> telling 1,062 outright lies.

Everything you'd measure gets better. The house is on fire.

**A quiet broken sensor beats a loud working one on every chart.** So any
system judged by its dashboard will slowly, helpfully, teach its sensors
to shut up.

And — this matters — **we are not calling that a finding.** We never wrote
it in the box beforehand, so by our own rule it's just something we
noticed. It has to be guessed *first*, then tested, before it counts. The
rule only means something if it also binds you when you'd rather it
didn't.

---

## The moral

Every single mistake above was a **silence**. Nothing crashed. Nothing
turned red. Nothing complained.

- A counter that couldn't count → looked like good news
- A label nobody could see → looked like the real thing
- The same test five times → looked like a pile of evidence
- An experiment testing nothing → looked like work

**The scariest thing a machine can do is not break loudly. It's go quiet
and look fine.**

Which is what the study was about. Which is what the study did. At about
the rate the study predicted.

---

## What anyone should actually do with this

- Don't build the "add more alarms and compare notes" thing. Proven
  useless here.
- Do teach the alarm to say **"I couldn't check."** Cheapest change,
  biggest effect.
- Don't expect "make it fail more gently" to substitute for it. Different
  problem.
- **Make every zero say which zero it is** — "0 (didn't happen)" versus
  "0 (couldn't be measured)". Small code change. Probably the most
  valuable one on the list, and the study is the proof.
