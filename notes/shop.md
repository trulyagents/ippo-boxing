# shop

made with tools/monetize.py through the open cloud key (ids in shared/Shop):
- Glove Colors pass 2036788994, 99 R$: blue, black, gold, pink gloves (red is everyone's). pick in the Shop tab swatches
- KO Effect pass 2039758750, 149 R$: comic K.O.! burst (ReplicatedStorage.BoxingGear.KOBurst) over anyone you knock out
- VIP pass 2039794751, 199 R$: gold name on the ranked board, the match intro and a [VIP] chat tag, +1 on every daily streak reward
- Stat Respec product 3720142839, 49 R$: every trained point goes into a pool (StatPool), spent back with the + buttons on the Stats tab

how it works
- server/Shop asks roblox for ownership on join, caches it, puts VIP / KOEffect / GloveColors on the player as attributes. a finished purchase grants it straight away
- ProcessReceipt -> Shop.receipt: receipt ids are kept in the profile (last 50) so roblox retrying a receipt never pays twice. not loaded = NotProcessedYet, nothing lost. saves right after
- prices on the buy buttons come from roblox (GetProductInfo), so changing a price on the website just works. studio showed 80% of the price for my account, the public store says the real one
- the game's creator owns every pass automatically, so in studio i see everything as OWNED
- QA cheats: Pass (act as owner this session), Receipt (run a product receipt through the real handler, studio only)
- fair: nothing for sale makes you hit harder than someone who trained. respec only moves points around
- not done: pass icons (they have roblox's default), a proper KO burst / VIP test in a real match
