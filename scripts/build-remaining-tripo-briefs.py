"""Build production-only briefs; never mutate queue, manifest or credit ledgers."""
import collections
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def mapping(text):
    return dict(line.split('|', 1) for line in text.strip().splitlines())

SURVIVORS = mapping('''
buccaneer|Salvage pirate survivor, athletic torso, cropped asymmetric naval jacket, tricorn with one folded corner, diagonal coin bandolier, tall cuffed boots and short tied hair. A belt of empty mismatched holsters communicates rotating scavenged weapons.
builder|Broad construction foreman, square hardhat, heavy sleeveless padded vest, brick-shaped shoulder guard, carpenter apron and reinforced knees; a folded miniature turret frame attached flat to the backpack suggests structure building.
captain|Tall composed evacuation captain, peaked naval cap, double-breasted long coat split above the knees, chunky epaulettes, whistle and compact evacuation-beacon pack; upright commanding silhouette.
chef|Living food-court cook survivor, tall pleated toque, rolled sleeves, fitted double-breasted tunic, short flour-dusted apron, oven-mitt belt pouches and sturdy clogs; lean proportions distinct from the bloated enemy chef.
creature|Friendly infected survivor, compact pear-shaped humanoid, large rounded ears, segmented fungal brow, oversized padded hands, torn containment overalls and a single strapped sample canister; visibly mutated but alert and friendly.
curious|Wide-eyed mall antiques appraiser, short rounded coat, oversized round spectacles, magnifying lens folded against chest, asymmetrical specimen satchel and tiny closed curiosity boxes on belt; inquisitive forward-set head.
diver|Aquarium rescue diver, squat heavy rounded brass helmet with broad glass faceplate, thick rubber suit, weighted boots, compact twin air bottles and coiled hose secured to chest; joints exposed enough to bend.
druid|Atrium gardener survivor, slender silhouette, branching leaf-shaped hood, short layered bark-textured vest, seed pouch belt, vine-wrapped boots and a compact living sapling growing from backpack; no loose trailing vines.
dwarf|Short stocky salvage miner, very broad shoulders, braided beard, lamp helmet, thick leather mining vest, riveted knee guards and ore-sample belt; recognizable compressed proportions without a weapon.
gangster|Sharp-dressed mall racketeer, narrow fedora, broad pinstripe lapels without lettering, cropped waistcoat, oversized shoulder holster straps, pointed boots and one gold tooth; lean angular silhouette.
hiker|Long-legged endurance hiker, soft brimmed trail hat, enormous rolled sleeping mat across tall backpack, light rain shell, thick socks and scuffed trail boots; open chest strap and compact canteen.
ogre|Massive friendly ogre survivor, barrel chest, tiny head, blunt lower tusks, one oversized shoulder pad made from a shopping basket, patched sleeveless hoodie and short heavy boots; distinctly larger hands but humanoid joints.
romantic|Hopeful rescue volunteer in a fitted split-tail coat, heart-shaped padded chest panel, swept hair, rose-shaped shoulder clasp and rounded gift satchel; elegant narrow waist and expressive kind face.
sailor|Lean dockworker survivor, rolled knitted watch cap, striped undershirt, very wide short collar, belted waterproof trousers and rope coil fixed to one hip; tattoo-like simple anchor shape, no text.
apprentice|Young adult technical apprentice, oversized safety goggles pushed onto forehead, loose short workshop coat, many graduated tool pockets, mismatched protective boots and an empty notebook case; slight physique suggests growth potential.
arms_dealer|Organic HUMAN travelling weapons merchant with tan skin, broad visible nose, expressive mouth, rounded ears and short stubble. Long teal FABRIC sleeveless utility coat, empty compartment bandolier, sales-case backpack, close cloth cap and fingerless gloves. Normal human arms and legs, no robot head, metal skin, mechanical joints or carried guns.
artificer|Demolition tinkerer, huge blast goggles, compact reinforced bomb suit with short separated panels, spherical inert charge canisters on belt, wired blast meter on chest and charred heavy gloves; no active explosion.
baby|Tiny adult mall mascot survivor in a padded romper-shaped protective suit, oversized round helmet, short limbs, broad boots and a closed supply bib pouch; deliberately toy-like head-to-body ratio, no infant distress.
beast_master|Pet-shop handler, wiry adult with shaggy layered hair, sleeveless fur-trimmed jacket, thick animal-training gauntlets, feed pouch belt and rolled leash harness; distinctive broad collar, no extra animals in model.
brawler|Muscular amateur boxer, close-cropped hair, thick wrapped forearms, sleeveless athletic vest, padded waist belt and squat boxing boots; large shoulders taper to narrow hips, hands open for rigging.
chunky|Heavyset resilient supermarket survivor, large round belly in reinforced quilted overalls, small knitted cap, broad suspenders, compact snack pouch and very thick soles; friendly face and thick limbs.
crazy|Frenetic knife enthusiast survivor, spiky uneven hair, narrow sleeveless strait-cut vest, many empty knife sheaths, striped patched trousers and asymmetrical elbow pads; thin wiry frame and intense grin.
cryptid|Friendly woodland cryptid humanoid hiding in mall atrium, long shaggy limbs, small antler nubs, mossy shoulder mantle, narrow glowing eyes and digitigrade-looking boot covers over normal feet; two arms and two legs.
cyborg|Half-human maintenance cyborg, one mechanical shoulder and forearm, armored cybernetic leg, half-face optic plate, compact generator spine and open tool sockets; asymmetrical hard-surface silhouette, no attached weapon.
demon|Horned bargain-broker survivor, slim humanoid with two short swept horns, narrow pointed ears, cropped formal vest, coin-vial belt and triangular tail-shaped coat panel fixed to back; no free tail or wing.
entrepreneur|Mall startup founder turned recycler, tailored short blazer over utility harness, slick swept hair, compact folding cash-box backpack, salvaged-parts belt and clean angular shoes; confident narrow silhouette.
explorer|Atrium pathfinder in broad sun hat, layered expedition vest, flat binocular chest case, rolled tarp beneath compact backpack and high gaiters; wide shoulders with lightweight long legs, no held equipment.
farmer|Rooftop urban farmer, broad straw hat with thick sculpted brim, denim overalls, seed-filled belt pockets, rolled sleeves and mud-caked rubber boots; sturdy triangular silhouette and friendly sunworn face.
fisherman|Aquarium angler, floppy waterproof hat, thick yellow rain bib, fishing-lure shaped belt cases without hooks, hip waders and a lidded bait bucket fixed to backpack; round nose and bushy moustache.
generalist|Balanced emergency responder, one fabric shoulder and one light metal shoulder, short versatile field jacket, equal-sized utility pouches on both hips, two-tone work gloves and medium boots; balanced athletic proportions.
ghost|Ghostlike stealth survivor, opaque pale hooded short poncho with scalloped hem, slim visible arms and legs, smooth expressionless mask, padded silent boots and belt of wispy-shaped solid charms; no transparency or floating body.
gladiator|Mall sports-arena fighter, open crested helmet, one oversized segmented shoulder guard, broad leather chest harness, pleated short battle skirt over trousers and thick shin guards; athletic muscular physique.
glutton|Food-court gourmand survivor, huge round chef-bib chest, little bow tie, tall swept hair, stacked sealed lunch tins on backpack and padded stomach guard; short stout legs and oversized oven-safe cuffs.
golem|Awakened mall display golem, heavy humanoid assembled from chipped stone display plinth blocks, square jaw, broad slab shoulders, clear rounded mechanical-like joints and recessed amber chest core; no pedestal under feet.
hunter|Patient precision tracker, lean tall body, low wide brim hat, high-collared short camouflage cape, flat rangefinder goggles, compact quiver-like empty case and long sturdy boots; no rifle or arrows.
jack|Elite boss-hunter survivor, tall triangular torso, angular motorcycle visor, reinforced asymmetric coat, two large trophy-shaped metal plates fixed to chest and oversized protective boots; intimidating clean silhouette.
king|Self-appointed mall king, short heavy crown made of shopping-cart steel, broad fur-trimmed collar, fitted high-quality segmented armor and split royal coat ending above knees; polished gold accents and powerful build.
knight|Armored mall reenactor, rounded closed visor with broad eye slit, articulated steel breastplate, large curved pauldrons, short cloth tabard and plated boots; substantial separated elbow and knee joints.
lich|Friendly undead healer survivor, narrow skeletal-looking mask under tall folded hood, rib-shaped opaque chest armor, short layered robe exposing two legs and sealed potion belt; warm amber chest gem, no floating bones.
loud|Punk mall busker, huge upright mohawk, speaker-shaped padded shoulder armor, cropped studded jacket, broad belt and heavy platform boots; compact loudspeaker pack, no instrument or sound-wave geometry.
lucky|Arcade prize collector, rounded lucky-cat ear cap, puffy short jacket, clover-shaped shoulder patches without words, coin-pouch waist belt and exaggerated soft shoes; jaunty chunky silhouette.
mage|Mall stage magician survivor, tall bent cone hat, short star-shaped scalloped shoulder cape, fitted tunic, large elemental crystal clasp and puffy boots; warm ember accents, no staff or baked magical particles.
masochist|Stubborn stunt performer, cracked protective face shield, bulky impact pads, strapped padded chest protector, bandaged forearms and oversized knee guards; visibly battered equipment without exposed wounds.
multitasker|Organic HUMAN mall technician with warm brown skin, rounded human head, clear nose and mouth, small ears and a tall tied ponytail. Short teal FABRIC six-pocket work coat, circular utility harness with twelve empty mounting sockets, two normal human arms and sturdy boots. No rectangular robot head, lamp eyes, mechanical limbs, extra arms or mounted weapons.
mutant|Rapidly adapting friendly mutant, asymmetric muscular humanoid, one oversized rounded shoulder, segmented skin ridges, small split crest, torn laboratory trousers and mismatched boots; exactly two arms, two legs and one head.
old|Elderly mall caretaker, stooped but riggable upright figure, bald crown with fluffy side hair, huge knitted cardigan, round reading glasses, high-waisted trousers and broad orthopedic shoes; no cane fused to hand.
one_arm|One-armed veteran survivor, strong left arm, right upper arm ending in a clean short sealed sleeve at shoulder, asymmetric harness, close military haircut and light agile boots; no prosthetic replacement or second arm.
pacifist|Evacuation peace volunteer, broad soft sun hat, rounded quilted safety vest, rolled blanket backpack, flower-shaped clasp and open unarmored palms; relaxed sturdy frame, no weapon or aggressive expression.
renegade|Outlaw ranged fighter, low angular helmet, three-lobed empty ammunition pouch belt, short ragged poncho, angular chest armor and long narrow boots; lean silhouette and asymmetrical scarf secured flat.
saver|Frugal cashier survivor, thick round glasses, tight knitted waistcoat, enormous locked piggy-bank-shaped backpack, coin-slot belt purse and small sturdy shoes; hunched narrow shoulders beneath oversized savings pack.
sick|Chronically infected but living survivor, pale tired face behind broad respirator, thin frame, short insulated patient jacket, compact life-support bottle fixed to back and medical brace boots; no gore or open wounds.
soldier|Stationary-fire specialist, broad tactical helmet, heavy squared chest plate, reinforced bracing knee pads, thick ammunition-free vest pouches and planted combat boots; compact disciplined military silhouette.
speedy|Lightweight sprint courier, streamlined bicycle helmet, tiny fitted running vest, narrow waist, long slim legs, aerodynamic elbow pads and exaggerated running shoes; no heavy backpack or flowing coat.
streamer|Mall livestreamer survivor, oversized over-ear headphones, large hair tuft, short hoodie, chest camera block, compact broadcast battery backpack and padded trainers; broad rectangular backpack antenna folded flat.
technomage|Hybrid tech wizard survivor, angular circuit-shaped cowl, narrow segmented coat, hard-surface rune-like chest panels without writing, one mechanical gauntlet and sealed crystal battery pack; no weapon or floating energy.
vagabond|Resourceful drifter, floppy patched cap, multiple overlapping short cloth layers, bedroll tied diagonally to compact backpack, mismatched knee pads and worn boots; irregular silhouette and weathered kind face.
vampire|Elegant vampire survivor, high bat-shaped collar, slick hair, fitted waistcoat with ribbed blood-vial cases, short split crimson-lined coat and pointed armored boots; pale face with small fangs, no wings.
wildling|Feral atrium scavenger, bushy hair, broad fur shoulder wrap, rope-belt tunic, primitive wood shin guards and bare-looking wrapped feet; compact muscular body, no stick or club in hands.
wounded|Fragile survivor protected by one large padded shoulder sling, bandaged forehead, short emergency blanket jacket, soft chest brace and light running shoes; alert face, intact covered skin, no visible wound.
''')

ENEMIES = mapping('''
rhino|Rhino-themed infected riot guard, enormous sloping shoulder armor, short blunt horn fixed to riot helmet, thick neck and heavy shin plates; broad charging wedge silhouette.
bruiser|Infected HUMAN bouncer with very wide muscular shoulders, EXPOSED gray-green human face, asymmetric nose and mouth, sunken cheeks and uneven teeth. Torn teal FABRIC security vest over broad organic torso; metal only on small shoulder pads and forearm guards. Relaxed five-finger hands, stout legs and worn work boots. NOT a robot: no square lamp eyes, metal face or full steel chest.
horned_bruiser|Horned infected arena bouncer, two outward curved helmet horns, huge trapezoid torso, asymmetric stacked shoulder plates and thick split-toe work boots; larger upper body than ordinary bruiser.
helmet_alien|Infected motorcycle courier, oversized spherical full-face helmet with narrow cracked visor, compact armored jacket, tall knee pads and small backpack; head dominates compact body.
bloated_spawner|Bloated infected stockroom carrier, barrel abdomen, four swollen opaque incubation pods attached across backpack, stretched torn coveralls and tiny padded hood; pods integral and closed.
butcher|Infected food-court butcher, enormous squared belly guard, short stained striped apron, slab-like forearms, tiny paper cap and broad rubber boots; no held cleaver or gore.
horned_spitter|Infected chemical-store worker, paired short funnel horns on respirator, swollen throat pouch, narrow torso, spill-proof shoulder tanks and rubber overalls; forward projectile-emitter mouth unobstructed.
anemone|Infected aquarium attendant, crown of thick upright anemone-like rubber tubing, bulbous breathing collar, narrow waterproof apron and stout boots; tubing fixed to head with no additional limbs.
anglerfish|Infected aquarium night guard, single short arched headlamp stalk above large tooth-like respirator grille, narrow shoulders, rounded deep-sea chest suit and heavy boots; lamp integral to helmet.
bat|Lean infected costume-shop runner, large triangular bat-ear hood, short scalloped cape attached above elbows, narrow ribbed torso and long legs; arms fully separate, no actual wings.
bloated_pufferfish|Huge infected aquarium mascot, spherical inflated padded belly studded with broad soft spikes, tiny goggle head, stubby thick limbs and torn diving shorts; distinct balloon silhouette.
blobfish|Sagging infected aquarium cashier, drooping broad face, low rounded shoulders, loose apron stretched across pear-shaped body and flat wide boots; soft folds without gore.
brainy_squid|Infected aquarium scientist, oversized domed cranial helmet showing opaque folded brain-like forms, four thick short cable locks fixed behind head, thin lab coat and narrow legs.
clam|Infected shellfish mascot worker, two large scalloped shell-shaped armor panels enclosing torso, small exposed head above hinge, thick forearms and squat legs; open joints, no real shell enclosure around feet.
colossal_squid|Towering infected aquarium boss, tall mantle-shaped head hood, massive tapered torso, layered tentacle-shaped armored apron strips secured flat and enormous two humanoid arms; no extra limbs.
cool_walrus|Infected retired lifeguard, huge moustache with two short tusks, dark sunglasses, broad inflated life vest, bulky forearms and waterproof boots; rounded imposing chest.
crab|Infected seafood vendor, sideways-wide shoulder carapace, claw-shaped forearm guards over two normal hands, small helmet and short bowed-looking legs; hard red shell texture on armor.
dead_whale|Colossal infected aquarium mascot, very broad whale-shaped padded torso, small round blowhole helmet detail, sagging flipper-shaped shoulder panels and huge heavy boots; two humanoid arms and legs.
diplocaulus|Infected science-museum guide, broad boomerang-shaped helmet extending sideways, slim suit, long pointed elbow pads and athletic legs; distinctive horizontal head silhouette.
dragonfish|Infected aquarium technician, serrated fin-shaped helmet crest, long forward respirator snout, narrow segmented chest armor and rubber waders; small amber lamp nodules fixed to collar.
eel|Long-limbed infected electrician, smooth narrow eel-shaped hood, ribbed cable chest harness, streamlined torso, long rubber gloves and elongated boots; no tail or extra limbs.
evil_mob|Tiny infected mall mascot, pointed hood, oversized scowling faceplate, short ragged tunic and squat bare-looking padded feet; simple compact high-contrast silhouette for dense groups.
firemane_anemone|Infected aquarium furnace technician, thick flame-shaped orange tube crown, insulated circular shoulder collar, short charred apron and heavy rubber boots; solid sculpted forms, no actual fire particles.
giant|Towering infected delivery porter, tiny head above immensely broad square shoulders, giant parcel-harness torso, massive hands and thick freight boots; no carried detached boxes.
giant_isopod|Infected aquarium armored mascot, overlapping pill-bug plates covering a long hunched upper back, small tucked head, thick gauntlets and stout humanoid legs; no extra insect legs.
goblin_shark|Thin infected aquarium diver, long flat pointed nose guard, narrow jagged respirator grille, tall fin-shaped back plate and long agile limbs; forward-leaning character proportions.
hermit|Infected homeless aquarium scavenger, enormous spiral-shell backpack, small hooded head and narrow chest beneath it, two thin arms and heavy uneven boots; shell firmly integrated with harness.
impaled_worm|Infected maintenance crawler reinterpreted as lanky humanoid, segmented tubular torso armor, blunt vertical rebar-shaped spine brace secured behind head, tiny masked face and long banded limbs; no impalement wound.
infected_blobfish|Heavily infected aquarium cashier, asymmetrical sagging belly, opaque fungal nodules on one shoulder, drooping mask face and torn quarantine apron; markedly lopsided silhouette distinct from ordinary blobfish.
iron_lung|Infected hospital evacuation patient, huge cylindrical metal respirator casing around torso, small masked head, hose-covered forearms and short mechanical-braced legs; breathing grille front-facing.
jellyfish|Infected aquarium guide, translucent-looking but opaque milky bell-shaped helmet, short thick cable fringe above shoulders, slim diving torso and long rubber boots; no floating fringe or actual transparency.
lobster|Infected seafood kitchen worker, tall segmented lobster-tail-shaped back armor, elongated claw gauntlets over ordinary hands, antenna-like short helmet bars and narrow armored legs.
looting_pig|Infected greedy stockroom raider, pig-snouted respirator, huge supply-filled belly bag, tiny cap, bulky shoulders and thick short boots; several sealed shopping pouches integrated at hips.
mad_dragonfish|Frenzied infected deep-sea technician, twin jagged crest fins, gaping rigid respirator grille, asymmetrical spiked shoulder tank and long wiry legs; more aggressive angular silhouette than dragonfish.
megalodon|Massive infected shark mascot enforcer, triangular dorsal armor above broad shoulders, wide tooth-edged jaw helmet, muscular heavy torso and short powerful legs; no actual fish tail.
narwhal|Infected aquarium parade runner, single long blunt spiral horn rising diagonally from helmet, narrow flotation vest, smooth shoulder pads and long sprinting legs; horn is rigid accessory, no weapon in hand.
plankton|Tiny infected aquarium lab helper, oversized round single-lens goggles, compact smooth hood, short oval torso and very thin separated limbs; bright collar and simple silhouette.
prisoner|Infected detention escapee, broad locked chest restraint, striped short prison jacket without numbers, shaved head, chunky wrist cuffs with no loose chains and heavily braced boots.
pufferfish|Infected aquarium mascot, compact rounded padded torso with six broad blunt conical studs, large circular goggles and average-length thin arms and legs; less inflated than bloated pufferfish.
scaled_goblin_shark|Infected armored aquarium diver, long flat shark snout helmet, layered scale-shaped shoulder and thigh guards, lean torso and sharp dorsal back fin; lean fast proportions preserved beneath armor.
scaled_stargazer|Infected armored aquarium ambusher, upward-facing goggle visor, squat wedge head, layered angular scale plates on chest and shins, long lean arms; head broader than goblin shark.
sea_pig|Infected deep-sea exhibit mascot, low pinkish padded belly, short soft snout mask, rounded backpack lobes and stumpy boots; small arms held clear of barrel body.
shielded_diplocaulus|Infected shielded museum guard, giant boomerang helmet, broad curved chest shield fixed to torso, thick forearm plates and compact reinforced legs; two free hands, no detached shield.
shrimp|Small infected seafood courier, curved segmented back protector, short antenna-shaped cap studs, narrow pointed mask, tiny chest and long springy legs; orange shell-like shin guards.
spider_crab|Tall infected aquarium climber, broad low crab-like helmet, narrow angular torso, exceptionally long thin arms and legs with bulbous knee pads; two arms and two legs only.
spiky_lung|Infected quarantine patient, spherical ribbed respirator shell covering chest and belly, large blunt metal spikes on shoulder casing, small masked head and short thick legs; distinct from smooth iron lung.
stargazer|Infected aquarium ambusher, broad flattened helmet with two upward-tilted round lenses, low shoulders, slim chest harness and long lean legs; no fish tail.
stonefish|Infected aquarium maintenance guard, irregular stone-like shell armor, broad craggy shoulders, tiny recessed mask and thick stocky limbs; squat asymmetrical rocky silhouette.
turtle|Infected mall aquarium mascot, enormous domed segmented shell backpack, blunt helmet, wide padded chest, thick forearms and short heavy boots; shell firmly on humanoid torso.
vampire_squid|Infected aquarium illusionist, dark tall hood, scalloped short cape with thick suction-cup-shaped discs fixed along collar, narrow pale mask and elegant long boots; no actual tentacle limbs.
viperfish|Infected aquarium hunter, extremely narrow tall head with long tooth-shaped respirator fins, thin arched neck guard, slim ribbed suit and long arms; small luminous collar bead forms.
walrus|Infected aquarium janitor, broad moustached respirator with two blunt downward tusks, heavy waterproof apron, sloping shoulders and massive rubber boots; no sunglasses or flotation vest.
buffer|Infected mall fitness instructor, broad padded sports vest, large megaphone-shaped collar mounted behind head, thick sweatbands and springy sneakers; visual support-aura source is solid chest beacon.
corrupted_buffer|Corrupted infected fitness instructor, one swollen fungal shoulder, cracked multi-disc beacon collar, asymmetrical segmented vest and heavy split-colored shoes; distorted silhouette differs from normal buffer.
croc|Infected reptile-exhibit runner, long crocodile snout mask, ridged short back armor, narrow athletic torso and long splayed-looking boots; no tail, fast lean humanoid.
dire_junkie|Severely infected arcade runner, huge asymmetrical padded hood, multiple sealed stimulant canisters on chest, hunched broad shoulders and very thin long legs; opaque skin swellings without gore.
fin_alien|Infected swim-shop athlete, single tall fin-shaped mohawk helmet, close-fitting ribbed swimming suit, narrow shoulders and elongated flipper-like boot covers; two free arms.
fly|Infected pest-control runner, huge paired compound-eye goggles, short clear-looking opaque wing-shaped backpack panels fixed against back, thin coveralls and long rubber boots.
gargoyle|Infected architectural restoration worker, angular stone gargoyle mask, heavy pointed shoulder ornaments, folded wing-shaped stone back plates and agile long legs; no free wings.
horned_charger|Infected charging mascot, two long forward-angled blunt helmet horns, wedge-shaped neck armor, narrow waist and powerful thick thighs; aggressive head-first silhouette in neutral rig pose.
horned_fly|Infected horned pest-control sprinter, giant faceted goggles with paired short horns above them, narrow insect-like chest harness, folded hard wing panels on back and long thin legs.
infected_slasher_egg|Infected nursery carrier humanoid, oval opaque egg-like abdominal shell cracked with raised fungal seams, small hooded head and two long thin arms; compact legs clear below shell, no gore or detached eggs.
invoker|Infected occult bookshop attendant, tall tiered hood, triangular short ceremonial coat, closed summoning-device pack and narrow claw-shaped glove armor; pale elongated face and long legs.
junkie|Infected arcade loiterer, narrow hooded head, baggy short vest with two sealed soda-can-shaped cartridges, slumped thin shoulders and long spindly legs; no drugs or needles visible.
lamprey|Infected pipe-maintenance worker, round concentric tooth-like respirator grille, long ribbed torso suit, eel-like smooth hood and elongated arms; two booted legs, no extra tentacle.
looter|Infected smash-and-grab thief, oversized bulging sack backpack, low baseball cap, angular torn vest, hooked-looking glove guards and long scuffed boots; hands empty.
mad_slasher|Frenzied infected salon worker, huge wild comb-like hair crest, torn short barber apron, long blade-shaped forearm armor fixed safely along arms and thin agile legs; no held scissors.
mantis|Infected garden-store runner, triangular insect-like face shield, high narrow shoulders, folded scythe-shaped elbow guards along two normal arms and very long narrow legs; no additional limbs.
monk|Infected wellness-shop attendant, bald round head, huge solid prayer-bead collar, short layered robe, broad belt and soft boots; round support-beacon clasp, hands separated and empty.
predator|Infected mall stalker, angular low hunting visor, broad swept shoulder plates, narrow waist, thick forearm guards and long spring-loaded-looking boot armor; muscular feline-inspired humanoid silhouette.
pursuer|Relentless infected security tracker, tall narrow hood, long split trench jacket above knees, rectangular scanning visor, compact spinal battery and long heavy boots; lean vertical silhouette.
slasher_egg|Nursery carrier zombie, smooth oval padded egg-shell abdomen, tiny round respirator head, short intact apron and narrow arms and legs clearly outside shell; uncracked smooth shell differs from infected variant.
spawner|Infected stockroom carrier with a clearly visible separate human head and neck ABOVE the shoulders, unobstructed front torso, chest harness and thick gloves. Three SMALL closed incubation canisters are strapped LOW on the back below the shoulders, never covering head, neck or arms. Tall narrow body, two clear arms and legs; no loose pods.
tentacle|Infected hose-maintenance humanoid, thick segmented tentacle-like protective sleeves on two arms, compact masked head, coiled hose collar and narrow banded legs; no extra limbs, hose ends secured.
''')

WEAPONS = mapping('''
anchor|Heavy reclaimed ship anchor, thick straight shank, large upper ring at LEFT, two broad curved flukes at RIGHT; rusted teal iron, chunky welded joints, horizontal shank.
brick|One single solid rectangular red clay brick, chipped beveled corners and three shallow rectangular recesses on its top face. Just a handheld masonry brick. No gun, barrel, grip, handle, weapon assembly, pedestal, table or extra objects.
captains_sword|Elegant curved naval cutlass, narrow brass basket guard and dark grip LEFT, long broad gently curved silver blade tapering to pointed tip RIGHT; ornate but simple raised trim.
chainsaw|One compact salvage chainsaw, bulky teal motor housing and closed rear handle LEFT, straight toothed guide bar extending RIGHT; continuous blunt stylized chain teeth, visible top handle.
hiking_stick|One telescopic trekking pole laid horizontally, thick ergonomic cork grip and strap loop secured at LEFT, three stepped metal shaft sections tapering to rubber point RIGHT.
lute|One battered acoustic lute used as a club, short fretted neck and grip LEFT, large round ribbed pear-shaped wooden resonator RIGHT, inset sound hole and simplified strings flush to body.
mace|One heavy medieval salvage mace, short leather grip LEFT, straight steel shaft, massive faceted six-flange striking head RIGHT; worn dark iron with amber rivets.
sickle|One harvesting sickle, thick wooden grip LEFT, hooked crescent steel blade curving upward then toward RIGHT, clearly visible hollow crescent and sharpened inner edge.
spoon|One oversized steel cafeteria spoon, thick taped handle LEFT, deep oval reflective bowl RIGHT; sturdy industrial shape, no food.
trident|One salvage trident, long dark straight shaft with leather grip LEFT, three distinct parallel steel tines pointing RIGHT, center tine slightly longer; teal crossbar.
war_hammer|One massive two-faced war hammer, long reinforced grip LEFT, huge rectangular steel hammer block RIGHT with broad flat striking faces and angled bevels; no spikes or axe blade.
blunderbuss|One antique blunderbuss, short dark wooden shoulder stock LEFT, bulky brass receiver, dramatically flared single trumpet muzzle pointing RIGHT; trigger guard below, no pump handle.
flute|One metallic concert flute laid horizontally, thick mouthpiece end LEFT, long narrow silver tube with six broad sculpted key pads, open end RIGHT; no case or musician.
grenade_launcher|One standalone chunky grenade launcher, short shoulder stock LEFT, six-chamber rotary drum in center, short large-bore single muzzle pointing RIGHT, pistol grip below; no spare grenades.
harpoon_gun|One pneumatic harpoon gun, compact teal rear grip LEFT, long barrel rail with one thick pointed harpoon seated along top aiming RIGHT, small integral pressure cylinder below; no trailing rope.
javelin|One athletic throwing javelin, straight slender shaft horizontal, narrow rounded tail LEFT, thicker central wrapped grip, tapered metallic point RIGHT; clean continuous shaft.
cacti_club|One improvised cactus club, brown wrapped grip LEFT, thick oval cactus-shaped striking body RIGHT with widely spaced broad thorn studs; solid opaque green surface, no plant pot.
chopper|One heavy kitchen cleaver, short dark wooden grip LEFT, very broad rectangular steel blade RIGHT with rounded upper corner and small hanging hole; straight cutting edge below.
circular_saw|One handheld circular saw, compact motor and enclosed rear grip LEFT, large toothed circular blade exposed at RIGHT, partial teal safety guard above blade; single tool, no table.
claw|One EMPTY wearable wrist gauntlet with THREE parallel long curved steel claw blades extending straight RIGHT from its knuckle plate. Short open padded wrist cuff LEFT, no arm inside. Compact dark leather glove shell, teal knuckle plate, silver blades. No gun, stock, barrel, trigger, pistol grip, support post, pedestal or extra objects.
dagger|One narrow double-edged combat dagger, compact dark grip and small straight guard LEFT, symmetrical diamond-section blade tapering to sharp point RIGHT; distinct from broad kitchen knife.
dextroyer|One oversized industrial salvage lance, short wrapped powered grip LEFT, long narrow reinforced shaft with a thick ribbed central power chamber, ending RIGHT in a large angular forked spear blade with two solid gold-edged prongs and a deep triangular gap. One continuous weapon; no rectangular cleaver slab, exposed flesh, detached sparks or blast effect.
drill|One heavy industrial power drill, squared teal motor body and rear grip LEFT, enormous conical spiral drill bit extending RIGHT; wide spiral grooves and small amber power pack below.
excalibur|One ceremonial broadsword, ornate brass crossguard and dark grip LEFT, broad straight polished blade RIGHT with long central fuller and diamond-shaped tip; inset amber gem, no stone pedestal.
fighting_stick|One martial-arts baton, thick cylindrical dark hardwood shaft horizontal, wrapped grip LEFT, smooth rounded striking tip RIGHT; two raised metal reinforcement bands near the tip.
fist|One detached boxing-gauntlet weapon, empty open wrist cuff LEFT, compact padded closed-knuckle shape RIGHT; brown stitched leather with steel knuckle plate, no human hand or arm.
flaming_brass_knuckles|One compact brass knuckle duster: FOUR adjacent round finger holes through one thick golden metal frame, a short integral palm rest underneath, small solid red ceramic inserts on the upper striking ridge. All four holes fully open and visible. No gun, barrel, trigger, pistol grip, stock, wrist gauntlet, human hand or flame.
ghost_axe|One spectral-themed opaque axe, wrapped bone-colored haft LEFT, broad solid pale-mint crescent axe head RIGHT, carved hollow crescent opening and dark socket; opaque stone and metal, no mist or transparent surfaces.
ghost_flint|One hand-sized knapped pale-cyan flint shard, thick blunt graspable heel LEFT and long triangular chipped point RIGHT, broad faceted stone body with dark fissures; no wooden shaft, axe head, straps, detached chips, aura or translucent surfaces.
hand|One oversized open mechanical glove weapon, empty wrist cuff LEFT, five broad blunt segmented finger shapes extending RIGHT in a shallow fan; clearly artificial padded glove, no flesh or arm.
jousting_lance|One long jousting lance, rear grip and large conical hand guard LEFT, long tapered painted wood shaft ending in blunt metal point RIGHT; clean straight horizontal silhouette.
lightning_shiv|One compact electrical shiv, rubber grip and small battery LEFT, short jagged twin-edged steel point RIGHT with inset blue ceramic conductor strip; no lightning geometry.
plank|One battered wooden plank, taped grip around LEFT end, broad splintered flat striking end RIGHT, three short blunt nails embedded near tip; no detached pieces.
plasma_sledgehammer|One sci-fi sledgehammer, powered cylindrical grip LEFT, giant double-faced rectangular head RIGHT with recessed cyan plasma panels and thick steel frame; no energy cloud.
power_fist|One powered mechanical gauntlet, open empty wrist cuff LEFT, huge squared four-knuckle armored punch block RIGHT, hydraulic pistons fixed along side; no human hand or arm.
pruner|One compact garden pruning shears, two thick closed handles LEFT, short curved hooked cutting jaws RIGHT slightly open, broad center hinge visible; dark teal grips and worn silver jaws.
rock|One asymmetrical rough gray stone club head with a small wrapped gripping indentation on LEFT, heavier faceted blunt striking mass RIGHT; single stone, no handle or ground.
scissors|One large steel tailoring scissors, two oval finger loops LEFT, broad crossing blades extending RIGHT slightly open, visible round pivot; no human hand.
screwdriver|One long flat-head screwdriver, thick faceted amber rubber handle LEFT, straight narrow steel shaft extending RIGHT and broad flattened terminal tip; single tool.
scythe|One oversized salvage scythe, long dark straight grip shaft LEFT, huge curved crescent blade projecting from shaft end RIGHT, wide sharpened silver edge; no person or foliage.
sharp_tooth|One massive curved fossil tooth weapon, thick wrapped root grip LEFT, broad ivory body tapering into a hooked pointed tip RIGHT; ridged root and worn enamel.
spiky_shield|One thick convex round metal buckler in a three-quarter side view, integrated rear handgrip on the LEFT, a broad central boss with one short stout conical striking spike projecting RIGHT perpendicular to the shield face. Scuffed teal plate and reinforced rim, enough thickness to read from above; no arm, hand, pedestal or detached parts.
stick|One simple natural tree branch club, thin wrapped gripping end LEFT, thicker knotted striking end RIGHT, three sawn-off twig nubs; rough brown wood, no foliage.
sword|One practical straight arming sword, dark leather grip and simple rectangular crossguard LEFT, medium-width steel blade with central fuller tapering RIGHT; plain utilitarian silhouette.
thunder_sword|One heavy electrical sword, insulated grip LEFT, broad angular blade pointing RIGHT, thick lightning-bolt-shaped ceramic inset along central fuller and squared guard; no emitted bolts.
torch|One complete traditional survival torch: a SINGLE continuous stout wooden shaft, wrapped grip LEFT and cloth-bound thicker head RIGHT secured directly by two tight metal bands. Head and handle share uninterrupted connected wood. No separate basket, brazier, lantern, floating piece or flame; the engine supplies moving fire.
bloody_vorpal|One sinister curved vorpal blade, dark ribbed grip LEFT, broad hooked steel blade RIGHT with deep crescent cutout and crimson enamel channel; no blood or gore.
chain_gun|One heavy belt-fed machine gun, squared rear receiver and compact shoulder brace LEFT, one long thick barrel inside a perforated heat shroud pointing RIGHT, short integrated feed box below and a compact linked ammunition belt secured flush to the receiver. Single muzzle, no rotary barrel cluster, loose ammunition or muzzle flash.
fireball|One handheld arcane fire emitter, short dark insulated grip LEFT, spherical solid amber ceramic fire core enclosed in three thick bronze cage ribs RIGHT, broad forward circular aperture; no flame, projectile or particles.
flamethrower|One compact handheld flamethrower, rear pistol grip LEFT, short wide perforated heat-shield barrel pointing RIGHT, small ignition nozzle below muzzle, integrated fuel cylinder beneath body; no backpack, hose, flame or person.
gatling_laser|One heavy rotary laser cannon, compact rear power block LEFT, six blunt parallel optical barrels in circular cluster pointing RIGHT, cyan lens recesses and thick cooling collar; no projectile or beam.
ghost_scepter|One opaque spectral scepter, dark tapered hand grip LEFT, pale mint skull-shaped cage head RIGHT around solid inner crystal, broad curved ribs; no transparent mist or floating fragments.
icicle|One solid crystalline ice spike weapon, thick frosted grip root LEFT, long asymmetrical faceted blue-white ice blade tapering to point RIGHT; opaque material with broad readable facets, no water or particles.
medical_gun|One chunky rescue injector gun, white and teal receiver, short rear pistol grip LEFT, broad blunt nozzle pointing RIGHT, large sealed transparent-looking opaque medicine cylinder across top; no needle or red-cross insignia.
minigun|One portable minigun, compact rear motor housing LEFT, six long parallel steel barrels in circular cluster aiming RIGHT, broad rear handle and integral ammunition box; no tripod or loose belt.
nuclear_launcher|One huge sci-fi containment launcher, rear shoulder grip LEFT, broad cylindrical armored chamber and single enormous circular muzzle pointing RIGHT, thick orange hazard bands without symbols; no missile or explosion.
obliterator|One colossal mechanical dragon-head siege gun, short rear stock LEFT, heavy ribbed receiver, armored reptilian snout projecting RIGHT with a single deep firing aperture framed by thick blunt tooth-shaped metal plates, short angular dorsal fins and one recessed amber eye-shaped panel. All rigid machine parts, no living creature, tongue, loose teeth, tripod or beam.
particle_accelerator|One experimental particle accelerator gun, compact rear power block and grip LEFT, thick cylindrical forward chamber wrapped in four broad separated magnetic coil collars, ribbed solid amber core visible between collars, ending RIGHT in one large circular recessed emitter rim. Heavy rounded coil silhouette; no long twin open rails, beam, particles or detached rings.
potato_thrower|One improvised grocery produce launcher, rear stock and grip LEFT, broad pipe muzzle pointing RIGHT, integrated lidded hopper above receiver shaped like a small produce crate; no loose food or projectile.
rail_gun|One precision electromagnetic rifle, slim rear stock LEFT, two long rectangular parallel rails extending RIGHT, open center gap, small top sight and thick central power block; no beam.
shredder|One compact disc-launching gun, stubby rear grip LEFT, flattened saw-disc magazine integrated into center body, wide thin horizontal slot muzzle pointing RIGHT; no exposed loose discs or projectile.
shuriken|One four-point steel throwing star, broad symmetrical flat body, small center hole, four distinct pointed blades with one point aiming RIGHT; dark beveled metal, no hand or motion trail.
slingshot|One wooden Y-shaped slingshot, thick wrapped lower grip toward LEFT, two broad fork arms toward RIGHT, taut dark rubber bands and empty central pouch; no stones or hand.
sniper_gun|One long bolt-action sniper rifle, angular stock LEFT, long thin single barrel aiming RIGHT, large integral scope above receiver, compact grip and box magazine below; no bipod or ammunition.
taser|One compact stun gun, thick insulated rear grip LEFT, short squared body with two widely separated blunt electrical contacts pointing RIGHT, small recessed indicator panel; no lightning or human target.
wand|One magical salvage wand, short dark wrapped grip LEFT, slender slightly curved wood shaft extending RIGHT to a small faceted amber crystal held by three thick metal prongs; no energy particles.
''')

UTILITY = mapping('''
blazemander|Friendly small rescue salamander companion, low long body, four short separated legs, thick curled tail, broad smiling snout, charcoal heatproof harness and solid orange dorsal ceramic fins; no fire. Neutral quadruped pose.
bonk_dog|Friendly stocky rescue bulldog, four short separated legs, broad muzzle, squat ears, padded work harness and one compact foam mallet fixed horizontally on backpack; neutral quadruped pose.
bot_o_mine|Compact friendly mine-laying security robot, upright rounded tan-and-teal torso balanced on one broad integrated wheel, short neck and square camera-like head with one large circular recessed forward firing aperture, small red-tipped antenna and closed rear mine compartment. Complete body with short integral aperture rim; no drill, insect legs, long gun barrel, detached mines, bullets or muzzle flash.
catling_gun|Friendly mechanical rescue cat, four separated paws, pointed ears, rounded feline head and curved tail. Teal armored harness with two EMPTY swivel mounting pads on the left and right upper flanks. CAT BODY AND EMPTY MOUNTS ONLY: no barrels, fixed guns or central turret. Keep clear space around both pads; the engine attaches two independently aimed guns.
doc_moth|Friendly medical moth companion, compact upright segmented abdomen, small rounded head with two knobbed antennae and FOUR thick opaque wings: a larger upper pair and a smaller lower pair, all spread symmetrically with clear gaps. Soft green wing panels with muted pink circular markings, cream medical satchel integrated around thorax; no lettering, red cross, halo, healing ring or particles.
jellyshield|One small friendly jellyfish companion, a smooth thick opaque pale-cyan bell with a large round blue eye inset in its front and FOUR soft short curved hanging tentacles, tapering rounded ends, clearly separated below the bell. Floating creature body only. No robot, metal armor, straight support legs, feet, shoes, table, base, halo or transparency.
lootworm|Friendly salvage-collecting worm companion, thick short segmented green body curved behind an upright broad head, large clearly modeled open oval mouth with rounded blunt teeth and recessed dark throat, two short knobbed antennae and three closed utility pockets attached along its back. No legs, separate grabber claws, loose food, coins, swallowed objects or effects.
ratzilla|Friendly oversized salvage rat companion, four separated sturdy legs, large round ears, blunt whisker nubs, thick tail curved beside body and patched utility saddle; neutral quadruped pose, no rider.
scapegoat|Friendly compact rescue goat companion, four separated sturdy legs, two short curved horns, little beard, padded protective vest and large bell-shaped closed chest charm; neutral quadruped pose.
landmine|One compact deployable salvage landmine, low squat circular steel body, broad raised pressure plate, three recessed indicator dots and orange edge band; solid intact unarmed-looking object, no explosion.
turret|One autonomous mall defense gun turret, low three-foot integral mechanical support, central rotating steel column, short rectangular receiver and single barrel pointing RIGHT; no ground platform, bullets or person.
builder_turret|One reinforced builder turret, four integral short square support feet, broad brick-like armored base, tall articulated column, twin short barrels pointing RIGHT and visible welded braces; no loose building materials.
flame_turret|One automatic fire-defense turret, low three-foot mechanical support, round integrated fuel tank, squat rotating head and wide perforated nozzle pointing RIGHT; no flame or loose hoses.
garden|One compact rooftop garden utility object, rectangular chipped metal planter containing dark soil, four distinct broad-leaf plants and three attached ripe red fruits; integral planter required, no surrounding ground.
healing_turret|One automated healing station, low three-foot support, rounded cream body, broad teal capsule-shaped central beacon and two stubby folded dispenser arms; no red cross, text or healing particles.
laser_turret|One compact laser defense turret, three low angular feet, faceted rotating head, single thick optical barrel pointing RIGHT and recessed cyan lens; integral cooling fins, no beam.
rocket_turret|One autonomous rocket turret, four short braced feet, rotating box head holding four recessed launch tubes in a two-by-two grid pointing RIGHT; no visible detached missiles or fire.
tyler|One improvised boxing defense robot, squat integral wheeled base, spring-like vertical torso column, two thick forward padded mechanical punch arms and small welding-mask head; arms part of same robot, no person.
wandering_bot|One hovering crowd-control support drone, compact rounded orange-and-teal body, tall shield-shaped recessed blue sensor face, two short integrated side stabilizers and one small underside emitter disk; solid connected upper rotor housing, no wheels, gun barrel, ammunition, detached rotor blades or surrounding slow-field effects.
tree|One mall atrium planter with broad rooted trunk and dense three-lobed green canopy, chipped square concrete pot, two low sawn branch nubs and visible soil; integral planter, no surrounding floor or extra trees.
fruit|One sealed food-court survival ration pack, squat folded kraft-paper pouch with clear sculpted folded seams, orange round fruit shape embossed on front and small green closure tab; no words, logos or loose food.
poisoned_fruit|One toxic spoiled mall-grocery fruit, asymmetrical deep-purple lobed fruit body, four raised sickly yellow-green danger spots, one short crooked dark stem and a wilted leaf attached on top; no container, face, skull, text or particles. Clearly unsafe-looking and distinct from a healing ration.
cursed_chest|One cursed mall supply chest, squat purple-black armored case, high faceted lid, two broad violet metal straps, two short blunt horn-shaped lid corners and a pale diamond-shaped lock with dark keyhole; sealed lid, no glow cloud, text, skull, background or detached accessories.
item_box|One ordinary mall supply crate, small squat teal metal case with beveled corners, two broad lid straps, silver reinforced edges and simple recessed latch; lid closed, no lettering or surrounding objects.
legendary_item_box|One rare emergency vault crate, heavy faceted gold-edged dark case, raised armored lid, large hexagonal amber latch and four protective corner feet; closed, no glow particles or text, distinct from ordinary crate.
material|One small handheld bundle of three stacked beveled scrap-metal ingots tightly bound together by two wide teal straps. All ingots touch, one compact solid pickup. No table, legs, workstation, pedestal, loose pieces, coins or words.
''')

STYLE = 'Stylized 3D game asset for a zombie-infested shopping mall, chunky readable cartoon proportions, worn teal steel, muted fabric and warm amber accents, hand-painted 1K texture, clean opaque surfaces. '
HUMAN = ' Full body, one character only, upright neutral A-pose, feet apart, hands empty and separated from torso, clear elbows and knees, face forward, ready for humanoid rigging. No weapon, base, floor, background scene, text, logo, gore or detached accessories.'
STATIC = ' Single isolated complete static object, clear silhouette from above, broad bevels, no thin floating detail. Landscape orientation with functional tip or muzzle RIGHT and grip LEFT. No hands, human, base, display stand, background scene, text, logo, particles or extra objects.'
PROP = ' One complete isolated game object, broad readable top-down silhouette, clean separated forms, opaque materials, neutral pose if alive. No display pedestal, surrounding floor, background scene, text, logo, detached accessories or particles.'

def local(resource):
    return ROOT / 'gdproj' / resource.removeprefix('res://')

def source_evidence(m, enemies):
    src = m['source']
    if src.startswith('enemy:'):
        src = enemies[src.split(':')[1]]
    if src.startswith('consumable_'):
        key=src.removeprefix('consumable_')
        src = f'res://dlcs/dlc_1/consumables/{key}_data.tres' if key in ('poisoned_fruit','cursed_chest') else f'res://items/consumables/{key}/{key}_data.tres'
    evidence = {'resource': src, 'queue_role': m.get('role', '')}
    if not src.startswith('res://'):
        return evidence
    p = local(src)
    assert p.exists(), src
    content = p.read_text(encoding='utf-8')
    evidence['resource_sha256'] = hashlib.sha256(p.read_bytes()).hexdigest()
    refs = re.findall(r'path="(res://[^"]+)"', content)
    evidence['gameplay_references'] = [r for r in refs if any(x in r for x in ('effect', 'stats', 'behavior', '/sets/')) and not r.endswith('.png')]
    evidence['behavior_scene_references'] = [r for r in refs if r.endswith(('.tscn', '.gd')) and any(x in r for x in ('projectile', 'enemy', 'pet', 'turret', 'weapon'))]
    evidence['direct_gameplay_fields'] = [line.strip() for line in content.splitlines() if re.match(r'^(projectile_speed|number_projectiles|cooldown|initial_cooldown|spawn_projectiles_on_target|projectile_spawn_only_on_borders|wanted_tags|enemy_id|weapon_id) =', line)]
    # Actual scalar evidence from directly linked effects/stats, not guessed mechanics.
    hints = []
    for r in evidence['gameplay_references']:
        rp = local(r)
        if not rp.exists() or rp.suffix != '.tres':
            continue
        fields = [line.strip() for line in rp.read_text(encoding='utf-8').splitlines() if re.match(r'^(key|custom_key|value|damage|cooldown|piercing|burn_chance|projectiles|stat|speed) =', line)]
        if fields:
            hints.append({'resource': r, 'fields': fields})
    evidence['gameplay_fields'] = hints
    return evidence

def main():
    queue_path = ROOT / 'docs/model-production-queue.json'
    queue = json.loads(queue_path.read_text(encoding='utf-8'))
    enemies = {e['id']: e['resource'] for e in json.loads((ROOT/'docs/enemy-art-coverage.json').read_text(encoding='utf-8'))}
    production = {r['target_identity']:r for r in json.loads((ROOT/'docs/tripo-production-2026-09-06.json').read_text(encoding='utf-8'))['assets'] if r.get('target_identity')}
    rows = []
    for m in queue['models']:
        if all(m['acceptance'].values()):
            continue
        key = m['id'].removeprefix('character_').removeprefix('weapon_').removeprefix('enemy:').removeprefix('prop:')
        category = m['category']
        if category == 'survivor':
            concept, ending = SURVIVORS[key], HUMAN
        elif category == 'enemy':
            concept, ending = ENEMIES[key], HUMAN
        elif category == 'weapon':
            concept, ending = WEAPONS[key], STATIC
        elif category == 'environment':
            raise AssertionError('New pending environment needs an explicit authored brief')
        else:
            concept, ending = UTILITY[key], PROP
        # Deliberate one-arm silhouette cannot honestly pass the normal two-arm rig contract.
        note = ''
        if key == 'one_arm':
            ending = HUMAN.replace('hands empty and separated from torso', 'left hand empty and separated from torso')
            note = 'One-arm identity: try humanoid rig once only; if rejected, export static and use a dedicated one-arm skeleton locally. Do not regenerate a second arm to pass rigging.'
        if category == 'weapon' and key == 'shuriken':
            ending = STATIC.replace('Landscape orientation with functional tip or muzzle RIGHT and grip LEFT.', 'Flat blade face UP, one point RIGHT; four symmetric points around center, absolutely no handle or grip.')
        if category == 'weapon' and key == 'brick':
            ending = STATIC.replace('Landscape orientation with functional tip or muzzle RIGHT and grip LEFT.', 'Longest dimension runs horizontally; recessed face UP. Plain masonry object with no handle or grip.')
        if category == 'weapon' and key == 'flaming_brass_knuckles':
            ending = ' Single isolated compact static knuckle duster, four finger holes in a horizontal row, broad face toward viewer. No pedestal, support, scene, text, logo or extra objects.'
        if category == 'weapon' and key in ('hand', 'claw'):
            ending = STATIC.replace('No hands, human,', 'No exposed flesh or human body,')
        if category == 'weapon' and key == 'torch':
            note = 'Engine TorchFlameArt mirrors the actual BurningParticles emitter. Keep the mesh head physically connected to its shaft; verify actual muzzle alignment and set icon_flame_origin from the imported head. See docs/torch-flame-3d-review.md.'
        if category == 'enemy' and m.get('role') in ('tentacle', 'spore_nest'):
            note = 'Intentional zombie humanoid reinterpretation preserves gameplay role; verify elongation or egg-carrying silhouette against attack/spawn behavior, not original animal anatomy.'
        if category == 'pet':
            note = 'Retain companion species and silhouette; do not use humanoid auto-rig. Static procedural motion or an appropriate animal/robot rig must be reviewed separately.'
            if key == 'catling_gun':
                note += ' Body only with two empty mounts; CatlingAimArt supplies independent gun nodes. Normalize to about 0.9 world units high, feet at ground, nose toward +Z; verify actual muzzle alignment. See docs/catling-dual-aim-review.md.'
        style = STYLE.replace('worn teal steel, muted fabric and warm amber accents', 'soft pale-cyan surfaces and muted blue accents') if key == 'jellyshield' else STYLE
        if category in ('survivor', 'enemy'):
            style = STYLE.replace('worn teal steel, muted fabric and warm amber accents', 'natural skin and muted fabric clothing, small teal metal accessories and warm amber accents')
        brief = concept + ' ' + style + ending
        assert len(brief) <= 950, (m['id'], len(brief))
        rows.append({'id':m['id'], 'category':category, 'queue_status_at_build':m['status'], 'production_action':'generate' if m['status']=='pending_generation' and not m.get('studio_url') else 'resume_existing_job_or_import; do_not_generate_duplicate', 'target_triangles':m['target_triangles'], 'texture_size':m['texture_size'], 'rig_requested_by_queue':m['rig'], 'brief':brief, 'brief_characters':len(brief), 'design_rationale':concept, 'integration_note':note, 'evidence':source_evidence(m,enemies)})
        if m['id'] in production:
            job=production[m['id']]
            rows[-1]['production_action']=('generate_replacement_for_rejected_visual; retain_previous_cost'
                                          if 'reject' in job.get('status','').lower()
                                          else 'resume_existing_job_or_import; do_not_generate_duplicate')
            rows[-1]['existing_production_job']={'asset':job['id'],'status':job['status'],'url':job.get('url')}
    assert len({r['id'] for r in rows}) == len(rows)
    assert len({r['brief'] for r in rows}) == len(rows)
    out = {'schema':1, 'scope':f'Production briefs for every not-fully-accepted identity in the authoritative {len(queue["models"])}-model queue. Snapshot only; recheck live ledger and Studio job before spending credits.', 'style_decision':'Zombie mall cartoon; survivors retain gameplay archetypes, enemies become distinct infected mall workers/mascots; no color-only identity substitutions.', 'queue_sha256_at_build':hashlib.sha256(queue_path.read_bytes()).hexdigest(), 'counts':dict(collections.Counter(r['category'] for r in rows)), 'count':len(rows), 'completed_excluded':len(queue['models'])-len(rows), 'maximum_brief_characters':max(r['brief_characters'] for r in rows), 'validation':'Exact set equality against incomplete queue; unique IDs and prompts; <=950 characters; actual source files resolved and hashed; linked effect/stat values extracted. Briefs are design specifications, not model acceptance.', 'briefs':rows}
    (ROOT/'docs/tripo-remaining-briefs.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:out[k] for k in ('count','counts','completed_excluded','maximum_brief_characters')},ensure_ascii=False))

if __name__ == '__main__':
    main()
