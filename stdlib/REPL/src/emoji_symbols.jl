# This file is a part of Julia. License is MIT: https://julialang.org/license

#==
using Pkg: @pkg_str
pkg"activate --temp"
pkg"add JSON@0.21"

import JSON

function emoji_data(url)
    emojis = JSON.parsefile(download(url))
    result = Dict()
    for emj in emojis
        name = "\\:" * emj["short_name"] * ":"
        unicode = emj["unified"]
        if '-' in unicode
            continue
        end
        result[name] = "$(Char(parse(UInt32, unicode, base = 16)))"
    end
    return result
end

# We combine multiple versions as the data changes, and not only by growing.
result = mapfoldr(emoji_data, merge, [
    # Newer versions must be added to top of this list as we want the older versions to
    # overwrite so we keep the old names of things that are renamed
    "https://raw.githubusercontent.com/iamcal/emoji-data/e512953312c012f6bd00e3f2ef6bf152ca3710f8/emoji_pretty.json",
    "https://raw.githubusercontent.com/iamcal/emoji-data/0f0cf4ea8845eb52d26df2a48c3c31c3b8cad14e/emoji_pretty.json",
    ];
    init=Dict()
)

skeys = sort(collect(keys(result)))
open("emoji_symbols.jl", "w") do fh
    println(fh, "const emoji_symbols = Dict(")
    for key in skeys
        println(fh, "    \"", escape_string(key), "\" => \"",
                 escape_string(result[key]), "\",")
    end
    println(fh, ")")
end
==#


const emoji_symbols = Dict(
    "\\:+1:" => "👍",
    "\\:-1:" => "👎",
    "\\:100:" => "💯",
    "\\:1234:" => "🔢",
    "\\:8ball:" => "🎱",
    "\\:a:" => "🅰",
    "\\:ab:" => "🆎",
    "\\:abacus:" => "🧮",
    "\\:abc:" => "🔤",
    "\\:abcd:" => "🔡",
    "\\:accept:" => "🉑",
    "\\:accordion:" => "🪗",
    "\\:adhesive_bandage:" => "🩹",
    "\\:adult:" => "🧑",
    "\\:aerial_tramway:" => "🚡",
    "\\:airplane:" => "✈",
    "\\:airplane_arriving:" => "🛬",
    "\\:airplane_departure:" => "🛫",
    "\\:alarm_clock:" => "⏰",
    "\\:alien:" => "👽",
    "\\:ambulance:" => "🚑",
    "\\:amphora:" => "🏺",
    "\\:anatomical_heart:" => "🫀",
    "\\:anchor:" => "⚓",
    "\\:angel:" => "👼",
    "\\:anger:" => "💢",
    "\\:angry:" => "😠",
    "\\:anguished:" => "😧",
    "\\:ant:" => "🐜",
    "\\:apple:" => "🍎",
    "\\:aquarius:" => "♒",
    "\\:aries:" => "♈",
    "\\:arrow_backward:" => "◀",
    "\\:arrow_double_down:" => "⏬",
    "\\:arrow_double_up:" => "⏫",
    "\\:arrow_down:" => "⬇",
    "\\:arrow_down_small:" => "🔽",
    "\\:arrow_forward:" => "▶",
    "\\:arrow_heading_down:" => "⤵",
    "\\:arrow_heading_up:" => "⤴",
    "\\:arrow_left:" => "⬅",
    "\\:arrow_lower_left:" => "↙",
    "\\:arrow_lower_right:" => "↘",
    "\\:arrow_right:" => "➡",
    "\\:arrow_right_hook:" => "↪",
    "\\:arrow_up:" => "⬆",
    "\\:arrow_up_down:" => "↕",
    "\\:arrow_up_small:" => "🔼",
    "\\:arrow_upper_left:" => "↖",
    "\\:arrow_upper_right:" => "↗",
    "\\:arrows_clockwise:" => "🔃",
    "\\:arrows_counterclockwise:" => "🔄",
    "\\:art:" => "🎨",
    "\\:articulated_lorry:" => "🚛",
    "\\:astonished:" => "😲",
    "\\:athletic_shoe:" => "👟",
    "\\:atm:" => "🏧",
    "\\:auto_rickshaw:" => "🛺",
    "\\:avocado:" => "🥑",
    "\\:axe:" => "🪓",
    "\\:b:" => "🅱",
    "\\:baby:" => "👶",
    "\\:baby_bottle:" => "🍼",
    "\\:baby_chick:" => "🐤",
    "\\:baby_symbol:" => "🚼",
    "\\:back:" => "🔙",
    "\\:bacon:" => "🥓",
    "\\:badger:" => "🦡",
    "\\:badminton_racquet_and_shuttlecock:" => "🏸",
    "\\:bagel:" => "🥯",
    "\\:baggage_claim:" => "🛄",
    "\\:baguette_bread:" => "🥖",
    "\\:ballet_shoes:" => "🩰",
    "\\:balloon:" => "🎈",
    "\\:ballot_box_with_check:" => "☑",
    "\\:bamboo:" => "🎍",
    "\\:banana:" => "🍌",
    "\\:bangbang:" => "‼",
    "\\:banjo:" => "🪕",
    "\\:bank:" => "🏦",
    "\\:bar_chart:" => "📊",
    "\\:barber:" => "💈",
    "\\:baseball:" => "⚾",
    "\\:basket:" => "🧺",
    "\\:basketball:" => "🏀",
    "\\:bat:" => "🦇",
    "\\:bath:" => "🛀",
    "\\:bathtub:" => "🛁",
    "\\:battery:" => "🔋",
    "\\:bear:" => "🐻",
    "\\:bearded_person:" => "🧔",
    "\\:beaver:" => "🦫",
    "\\:bee:" => "🐝",
    "\\:beer:" => "🍺",
    "\\:beers:" => "🍻",
    "\\:beetle:" => "🐞",
    "\\:beginner:" => "🔰",
    "\\:bell:" => "🔔",
    "\\:bell_pepper:" => "🫑",
    "\\:bento:" => "🍱",
    "\\:beverage_box:" => "🧃",
    "\\:bicyclist:" => "🚴",
    "\\:bike:" => "🚲",
    "\\:bikini:" => "👙",
    "\\:billed_cap:" => "🧢",
    "\\:bird:" => "🐦",
    "\\:birthday:" => "🎂",
    "\\:bison:" => "🦬",
    "\\:black_circle:" => "⚫",
    "\\:black_heart:" => "🖤",
    "\\:black_joker:" => "🃏",
    "\\:black_large_square:" => "⬛",
    "\\:black_medium_small_square:" => "◾",
    "\\:black_medium_square:" => "◼",
    "\\:black_nib:" => "✒",
    "\\:black_small_square:" => "▪",
    "\\:black_square_button:" => "🔲",
    "\\:blossom:" => "🌼",
    "\\:blowfish:" => "🐡",
    "\\:blue_book:" => "📘",
    "\\:blue_car:" => "🚙",
    "\\:blue_heart:" => "💙",
    "\\:blueberries:" => "🫐",
    "\\:blush:" => "😊",
    "\\:boar:" => "🐗",
    "\\:boat:" => "⛵",
    "\\:bomb:" => "💣",
    "\\:bone:" => "🦴",
    "\\:book:" => "📖",
    "\\:bookmark:" => "🔖",
    "\\:bookmark_tabs:" => "📑",
    "\\:books:" => "📚",
    "\\:boom:" => "💥",
    "\\:boomerang:" => "🪃",
    "\\:boot:" => "👢",
    "\\:bouquet:" => "💐",
    "\\:bow:" => "🙇",
    "\\:bow_and_arrow:" => "🏹",
    "\\:bowl_with_spoon:" => "🥣",
    "\\:bowling:" => "🎳",
    "\\:boxing_glove:" => "🥊",
    "\\:boy:" => "👦",
    "\\:brain:" => "🧠",
    "\\:bread:" => "🍞",
    "\\:breast-feeding:" => "🤱",
    "\\:bricks:" => "🧱",
    "\\:bride_with_veil:" => "👰",
    "\\:bridge_at_night:" => "🌉",
    "\\:briefcase:" => "💼",
    "\\:briefs:" => "🩲",
    "\\:broccoli:" => "🥦",
    "\\:broken_heart:" => "💔",
    "\\:broom:" => "🧹",
    "\\:brown_heart:" => "🤎",
    "\\:bubble_tea:" => "🧋",
    "\\:bucket:" => "🪣",
    "\\:bug:" => "🐛",
    "\\:bulb:" => "💡",
    "\\:bullettrain_front:" => "🚅",
    "\\:bullettrain_side:" => "🚄",
    "\\:burrito:" => "🌯",
    "\\:bus:" => "🚌",
    "\\:busstop:" => "🚏",
    "\\:bust_in_silhouette:" => "👤",
    "\\:busts_in_silhouette:" => "👥",
    "\\:butter:" => "🧈",
    "\\:butterfly:" => "🦋",
    "\\:cactus:" => "🌵",
    "\\:cake:" => "🍰",
    "\\:calendar:" => "📆",
    "\\:call_me_hand:" => "🤙",
    "\\:calling:" => "📲",
    "\\:camel:" => "🐫",
    "\\:camera:" => "📷",
    "\\:camera_with_flash:" => "📸",
    "\\:cancer:" => "♋",
    "\\:candy:" => "🍬",
    "\\:canned_food:" => "🥫",
    "\\:canoe:" => "🛶",
    "\\:capital_abcd:" => "🔠",
    "\\:capricorn:" => "♑",
    "\\:car:" => "🚗",
    "\\:card_index:" => "📇",
    "\\:carousel_horse:" => "🎠",
    "\\:carpentry_saw:" => "🪚",
    "\\:carrot:" => "🥕",
    "\\:cat2:" => "🐈",
    "\\:cat:" => "🐱",
    "\\:cd:" => "💿",
    "\\:chair:" => "🪑",
    "\\:champagne:" => "🍾",
    "\\:chart:" => "💹",
    "\\:chart_with_downwards_trend:" => "📉",
    "\\:chart_with_upwards_trend:" => "📈",
    "\\:checkered_flag:" => "🏁",
    "\\:cheese_wedge:" => "🧀",
    "\\:cherries:" => "🍒",
    "\\:cherry_blossom:" => "🌸",
    "\\:chestnut:" => "🌰",
    "\\:chicken:" => "🐔",
    "\\:child:" => "🧒",
    "\\:children_crossing:" => "🚸",
    "\\:chocolate_bar:" => "🍫",
    "\\:chopsticks:" => "🥢",
    "\\:christmas_tree:" => "🎄",
    "\\:church:" => "⛪",
    "\\:cinema:" => "🎦",
    "\\:circus_tent:" => "🎪",
    "\\:city_sunrise:" => "🌇",
    "\\:city_sunset:" => "🌆",
    "\\:cl:" => "🆑",
    "\\:clap:" => "👏",
    "\\:clapper:" => "🎬",
    "\\:clinking_glasses:" => "🥂",
    "\\:clipboard:" => "📋",
    "\\:clock1030:" => "🕥",
    "\\:clock10:" => "🕙",
    "\\:clock1130:" => "🕦",
    "\\:clock11:" => "🕚",
    "\\:clock1230:" => "🕧",
    "\\:clock12:" => "🕛",
    "\\:clock130:" => "🕜",
    "\\:clock1:" => "🕐",
    "\\:clock230:" => "🕝",
    "\\:clock2:" => "🕑",
    "\\:clock330:" => "🕞",
    "\\:clock3:" => "🕒",
    "\\:clock430:" => "🕟",
    "\\:clock4:" => "🕓",
    "\\:clock530:" => "🕠",
    "\\:clock5:" => "🕔",
    "\\:clock630:" => "🕡",
    "\\:clock6:" => "🕕",
    "\\:clock730:" => "🕢",
    "\\:clock7:" => "🕖",
    "\\:clock830:" => "🕣",
    "\\:clock8:" => "🕗",
    "\\:clock930:" => "🕤",
    "\\:clock9:" => "🕘",
    "\\:closed_book:" => "📕",
    "\\:closed_lock_with_key:" => "🔐",
    "\\:closed_umbrella:" => "🌂",
    "\\:cloud:" => "☁",
    "\\:clown_face:" => "🤡",
    "\\:clubs:" => "♣",
    "\\:coat:" => "🧥",
    "\\:cockroach:" => "🪳",
    "\\:cocktail:" => "🍸",
    "\\:coconut:" => "🥥",
    "\\:coffee:" => "☕",
    "\\:coin:" => "🪙",
    "\\:cold_face:" => "🥶",
    "\\:cold_sweat:" => "😰",
    "\\:compass:" => "🧭",
    "\\:computer:" => "💻",
    "\\:confetti_ball:" => "🎊",
    "\\:confounded:" => "😖",
    "\\:confused:" => "😕",
    "\\:congratulations:" => "㊗",
    "\\:construction:" => "🚧",
    "\\:construction_worker:" => "👷",
    "\\:convenience_store:" => "🏪",
    "\\:cookie:" => "🍪",
    "\\:cool:" => "🆒",
    "\\:cop:" => "👮",
    "\\:copyright:" => "©",
    "\\:corn:" => "🌽",
    "\\:couple:" => "👫",
    "\\:couple_with_heart:" => "💑",
    "\\:couplekiss:" => "💏",
    "\\:cow2:" => "🐄",
    "\\:cow:" => "🐮",
    "\\:crab:" => "🦀",
    "\\:credit_card:" => "💳",
    "\\:crescent_moon:" => "🌙",
    "\\:cricket:" => "🦗",
    "\\:cricket_bat_and_ball:" => "🏏",
    "\\:crocodile:" => "🐊",
    "\\:croissant:" => "🥐",
    "\\:crossed_fingers:" => "🤞",
    "\\:crossed_flags:" => "🎌",
    "\\:crown:" => "👑",
    "\\:cry:" => "😢",
    "\\:crying_cat_face:" => "😿",
    "\\:crystal_ball:" => "🔮",
    "\\:cucumber:" => "🥒",
    "\\:cup_with_straw:" => "🥤",
    "\\:cupcake:" => "🧁",
    "\\:cupid:" => "💘",
    "\\:curling_stone:" => "🥌",
    "\\:curly_loop:" => "➰",
    "\\:currency_exchange:" => "💱",
    "\\:curry:" => "🍛",
    "\\:custard:" => "🍮",
    "\\:customs:" => "🛃",
    "\\:cut_of_meat:" => "🥩",
    "\\:cyclone:" => "🌀",
    "\\:dancer:" => "💃",
    "\\:dancers:" => "👯",
    "\\:dango:" => "🍡",
    "\\:dart:" => "🎯",
    "\\:dash:" => "💨",
    "\\:date:" => "📅",
    "\\:deaf_person:" => "🧏",
    "\\:deciduous_tree:" => "🌳",
    "\\:deer:" => "🦌",
    "\\:department_store:" => "🏬",
    "\\:diamond_shape_with_a_dot_inside:" => "💠",
    "\\:diamonds:" => "♦",
    "\\:disappointed:" => "😞",
    "\\:disappointed_relieved:" => "😥",
    "\\:disguised_face:" => "🥸",
    "\\:diving_mask:" => "🤿",
    "\\:diya_lamp:" => "🪔",
    "\\:dizzy:" => "💫",
    "\\:dizzy_face:" => "😵",
    "\\:dna:" => "🧬",
    "\\:do_not_litter:" => "🚯",
    "\\:dodo:" => "🦤",
    "\\:dog2:" => "🐕",
    "\\:dog:" => "🐶",
    "\\:dollar:" => "💵",
    "\\:dolls:" => "🎎",
    "\\:dolphin:" => "🐬",
    "\\:door:" => "🚪",
    "\\:doughnut:" => "🍩",
    "\\:dragon:" => "🐉",
    "\\:dragon_face:" => "🐲",
    "\\:dress:" => "👗",
    "\\:dromedary_camel:" => "🐪",
    "\\:drooling_face:" => "🤤",
    "\\:drop_of_blood:" => "🩸",
    "\\:droplet:" => "💧",
    "\\:drum_with_drumsticks:" => "🥁",
    "\\:duck:" => "🦆",
    "\\:dumpling:" => "🥟",
    "\\:dvd:" => "📀",
    "\\:e-mail:" => "📧",
    "\\:eagle:" => "🦅",
    "\\:ear:" => "👂",
    "\\:ear_of_rice:" => "🌾",
    "\\:ear_with_hearing_aid:" => "🦻",
    "\\:earth_africa:" => "🌍",
    "\\:earth_americas:" => "🌎",
    "\\:earth_asia:" => "🌏",
    "\\:egg:" => "🍳",
    "\\:eggplant:" => "🍆",
    "\\:eight_pointed_black_star:" => "✴",
    "\\:eight_spoked_asterisk:" => "✳",
    "\\:electric_plug:" => "🔌",
    "\\:elephant:" => "🐘",
    "\\:elevator:" => "🛗",
    "\\:elf:" => "🧝",
    "\\:email:" => "✉",
    "\\:end:" => "🔚",
    "\\:envelope_with_arrow:" => "📩",
    "\\:euro:" => "💶",
    "\\:european_castle:" => "🏰",
    "\\:european_post_office:" => "🏤",
    "\\:evergreen_tree:" => "🌲",
    "\\:exclamation:" => "❗",
    "\\:exploding_head:" => "🤯",
    "\\:expressionless:" => "😑",
    "\\:eyeglasses:" => "👓",
    "\\:eyes:" => "👀",
    "\\:face_palm:" => "🤦",
    "\\:face_vomiting:" => "🤮",
    "\\:face_with_cowboy_hat:" => "🤠",
    "\\:face_with_hand_over_mouth:" => "🤭",
    "\\:face_with_head_bandage:" => "🤕",
    "\\:face_with_monocle:" => "🧐",
    "\\:face_with_raised_eyebrow:" => "🤨",
    "\\:face_with_rolling_eyes:" => "🙄",
    "\\:face_with_symbols_on_mouth:" => "🤬",
    "\\:face_with_thermometer:" => "🤒",
    "\\:facepunch:" => "👊",
    "\\:factory:" => "🏭",
    "\\:fairy:" => "🧚",
    "\\:falafel:" => "🧆",
    "\\:fallen_leaf:" => "🍂",
    "\\:family:" => "👪",
    "\\:fast_forward:" => "⏩",
    "\\:fax:" => "📠",
    "\\:fearful:" => "😨",
    "\\:feather:" => "🪶",
    "\\:feet:" => "🐾",
    "\\:fencer:" => "🤺",
    "\\:ferris_wheel:" => "🎡",
    "\\:field_hockey_stick_and_ball:" => "🏑",
    "\\:file_folder:" => "📁",
    "\\:fire:" => "🔥",
    "\\:fire_engine:" => "🚒",
    "\\:fire_extinguisher:" => "🧯",
    "\\:firecracker:" => "🧨",
    "\\:fireworks:" => "🎆",
    "\\:first_place_medal:" => "🥇",
    "\\:first_quarter_moon:" => "🌓",
    "\\:first_quarter_moon_with_face:" => "🌛",
    "\\:fish:" => "🐟",
    "\\:fish_cake:" => "🍥",
    "\\:fishing_pole_and_fish:" => "🎣",
    "\\:fist:" => "✊",
    "\\:flags:" => "🎏",
    "\\:flamingo:" => "🦩",
    "\\:flashlight:" => "🔦",
    "\\:flatbread:" => "🫓",
    "\\:floppy_disk:" => "💾",
    "\\:flower_playing_cards:" => "🎴",
    "\\:flushed:" => "😳",
    "\\:fly:" => "🪰",
    "\\:flying_disc:" => "🥏",
    "\\:flying_saucer:" => "🛸",
    "\\:foggy:" => "🌁",
    "\\:fondue:" => "🫕",
    "\\:foot:" => "🦶",
    "\\:football:" => "🏈",
    "\\:footprints:" => "👣",
    "\\:fork_and_knife:" => "🍴",
    "\\:fortune_cookie:" => "🥠",
    "\\:fountain:" => "⛲",
    "\\:four_leaf_clover:" => "🍀",
    "\\:fox_face:" => "🦊",
    "\\:free:" => "🆓",
    "\\:fried_egg:" => "🍳",
    "\\:fried_shrimp:" => "🍤",
    "\\:fries:" => "🍟",
    "\\:frog:" => "🐸",
    "\\:frowning:" => "😦",
    "\\:fuelpump:" => "⛽",
    "\\:full_moon:" => "🌕",
    "\\:full_moon_with_face:" => "🌝",
    "\\:game_die:" => "🎲",
    "\\:garlic:" => "🧄",
    "\\:gem:" => "💎",
    "\\:gemini:" => "♊",
    "\\:genie:" => "🧞",
    "\\:ghost:" => "👻",
    "\\:gift:" => "🎁",
    "\\:gift_heart:" => "💝",
    "\\:giraffe_face:" => "🦒",
    "\\:girl:" => "👧",
    "\\:glass_of_milk:" => "🥛",
    "\\:globe_with_meridians:" => "🌐",
    "\\:gloves:" => "🧤",
    "\\:goal_net:" => "🥅",
    "\\:goat:" => "🐐",
    "\\:goggles:" => "🥽",
    "\\:golf:" => "⛳",
    "\\:gorilla:" => "🦍",
    "\\:grapes:" => "🍇",
    "\\:green_apple:" => "🍏",
    "\\:green_book:" => "📗",
    "\\:green_heart:" => "💚",
    "\\:green_salad:" => "🥗",
    "\\:grey_exclamation:" => "❕",
    "\\:grey_question:" => "❔",
    "\\:grimacing:" => "😬",
    "\\:grin:" => "😁",
    "\\:grinning:" => "😀",
    "\\:guardsman:" => "💂",
    "\\:guide_dog:" => "🦮",
    "\\:guitar:" => "🎸",
    "\\:gun:" => "🔫",
    "\\:haircut:" => "💇",
    "\\:hamburger:" => "🍔",
    "\\:hammer:" => "🔨",
    "\\:hamster:" => "🐹",
    "\\:hand:" => "✋",
    "\\:handbag:" => "👜",
    "\\:handball:" => "🤾",
    "\\:handshake:" => "🤝",
    "\\:hankey:" => "💩",
    "\\:hatched_chick:" => "🐥",
    "\\:hatching_chick:" => "🐣",
    "\\:headphones:" => "🎧",
    "\\:headstone:" => "🪦",
    "\\:hear_no_evil:" => "🙉",
    "\\:heart:" => "❤",
    "\\:heart_decoration:" => "💟",
    "\\:heart_eyes:" => "😍",
    "\\:heart_eyes_cat:" => "😻",
    "\\:heartbeat:" => "💓",
    "\\:heartpulse:" => "💗",
    "\\:hearts:" => "♥",
    "\\:heavy_check_mark:" => "✔",
    "\\:heavy_division_sign:" => "➗",
    "\\:heavy_dollar_sign:" => "💲",
    "\\:heavy_minus_sign:" => "➖",
    "\\:heavy_multiplication_x:" => "✖",
    "\\:heavy_plus_sign:" => "➕",
    "\\:hedgehog:" => "🦔",
    "\\:helicopter:" => "🚁",
    "\\:herb:" => "🌿",
    "\\:hibiscus:" => "🌺",
    "\\:high_brightness:" => "🔆",
    "\\:high_heel:" => "👠",
    "\\:hiking_boot:" => "🥾",
    "\\:hindu_temple:" => "🛕",
    "\\:hippopotamus:" => "🦛",
    "\\:hocho:" => "🔪",
    "\\:honey_pot:" => "🍯",
    "\\:hook:" => "🪝",
    "\\:horse:" => "🐴",
    "\\:horse_racing:" => "🏇",
    "\\:hospital:" => "🏥",
    "\\:hot_face:" => "🥵",
    "\\:hotdog:" => "🌭",
    "\\:hotel:" => "🏨",
    "\\:hotsprings:" => "♨",
    "\\:hourglass:" => "⌛",
    "\\:hourglass_flowing_sand:" => "⏳",
    "\\:house:" => "🏠",
    "\\:house_with_garden:" => "🏡",
    "\\:hugging_face:" => "🤗",
    "\\:hushed:" => "😯",
    "\\:hut:" => "🛖",
    "\\:i_love_you_hand_sign:" => "🤟",
    "\\:ice_cream:" => "🍨",
    "\\:ice_cube:" => "🧊",
    "\\:ice_hockey_stick_and_puck:" => "🏒",
    "\\:icecream:" => "🍦",
    "\\:id:" => "🆔",
    "\\:ideograph_advantage:" => "🉐",
    "\\:imp:" => "👿",
    "\\:inbox_tray:" => "📥",
    "\\:incoming_envelope:" => "📨",
    "\\:information_desk_person:" => "💁",
    "\\:information_source:" => "ℹ",
    "\\:innocent:" => "😇",
    "\\:interrobang:" => "⁉",
    "\\:iphone:" => "📱",
    "\\:izakaya_lantern:" => "🏮",
    "\\:jack_o_lantern:" => "🎃",
    "\\:japan:" => "🗾",
    "\\:japanese_castle:" => "🏯",
    "\\:japanese_goblin:" => "👺",
    "\\:japanese_ogre:" => "👹",
    "\\:jeans:" => "👖",
    "\\:jigsaw:" => "🧩",
    "\\:joy:" => "😂",
    "\\:joy_cat:" => "😹",
    "\\:juggling:" => "🤹",
    "\\:kaaba:" => "🕋",
    "\\:kangaroo:" => "🦘",
    "\\:key:" => "🔑",
    "\\:keycap_ten:" => "🔟",
    "\\:kimono:" => "👘",
    "\\:kiss:" => "💋",
    "\\:kissing:" => "😗",
    "\\:kissing_cat:" => "😽",
    "\\:kissing_closed_eyes:" => "😚",
    "\\:kissing_heart:" => "😘",
    "\\:kissing_smiling_eyes:" => "😙",
    "\\:kite:" => "🪁",
    "\\:kiwifruit:" => "🥝",
    "\\:kneeling_person:" => "🧎",
    "\\:knot:" => "🪢",
    "\\:koala:" => "🐨",
    "\\:koko:" => "🈁",
    "\\:lab_coat:" => "🥼",
    "\\:lacrosse:" => "🥍",
    "\\:ladder:" => "🪜",
    "\\:ladybug:" => "🐞",
    "\\:large_blue_circle:" => "🔵",
    "\\:large_blue_diamond:" => "🔷",
    "\\:large_blue_square:" => "🟦",
    "\\:large_brown_circle:" => "🟤",
    "\\:large_brown_square:" => "🟫",
    "\\:large_green_circle:" => "🟢",
    "\\:large_green_square:" => "🟩",
    "\\:large_orange_circle:" => "🟠",
    "\\:large_orange_diamond:" => "🔶",
    "\\:large_orange_square:" => "🟧",
    "\\:large_purple_circle:" => "🟣",
    "\\:large_purple_square:" => "🟪",
    "\\:large_red_square:" => "🟥",
    "\\:large_yellow_circle:" => "🟡",
    "\\:large_yellow_square:" => "🟨",
    "\\:last_quarter_moon:" => "🌗",
    "\\:last_quarter_moon_with_face:" => "🌜",
    "\\:laughing:" => "😆",
    "\\:leafy_green:" => "🥬",
    "\\:leaves:" => "🍃",
    "\\:ledger:" => "📒",
    "\\:left-facing_fist:" => "🤛",
    "\\:left_luggage:" => "🛅",
    "\\:left_right_arrow:" => "↔",
    "\\:leftwards_arrow_with_hook:" => "↩",
    "\\:leg:" => "🦵",
    "\\:lemon:" => "🍋",
    "\\:leo:" => "♌",
    "\\:leopard:" => "🐆",
    "\\:libra:" => "♎",
    "\\:light_rail:" => "🚈",
    "\\:link:" => "🔗",
    "\\:lion_face:" => "🦁",
    "\\:lips:" => "👄",
    "\\:lipstick:" => "💄",
    "\\:lizard:" => "🦎",
    "\\:llama:" => "🦙",
    "\\:lobster:" => "🦞",
    "\\:lock:" => "🔒",
    "\\:lock_with_ink_pen:" => "🔏",
    "\\:lollipop:" => "🍭",
    "\\:long_drum:" => "🪘",
    "\\:loop:" => "➿",
    "\\:lotion_bottle:" => "🧴",
    "\\:loud_sound:" => "🔊",
    "\\:loudspeaker:" => "📢",
    "\\:love_hotel:" => "🏩",
    "\\:love_letter:" => "💌",
    "\\:low_brightness:" => "🔅",
    "\\:luggage:" => "🧳",
    "\\:lungs:" => "🫁",
    "\\:lying_face:" => "🤥",
    "\\:m:" => "Ⓜ",
    "\\:mag:" => "🔍",
    "\\:mag_right:" => "🔎",
    "\\:mage:" => "🧙",
    "\\:magic_wand:" => "🪄",
    "\\:magnet:" => "🧲",
    "\\:mahjong:" => "🀄",
    "\\:mailbox:" => "📫",
    "\\:mailbox_closed:" => "📪",
    "\\:mailbox_with_mail:" => "📬",
    "\\:mailbox_with_no_mail:" => "📭",
    "\\:mammoth:" => "🦣",
    "\\:man:" => "👨",
    "\\:man_and_woman_holding_hands:" => "👫",
    "\\:man_dancing:" => "🕺",
    "\\:man_with_gua_pi_mao:" => "👲",
    "\\:man_with_turban:" => "👳",
    "\\:mango:" => "🥭",
    "\\:mans_shoe:" => "👞",
    "\\:manual_wheelchair:" => "🦽",
    "\\:maple_leaf:" => "🍁",
    "\\:martial_arts_uniform:" => "🥋",
    "\\:mask:" => "😷",
    "\\:massage:" => "💆",
    "\\:mate_drink:" => "🧉",
    "\\:meat_on_bone:" => "🍖",
    "\\:mechanical_arm:" => "🦾",
    "\\:mechanical_leg:" => "🦿",
    "\\:mega:" => "📣",
    "\\:melon:" => "🍈",
    "\\:memo:" => "📝",
    "\\:menorah_with_nine_branches:" => "🕎",
    "\\:mens:" => "🚹",
    "\\:merperson:" => "🧜",
    "\\:metro:" => "🚇",
    "\\:microbe:" => "🦠",
    "\\:microphone:" => "🎤",
    "\\:microscope:" => "🔬",
    "\\:middle_finger:" => "🖕",
    "\\:military_helmet:" => "🪖",
    "\\:milky_way:" => "🌌",
    "\\:minibus:" => "🚐",
    "\\:minidisc:" => "💽",
    "\\:mirror:" => "🪞",
    "\\:mobile_phone_off:" => "📴",
    "\\:money_mouth_face:" => "🤑",
    "\\:money_with_wings:" => "💸",
    "\\:moneybag:" => "💰",
    "\\:monkey:" => "🐒",
    "\\:monkey_face:" => "🐵",
    "\\:monorail:" => "🚝",
    "\\:moon:" => "🌔",
    "\\:moon_cake:" => "🥮",
    "\\:mortar_board:" => "🎓",
    "\\:mosque:" => "🕌",
    "\\:mosquito:" => "🦟",
    "\\:motor_scooter:" => "🛵",
    "\\:motorized_wheelchair:" => "🦼",
    "\\:mount_fuji:" => "🗻",
    "\\:mountain_bicyclist:" => "🚵",
    "\\:mountain_cableway:" => "🚠",
    "\\:mountain_railway:" => "🚞",
    "\\:mouse2:" => "🐁",
    "\\:mouse:" => "🐭",
    "\\:mouse_trap:" => "🪤",
    "\\:movie_camera:" => "🎥",
    "\\:moyai:" => "🗿",
    "\\:mrs_claus:" => "🤶",
    "\\:muscle:" => "💪",
    "\\:mushroom:" => "🍄",
    "\\:musical_keyboard:" => "🎹",
    "\\:musical_note:" => "🎵",
    "\\:musical_score:" => "🎼",
    "\\:mute:" => "🔇",
    "\\:nail_care:" => "💅",
    "\\:name_badge:" => "📛",
    "\\:nauseated_face:" => "🤢",
    "\\:nazar_amulet:" => "🧿",
    "\\:necktie:" => "👔",
    "\\:negative_squared_cross_mark:" => "❎",
    "\\:nerd_face:" => "🤓",
    "\\:nesting_dolls:" => "🪆",
    "\\:neutral_face:" => "😐",
    "\\:new:" => "🆕",
    "\\:new_moon:" => "🌑",
    "\\:new_moon_with_face:" => "🌚",
    "\\:newspaper:" => "📰",
    "\\:ng:" => "🆖",
    "\\:night_with_stars:" => "🌃",
    "\\:ninja:" => "🥷",
    "\\:no_bell:" => "🔕",
    "\\:no_bicycles:" => "🚳",
    "\\:no_entry:" => "⛔",
    "\\:no_entry_sign:" => "🚫",
    "\\:no_good:" => "🙅",
    "\\:no_mobile_phones:" => "📵",
    "\\:no_mouth:" => "😶",
    "\\:no_pedestrians:" => "🚷",
    "\\:no_smoking:" => "🚭",
    "\\:non-potable_water:" => "🚱",
    "\\:nose:" => "👃",
    "\\:notebook:" => "📓",
    "\\:notebook_with_decorative_cover:" => "📔",
    "\\:notes:" => "🎶",
    "\\:nut_and_bolt:" => "🔩",
    "\\:o2:" => "🅾",
    "\\:o:" => "⭕",
    "\\:ocean:" => "🌊",
    "\\:octagonal_sign:" => "🛑",
    "\\:octopus:" => "🐙",
    "\\:oden:" => "🍢",
    "\\:office:" => "🏢",
    "\\:ok:" => "🆗",
    "\\:ok_hand:" => "👌",
    "\\:ok_woman:" => "🙆",
    "\\:older_adult:" => "🧓",
    "\\:older_man:" => "👴",
    "\\:older_woman:" => "👵",
    "\\:olive:" => "🫒",
    "\\:on:" => "🔛",
    "\\:oncoming_automobile:" => "🚘",
    "\\:oncoming_bus:" => "🚍",
    "\\:oncoming_police_car:" => "🚔",
    "\\:oncoming_taxi:" => "🚖",
    "\\:one-piece_swimsuit:" => "🩱",
    "\\:onion:" => "🧅",
    "\\:open_file_folder:" => "📂",
    "\\:open_hands:" => "👐",
    "\\:open_mouth:" => "😮",
    "\\:ophiuchus:" => "⛎",
    "\\:orange_book:" => "📙",
    "\\:orange_heart:" => "🧡",
    "\\:orangutan:" => "🦧",
    "\\:otter:" => "🦦",
    "\\:outbox_tray:" => "📤",
    "\\:owl:" => "🦉",
    "\\:ox:" => "🐂",
    "\\:oyster:" => "🦪",
    "\\:package:" => "📦",
    "\\:page_facing_up:" => "📄",
    "\\:page_with_curl:" => "📃",
    "\\:pager:" => "📟",
    "\\:palm_tree:" => "🌴",
    "\\:palms_up_together:" => "🤲",
    "\\:pancakes:" => "🥞",
    "\\:panda_face:" => "🐼",
    "\\:paperclip:" => "📎",
    "\\:parachute:" => "🪂",
    "\\:parking:" => "🅿",
    "\\:parrot:" => "🦜",
    "\\:part_alternation_mark:" => "〽",
    "\\:partly_sunny:" => "⛅",
    "\\:partying_face:" => "🥳",
    "\\:passport_control:" => "🛂",
    "\\:peach:" => "🍑",
    "\\:peacock:" => "🦚",
    "\\:peanuts:" => "🥜",
    "\\:pear:" => "🍐",
    "\\:pencil2:" => "✏",
    "\\:penguin:" => "🐧",
    "\\:pensive:" => "😔",
    "\\:people_hugging:" => "🫂",
    "\\:performing_arts:" => "🎭",
    "\\:persevere:" => "😣",
    "\\:person_climbing:" => "🧗",
    "\\:person_doing_cartwheel:" => "🤸",
    "\\:person_frowning:" => "🙍",
    "\\:person_in_lotus_position:" => "🧘",
    "\\:person_in_steamy_room:" => "🧖",
    "\\:person_in_tuxedo:" => "🤵",
    "\\:person_with_blond_hair:" => "👱",
    "\\:person_with_headscarf:" => "🧕",
    "\\:person_with_pouting_face:" => "🙎",
    "\\:petri_dish:" => "🧫",
    "\\:phone:" => "☎",
    "\\:pickup_truck:" => "🛻",
    "\\:pie:" => "🥧",
    "\\:pig2:" => "🐖",
    "\\:pig:" => "🐷",
    "\\:pig_nose:" => "🐽",
    "\\:pill:" => "💊",
    "\\:pinata:" => "🪅",
    "\\:pinched_fingers:" => "🤌",
    "\\:pinching_hand:" => "🤏",
    "\\:pineapple:" => "🍍",
    "\\:pisces:" => "♓",
    "\\:pizza:" => "🍕",
    "\\:placard:" => "🪧",
    "\\:place_of_worship:" => "🛐",
    "\\:pleading_face:" => "🥺",
    "\\:plunger:" => "🪠",
    "\\:point_down:" => "👇",
    "\\:point_left:" => "👈",
    "\\:point_right:" => "👉",
    "\\:point_up:" => "☝",
    "\\:point_up_2:" => "👆",
    "\\:police_car:" => "🚓",
    "\\:poodle:" => "🐩",
    "\\:popcorn:" => "🍿",
    "\\:post_office:" => "🏣",
    "\\:postal_horn:" => "📯",
    "\\:postbox:" => "📮",
    "\\:potable_water:" => "🚰",
    "\\:potato:" => "🥔",
    "\\:potted_plant:" => "🪴",
    "\\:pouch:" => "👝",
    "\\:poultry_leg:" => "🍗",
    "\\:pound:" => "💷",
    "\\:pouting_cat:" => "😾",
    "\\:pray:" => "🙏",
    "\\:prayer_beads:" => "📿",
    "\\:pregnant_woman:" => "🤰",
    "\\:pretzel:" => "🥨",
    "\\:prince:" => "🤴",
    "\\:princess:" => "👸",
    "\\:probing_cane:" => "🦯",
    "\\:purple_heart:" => "💜",
    "\\:purse:" => "👛",
    "\\:pushpin:" => "📌",
    "\\:put_litter_in_its_place:" => "🚮",
    "\\:question:" => "❓",
    "\\:rabbit2:" => "🐇",
    "\\:rabbit:" => "🐰",
    "\\:raccoon:" => "🦝",
    "\\:racehorse:" => "🐎",
    "\\:radio:" => "📻",
    "\\:radio_button:" => "🔘",
    "\\:rage:" => "😡",
    "\\:railway_car:" => "🚃",
    "\\:rainbow:" => "🌈",
    "\\:raised_back_of_hand:" => "🤚",
    "\\:raised_hands:" => "🙌",
    "\\:raising_hand:" => "🙋",
    "\\:ram:" => "🐏",
    "\\:ramen:" => "🍜",
    "\\:rat:" => "🐀",
    "\\:razor:" => "🪒",
    "\\:receipt:" => "🧾",
    "\\:recycle:" => "♻",
    "\\:red_circle:" => "🔴",
    "\\:red_envelope:" => "🧧",
    "\\:registered:" => "®",
    "\\:relaxed:" => "☺",
    "\\:relieved:" => "😌",
    "\\:repeat:" => "🔁",
    "\\:repeat_one:" => "🔂",
    "\\:restroom:" => "🚻",
    "\\:revolving_hearts:" => "💞",
    "\\:rewind:" => "⏪",
    "\\:rhinoceros:" => "🦏",
    "\\:ribbon:" => "🎀",
    "\\:rice:" => "🍚",
    "\\:rice_ball:" => "🍙",
    "\\:rice_cracker:" => "🍘",
    "\\:rice_scene:" => "🎑",
    "\\:right-facing_fist:" => "🤜",
    "\\:ring:" => "💍",
    "\\:ringed_planet:" => "🪐",
    "\\:robot_face:" => "🤖",
    "\\:rock:" => "🪨",
    "\\:rocket:" => "🚀",
    "\\:roll_of_paper:" => "🧻",
    "\\:roller_coaster:" => "🎢",
    "\\:roller_skate:" => "🛼",
    "\\:rolling_on_the_floor_laughing:" => "🤣",
    "\\:rooster:" => "🐓",
    "\\:rose:" => "🌹",
    "\\:rotating_light:" => "🚨",
    "\\:round_pushpin:" => "📍",
    "\\:rowboat:" => "🚣",
    "\\:rugby_football:" => "🏉",
    "\\:runner:" => "🏃",
    "\\:running_shirt_with_sash:" => "🎽",
    "\\:sa:" => "🈂",
    "\\:safety_pin:" => "🧷",
    "\\:safety_vest:" => "🦺",
    "\\:sagittarius:" => "♐",
    "\\:sake:" => "🍶",
    "\\:salt:" => "🧂",
    "\\:sandal:" => "👡",
    "\\:sandwich:" => "🥪",
    "\\:santa:" => "🎅",
    "\\:sari:" => "🥻",
    "\\:satellite:" => "📡",
    "\\:satellite_antenna:" => "📡",
    "\\:sauropod:" => "🦕",
    "\\:saxophone:" => "🎷",
    "\\:scarf:" => "🧣",
    "\\:school:" => "🏫",
    "\\:school_satchel:" => "🎒",
    "\\:scissors:" => "✂",
    "\\:scooter:" => "🛴",
    "\\:scorpion:" => "🦂",
    "\\:scorpius:" => "♏",
    "\\:scream:" => "😱",
    "\\:scream_cat:" => "🙀",
    "\\:screwdriver:" => "🪛",
    "\\:scroll:" => "📜",
    "\\:seal:" => "🦭",
    "\\:seat:" => "💺",
    "\\:second_place_medal:" => "🥈",
    "\\:secret:" => "㊙",
    "\\:see_no_evil:" => "🙈",
    "\\:seedling:" => "🌱",
    "\\:selfie:" => "🤳",
    "\\:sewing_needle:" => "🪡",
    "\\:shallow_pan_of_food:" => "🥘",
    "\\:shark:" => "🦈",
    "\\:shaved_ice:" => "🍧",
    "\\:sheep:" => "🐑",
    "\\:shell:" => "🐚",
    "\\:ship:" => "🚢",
    "\\:shirt:" => "👕",
    "\\:shopping_trolley:" => "🛒",
    "\\:shorts:" => "🩳",
    "\\:shower:" => "🚿",
    "\\:shrimp:" => "🦐",
    "\\:shrug:" => "🤷",
    "\\:shushing_face:" => "🤫",
    "\\:signal_strength:" => "📶",
    "\\:six_pointed_star:" => "🔯",
    "\\:skateboard:" => "🛹",
    "\\:ski:" => "🎿",
    "\\:skin-tone-2:" => "🏻",
    "\\:skin-tone-3:" => "🏼",
    "\\:skin-tone-4:" => "🏽",
    "\\:skin-tone-5:" => "🏾",
    "\\:skin-tone-6:" => "🏿",
    "\\:skull:" => "💀",
    "\\:skunk:" => "🦨",
    "\\:sled:" => "🛷",
    "\\:sleeping:" => "😴",
    "\\:sleeping_accommodation:" => "🛌",
    "\\:sleepy:" => "😪",
    "\\:slightly_frowning_face:" => "🙁",
    "\\:slightly_smiling_face:" => "🙂",
    "\\:slot_machine:" => "🎰",
    "\\:sloth:" => "🦥",
    "\\:small_blue_diamond:" => "🔹",
    "\\:small_orange_diamond:" => "🔸",
    "\\:small_red_triangle:" => "🔺",
    "\\:small_red_triangle_down:" => "🔻",
    "\\:smile:" => "😄",
    "\\:smile_cat:" => "😸",
    "\\:smiley:" => "😃",
    "\\:smiley_cat:" => "😺",
    "\\:smiling_face_with_3_hearts:" => "🥰",
    "\\:smiling_face_with_tear:" => "🥲",
    "\\:smiling_imp:" => "😈",
    "\\:smirk:" => "😏",
    "\\:smirk_cat:" => "😼",
    "\\:smoking:" => "🚬",
    "\\:snail:" => "🐌",
    "\\:snake:" => "🐍",
    "\\:sneezing_face:" => "🤧",
    "\\:snowboarder:" => "🏂",
    "\\:snowflake:" => "❄",
    "\\:snowman:" => "⛄",
    "\\:snowman_without_snow:" => "⛄",
    "\\:soap:" => "🧼",
    "\\:sob:" => "😭",
    "\\:soccer:" => "⚽",
    "\\:socks:" => "🧦",
    "\\:softball:" => "🥎",
    "\\:soon:" => "🔜",
    "\\:sos:" => "🆘",
    "\\:sound:" => "🔉",
    "\\:space_invader:" => "👾",
    "\\:spades:" => "♠",
    "\\:spaghetti:" => "🍝",
    "\\:sparkle:" => "❇",
    "\\:sparkler:" => "🎇",
    "\\:sparkles:" => "✨",
    "\\:sparkling_heart:" => "💖",
    "\\:speak_no_evil:" => "🙊",
    "\\:speaker:" => "🔈",
    "\\:speech_balloon:" => "💬",
    "\\:speedboat:" => "🚤",
    "\\:spock-hand:" => "🖖",
    "\\:sponge:" => "🧽",
    "\\:spoon:" => "🥄",
    "\\:sports_medal:" => "🏅",
    "\\:squid:" => "🦑",
    "\\:standing_person:" => "🧍",
    "\\:star-struck:" => "🤩",
    "\\:star2:" => "🌟",
    "\\:star:" => "⭐",
    "\\:stars:" => "🌠",
    "\\:station:" => "🚉",
    "\\:statue_of_liberty:" => "🗽",
    "\\:steam_locomotive:" => "🚂",
    "\\:stethoscope:" => "🩺",
    "\\:stew:" => "🍲",
    "\\:straight_ruler:" => "📏",
    "\\:strawberry:" => "🍓",
    "\\:stuck_out_tongue:" => "😛",
    "\\:stuck_out_tongue_closed_eyes:" => "😝",
    "\\:stuck_out_tongue_winking_eye:" => "😜",
    "\\:stuffed_flatbread:" => "🥙",
    "\\:sun_with_face:" => "🌞",
    "\\:sunflower:" => "🌻",
    "\\:sunglasses:" => "😎",
    "\\:sunny:" => "☀",
    "\\:sunrise:" => "🌅",
    "\\:sunrise_over_mountains:" => "🌄",
    "\\:superhero:" => "🦸",
    "\\:supervillain:" => "🦹",
    "\\:surfer:" => "🏄",
    "\\:sushi:" => "🍣",
    "\\:suspension_railway:" => "🚟",
    "\\:swan:" => "🦢",
    "\\:sweat:" => "😓",
    "\\:sweat_drops:" => "💦",
    "\\:sweat_smile:" => "😅",
    "\\:sweet_potato:" => "🍠",
    "\\:swimmer:" => "🏊",
    "\\:symbols:" => "🔣",
    "\\:synagogue:" => "🕍",
    "\\:syringe:" => "💉",
    "\\:t-rex:" => "🦖",
    "\\:table_tennis_paddle_and_ball:" => "🏓",
    "\\:taco:" => "🌮",
    "\\:tada:" => "🎉",
    "\\:takeout_box:" => "🥡",
    "\\:tamale:" => "🫔",
    "\\:tanabata_tree:" => "🎋",
    "\\:tangerine:" => "🍊",
    "\\:taurus:" => "♉",
    "\\:taxi:" => "🚕",
    "\\:tea:" => "🍵",
    "\\:teapot:" => "🫖",
    "\\:teddy_bear:" => "🧸",
    "\\:telephone_receiver:" => "📞",
    "\\:telescope:" => "🔭",
    "\\:tennis:" => "🎾",
    "\\:tent:" => "⛺",
    "\\:test_tube:" => "🧪",
    "\\:the_horns:" => "🤘",
    "\\:thinking_face:" => "🤔",
    "\\:third_place_medal:" => "🥉",
    "\\:thong_sandal:" => "🩴",
    "\\:thought_balloon:" => "💭",
    "\\:thread:" => "🧵",
    "\\:ticket:" => "🎫",
    "\\:tiger2:" => "🐅",
    "\\:tiger:" => "🐯",
    "\\:tired_face:" => "😫",
    "\\:tm:" => "™",
    "\\:toilet:" => "🚽",
    "\\:tokyo_tower:" => "🗼",
    "\\:tomato:" => "🍅",
    "\\:tongue:" => "👅",
    "\\:toolbox:" => "🧰",
    "\\:tooth:" => "🦷",
    "\\:toothbrush:" => "🪥",
    "\\:top:" => "🔝",
    "\\:tophat:" => "🎩",
    "\\:tractor:" => "🚜",
    "\\:traffic_light:" => "🚥",
    "\\:train2:" => "🚆",
    "\\:train:" => "🚋",
    "\\:tram:" => "🚊",
    "\\:triangular_flag_on_post:" => "🚩",
    "\\:triangular_ruler:" => "📐",
    "\\:trident:" => "🔱",
    "\\:triumph:" => "😤",
    "\\:trolleybus:" => "🚎",
    "\\:trophy:" => "🏆",
    "\\:tropical_drink:" => "🍹",
    "\\:tropical_fish:" => "🐠",
    "\\:truck:" => "🚚",
    "\\:trumpet:" => "🎺",
    "\\:tulip:" => "🌷",
    "\\:tumbler_glass:" => "🥃",
    "\\:turkey:" => "🦃",
    "\\:turtle:" => "🐢",
    "\\:tv:" => "📺",
    "\\:twisted_rightwards_arrows:" => "🔀",
    "\\:two_hearts:" => "💕",
    "\\:two_men_holding_hands:" => "👬",
    "\\:two_women_holding_hands:" => "👭",
    "\\:u5272:" => "🈹",
    "\\:u5408:" => "🈴",
    "\\:u55b6:" => "🈺",
    "\\:u6307:" => "🈯",
    "\\:u6708:" => "🈷",
    "\\:u6709:" => "🈶",
    "\\:u6e80:" => "🈵",
    "\\:u7121:" => "🈚",
    "\\:u7533:" => "🈸",
    "\\:u7981:" => "🈲",
    "\\:u7a7a:" => "🈳",
    "\\:umbrella:" => "☔",
    "\\:umbrella_with_rain_drops:" => "☔",
    "\\:unamused:" => "😒",
    "\\:underage:" => "🔞",
    "\\:unicorn_face:" => "🦄",
    "\\:unlock:" => "🔓",
    "\\:up:" => "🆙",
    "\\:upside_down_face:" => "🙃",
    "\\:v:" => "✌",
    "\\:vampire:" => "🧛",
    "\\:vertical_traffic_light:" => "🚦",
    "\\:vhs:" => "📼",
    "\\:vibration_mode:" => "📳",
    "\\:video_camera:" => "📹",
    "\\:video_game:" => "🎮",
    "\\:violin:" => "🎻",
    "\\:virgo:" => "♍",
    "\\:volcano:" => "🌋",
    "\\:volleyball:" => "🏐",
    "\\:vs:" => "🆚",
    "\\:waffle:" => "🧇",
    "\\:walking:" => "🚶",
    "\\:waning_crescent_moon:" => "🌘",
    "\\:waning_gibbous_moon:" => "🌖",
    "\\:warning:" => "⚠",
    "\\:watch:" => "⌚",
    "\\:water_buffalo:" => "🐃",
    "\\:water_polo:" => "🤽",
    "\\:watermelon:" => "🍉",
    "\\:wave:" => "👋",
    "\\:waving_black_flag:" => "🏴",
    "\\:wavy_dash:" => "〰",
    "\\:waxing_crescent_moon:" => "🌒",
    "\\:wc:" => "🚾",
    "\\:weary:" => "😩",
    "\\:wedding:" => "💒",
    "\\:whale2:" => "🐋",
    "\\:whale:" => "🐳",
    "\\:wheelchair:" => "♿",
    "\\:white_check_mark:" => "✅",
    "\\:white_circle:" => "⚪",
    "\\:white_flower:" => "💮",
    "\\:white_heart:" => "🤍",
    "\\:white_large_square:" => "⬜",
    "\\:white_medium_small_square:" => "◽",
    "\\:white_medium_square:" => "◻",
    "\\:white_small_square:" => "▫",
    "\\:white_square_button:" => "🔳",
    "\\:wilted_flower:" => "🥀",
    "\\:wind_chime:" => "🎐",
    "\\:window:" => "🪟",
    "\\:wine_glass:" => "🍷",
    "\\:wink:" => "😉",
    "\\:wolf:" => "🐺",
    "\\:woman:" => "👩",
    "\\:womans_clothes:" => "👚",
    "\\:womans_flat_shoe:" => "🥿",
    "\\:womans_hat:" => "👒",
    "\\:womens:" => "🚺",
    "\\:wood:" => "🪵",
    "\\:woozy_face:" => "🥴",
    "\\:worm:" => "🪱",
    "\\:worried:" => "😟",
    "\\:wrench:" => "🔧",
    "\\:wrestlers:" => "🤼",
    "\\:x:" => "❌",
    "\\:yarn:" => "🧶",
    "\\:yawning_face:" => "🥱",
    "\\:yellow_heart:" => "💛",
    "\\:yen:" => "💴",
    "\\:yo-yo:" => "🪀",
    "\\:yum:" => "😋",
    "\\:zany_face:" => "🤪",
    "\\:zap:" => "⚡",
    "\\:zebra_face:" => "🦓",
    "\\:zipper_mouth_face:" => "🤐",
    "\\:zombie:" => "🧟",
    "\\:zzz:" => "💤",
)
