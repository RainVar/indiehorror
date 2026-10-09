# First-time playtest and release gates

Give the packaged build to at least two independent players: one Filipino player who can review the dialogue/details, and one person comfortable narrating while playing. Do not explain the puzzle solutions beforehand.

Record only with each tester's consent. A written observation log is enough; microphone gameplay itself does not record anything.

## Observe

- Can they start, understand E/interactions, find the fuse, and read the first note unaided?
- How long does the full first run take? Record actual time, including reading and retries.
- Which instructions or room routes cause more than 90 seconds of confusion?
- Do they understand that red light means listening and that walking/crouching changes noise?
- Can they recover from a hunt without a full restart? Is the phone distraction discoverable?
- Does microphone mode respond fairly to their voice and room noise with headphones?
- Are there frightening or funny moments they would naturally share? Do not equate automation passing with fun or virality.
- Are the Filipino/Taglish writing, furniture and rituals read as intentional fiction rather than an inaccurate claim about a real tradition?
- Do they understand the early rice/cassette commitment, find both staircases, and want to replay the other route?
- Can they find and traverse the crawlspace, solve its binding order, and understand the radio-lure escape?
- Do the candle trials, scare spacing and ending cutscenes feel paced well?

## Physical device check

Use a real Android 10+ phone with 4 GB RAM. Test the exported itch.io iframe in Chrome, not only a desktop viewport emulation. Record model, Android/browser version, temperature after 15 minutes, quality preset, frame rate, startup time, controls and audio behavior. Aim for a stable 30 FPS at low quality. Do not claim this target is verified from emulation.

## Before public release

- Both independent playtests are complete and major feedback is addressed.
- Physical Android browser test is complete before advertising Mobile Friendly.
- Embedded itch.io startup, resizing, audio unlock, persistence, microphone fallback and both endings pass.
- Windows release archive is tested from a clean extracted folder; source/debug tools are absent.
- Story text and credits receive a final human review.
- Screenshots and page copy reflect the actual build. No claimed awards, endorsements, player counts or guaranteed virality.
- Revenue model and seller/payment setup are chosen separately. Do not publish payment credentials or signing keys in the repo.

Native Android, iOS, Linux/macOS downloads, full voice acting, gamepad support and paid-edition content are outside this initial release candidate.
