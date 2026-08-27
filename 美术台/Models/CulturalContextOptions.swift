import Foundation

struct PromptParameterOptionRecord: Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let promptToken: String
}

extension PromptParameter {
    /// Covers the 193 United Nations member states plus the two permanent
    /// observer states. Display names come from Foundation locale data while
    /// prompt values remain stable English country names.
    static let nationalityOptionRecords: [PromptParameterOptionRecord] = {
        let countryCodes = """
        AF AL DZ AD AO AG AR AM AU AT AZ BS BH BD BB BY BE BZ BJ BT BO BA BW BR BN BG BF BI CV KH CM CA CF TD CL CN CO KM CG CD CR CI HR CU CY CZ DK DJ DM DO EC EG SV GQ ER EE SZ ET FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IR IQ IE IL IT JM JP JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MG MW MY MV ML MT MH MR MU MX FM MD MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PG PY PE PH PL PT QA RO RU RW KN LC VC WS SM ST SA SN RS SC SL SG SK SI SB SO ZA SS ES LK SD SR SE CH SY TJ TZ TH TL TG TO TT TN TR TM TV UG UA AE GB US UY UZ VU VA VE VN YE ZM ZW PS
        """
        .split(whereSeparator: \.isWhitespace)
        .map(String.init)

        let chineseLocale = Locale(identifier: "zh-Hans")
        let englishLocale = Locale(identifier: "en_US_POSIX")
        let overrides = [
            "PS": ("巴勒斯坦国", "Palestine"),
            "VA": ("梵蒂冈", "Vatican City")
        ]

        let countries = countryCodes.map { code in
            let chineseName = overrides[code]?.0
                ?? chineseLocale.localizedString(forRegionCode: code)
                ?? code
            let localizedEnglishName = overrides[code]?.1
                ?? englishLocale.localizedString(forRegionCode: code)
                ?? code
            let latinName = localizedEnglishName
                .applyingTransform(.toLatin, reverse: false)?
                .applyingTransform(.stripDiacritics, reverse: false)
                ?? localizedEnglishName
            let englishName = String(latinName.unicodeScalars.filter { $0.value < 128 })

            return PromptParameterOptionRecord(
                id: code.lowercased(),
                title: chineseName,
                detail: "联合国会员国或观察员国 · ISO 3166-1：\(code)",
                promptToken: "nationality or national origin: \(englishName), culturally specific identity details only when supported by the script, no stereotypical features"
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return [
            PromptParameterOptionRecord(
                id: "none",
                title: "无",
                detail: "不指定国籍或国家归属",
                promptToken: ""
            )
        ] + countries
    }()

    /// Global chronology combines broad cross-regional periods with major
    /// civilization-specific eras so art direction is not forced into a
    /// Europe-only or China-only periodization.
    static let historicalEraOptionRecords: [PromptParameterOptionRecord] = [
        record("none", "无", "不指定时代或文明", ""),
        record("paleolithic", "旧石器时代", "约公元前 330 万年—前 1 万年 · 全球", "Paleolithic era material culture and historically appropriate lifeways"),
        record("neolithic", "新石器时代", "约公元前 1 万年—前 3000 年 · 各地时间不同", "Neolithic era settlement, craft, clothing and material culture appropriate to the selected region"),
        record("bronze-age", "青铜时代", "约公元前 3300—前 1200 年 · 各地时间不同", "Bronze Age material culture, technology, clothing and built environment appropriate to the selected region"),
        record("iron-age", "铁器时代", "约公元前 1200 年起 · 各地时间不同", "Iron Age material culture, technology, clothing and architecture appropriate to the selected region"),
        record("classical-antiquity", "古典时代", "约公元前 8 世纪—公元 5 世纪 · 地中海与相邻区域", "Classical antiquity with historically accurate regional clothing, architecture and material culture"),
        record("late-antiquity", "古代晚期", "约 3—8 世纪 · 欧亚与地中海", "Late Antiquity visual culture with regionally accurate dress, objects and architecture"),
        record("early-medieval-global", "全球中世纪早期", "约 5—10 世纪 · 需结合具体地区", "early medieval period with region-specific dress, technology, architecture and material culture"),
        record("high-medieval-global", "全球中世纪中期", "约 10—13 世纪 · 需结合具体地区", "high medieval period with region-specific dress, technology, architecture and material culture"),
        record("late-medieval-global", "全球中世纪晚期", "约 13—15 世纪 · 需结合具体地区", "late medieval period with region-specific dress, technology, architecture and material culture"),
        record("early-modern-global", "全球近世 / 早期现代", "约 1500—1800 年", "early modern era with globally and regionally accurate clothing, trade goods, technology and architecture"),
        record("industrial-19c", "工业化十九世纪", "约 1800—1900 年 · 地区进程不同", "nineteenth-century industrial era with regionally accurate dress, technology, transport and built environment"),
        record("belle-epoque", "美好年代 / 镀金时代", "约 1870—1914 年 · 欧美城市语境", "Belle Epoque and Gilded Age visual culture, circa 1870s to 1914, with historically accurate fashion and technology"),
        record("interwar", "两次世界大战之间", "1918—1939 年", "interwar period, 1918 to 1939, with historically accurate regional fashion, objects, vehicles and architecture"),
        record("world-war-ii", "第二次世界大战时期", "1939—1945 年", "World War II era, 1939 to 1945, with historically accurate civilian or military material culture as supported by the script"),
        record("postwar-1945-1969", "战后 1945—1969", "战后重建、现代主义与大众文化", "postwar 1945 to 1969 visual culture with regionally accurate fashion, technology, interiors and streets"),
        record("1970s", "1970 年代", "全球地区化七十年代视觉文化", "1970s period-accurate fashion, hair, objects, vehicles, interiors and graphic design"),
        record("1980s", "1980 年代", "全球地区化八十年代视觉文化", "1980s period-accurate fashion, hair, objects, vehicles, interiors and graphic design"),
        record("1990s", "1990 年代", "全球地区化九十年代视觉文化", "1990s period-accurate fashion, hair, objects, vehicles, interiors and technology"),
        record("2000s", "2000 年代", "2000—2009 年", "2000s period-accurate fashion, objects, vehicles, interiors and consumer technology"),
        record("2010s", "2010 年代", "2010—2019 年", "2010s period-accurate fashion, objects, vehicles, interiors and consumer technology"),
        record("2020s", "2020 年代", "2020 年至今", "2020s contemporary fashion, objects, vehicles, interiors and technology"),

        record("mesopotamian", "古代美索不达米亚", "苏美尔、阿卡德、巴比伦与亚述语境", "ancient Mesopotamian civilization with historically accurate Sumerian, Akkadian, Babylonian or Assyrian material culture as appropriate"),
        record("ancient-egypt", "古埃及", "前王朝至托勒密时期，需按剧本细分", "ancient Egyptian civilization with dynasty-appropriate clothing, regalia, objects and architecture"),
        record("achaemenid-persia", "阿契美尼德波斯", "约公元前 550—330 年", "Achaemenid Persian era with historically accurate court dress, military equipment, objects and architecture"),
        record("hellenistic", "希腊化时代", "公元前 323—31 年", "Hellenistic era with regionally accurate clothing, objects, sculpture and architecture"),
        record("roman", "古罗马", "共和国晚期至帝国时期，需按剧本细分", "ancient Roman era with period-accurate clothing, social rank, objects and architecture"),
        record("byzantine", "拜占庭时代", "约 4—15 世纪", "Byzantine era with historically accurate court, civic or religious dress, objects and architecture"),
        record("islamic-golden-age", "伊斯兰黄金时代", "约 8—13 世纪 · 跨西亚、北非与中亚", "Islamic Golden Age visual culture with regionally accurate textiles, dress, scholarship objects and architecture"),
        record("ottoman", "奥斯曼时代", "约 14 世纪末—1922 年，需按世纪细分", "Ottoman era with century-appropriate clothing, court culture, objects and architecture"),

        record("shang-zhou", "中国商周", "约公元前 1600—前 256 年", "Shang and Zhou dynasty China with historically accurate bronze culture, dress, ritual objects and architecture"),
        record("qin-han", "中国秦汉", "公元前 221—公元 220 年", "Qin and Han dynasty China with historically accurate clothing, armor, objects and architecture"),
        record("six-dynasties", "中国魏晋南北朝", "220—589 年", "Wei Jin and Northern and Southern Dynasties China with historically accurate dress, objects and architecture"),
        record("sui-tang", "中国隋唐", "581—907 年", "Sui and Tang dynasty China with historically accurate cosmopolitan dress, hair, objects and architecture"),
        record("song", "中国宋代", "960—1279 年", "Song dynasty China with historically accurate clothing, urban material culture, objects and architecture"),
        record("yuan", "中国元代", "1271—1368 年", "Yuan dynasty China with historically accurate multiethnic dress, objects, equestrian culture and architecture"),
        record("ming", "中国明代", "1368—1644 年", "Ming dynasty China with rank-appropriate clothing, hair, objects, craft and architecture"),
        record("qing", "中国清代", "1644—1912 年", "Qing dynasty China with reign- and status-appropriate clothing, hair, objects and architecture"),
        record("republican-china", "中华民国大陆时期", "1912—1949 年", "Republican-era China, 1912 to 1949, with period-accurate regional fashion, streets, objects and architecture"),

        record("jomon-yayoi", "日本绳文—弥生", "约公元前 14000 年—公元 3 世纪", "Jomon or Yayoi Japan with phase-appropriate clothing, pottery, settlement and material culture"),
        record("heian", "日本平安时代", "794—1185 年", "Heian-period Japan with rank-appropriate court or common dress, objects and architecture"),
        record("kamakura-muromachi", "日本镰仓—室町", "1185—1573 年", "Kamakura or Muromachi Japan with historically accurate dress, armor, objects and architecture"),
        record("edo", "日本江户时代", "1603—1868 年", "Edo-period Japan with class- and decade-appropriate clothing, hair, objects, streets and architecture"),
        record("meiji-taisho", "日本明治—大正", "1868—1926 年", "Meiji or Taisho Japan with period-accurate hybrid fashion, technology, objects and architecture"),
        record("showa", "日本昭和时代", "1926—1989 年，需按年代细分", "Showa-era Japan with decade-appropriate fashion, technology, objects and architecture"),
        record("korean-three-kingdoms", "朝鲜半岛三国时期", "约公元前 1 世纪—公元 7 世纪", "Korean Three Kingdoms period with kingdom- and status-appropriate dress, objects and architecture"),
        record("goryeo", "高丽时代", "918—1392 年", "Goryeo-era Korea with historically accurate clothing, celadon, objects and architecture"),
        record("joseon", "朝鲜王朝", "1392—1910 年", "Joseon-era Korea with rank-, gender- and century-appropriate clothing, hair, objects and architecture"),

        record("indus", "印度河文明", "约公元前 2600—前 1900 年", "Indus Valley civilization with archaeologically grounded clothing, ornaments, objects and urban architecture"),
        record("vedic-mahajanapada", "南亚吠陀—列国时期", "约公元前 1500—前 321 年", "Vedic and Mahajanapada South Asia with historically grounded regional dress, objects and settlement culture"),
        record("maurya-gupta", "南亚孔雀—笈多时代", "约公元前 322—公元 550 年", "Maurya or Gupta era South Asia with period-appropriate clothing, jewelry, objects and architecture"),
        record("delhi-sultanate", "德里苏丹国时期", "1206—1526 年", "Delhi Sultanate era with historically accurate regional dress, arms, objects and architecture"),
        record("mughal", "莫卧儿时代", "1526—1857 年", "Mughal era with reign- and status-appropriate clothing, jewelry, objects, gardens and architecture"),
        record("british-raj", "英属印度时期", "1858—1947 年", "British Raj era with region-, class- and decade-appropriate South Asian dress, objects and architecture"),

        record("angkor-khmer", "高棉帝国 / 吴哥时代", "约 802—1431 年", "Khmer Empire and Angkor era with historically accurate regional dress, regalia, objects and architecture"),
        record("srivijaya-majapahit", "室利佛逝—满者伯夷", "约 7—16 世纪 · 海岛东南亚", "Srivijaya or Majapahit maritime Southeast Asia with historically accurate textiles, jewelry, objects, ships and architecture"),
        record("early-modern-se-asia", "东南亚近世王国", "约 16—19 世纪", "early modern Southeast Asian court or community culture with kingdom-specific dress, objects and architecture"),
        record("colonial-se-asia", "东南亚殖民时期", "约 19 世纪—20 世纪中叶 · 地区不同", "colonial-era Southeast Asia with territory- and decade-appropriate local dress, objects, transport and architecture"),

        record("kush-aksum", "库施—阿克苏姆时代", "约公元前 8 世纪—公元 7 世纪 · 东北非", "Kushite or Aksumite era with historically grounded regional dress, objects, trade culture and architecture"),
        record("west-african-empires", "西非帝国时代", "加纳、马里、桑海等，约 8—16 世纪", "medieval West African empire visual culture with polity-, status- and trade-appropriate dress, objects and architecture"),
        record("swahili-city-states", "斯瓦希里城邦时代", "约 10—16 世纪 · 东非海岸", "Swahili city-state culture with historically accurate coastal dress, trade goods, objects and architecture"),
        record("ethiopian-imperial", "埃塞俄比亚帝国传统", "约 13—20 世纪，需按时期细分", "Ethiopian imperial era with period-, region- and status-appropriate clothing, objects and architecture"),
        record("africa-16th-18th", "非洲 16—18 世纪", "按具体王国与地区细分", "sixteenth- to eighteenth-century African visual culture specific to the selected polity and region"),
        record("africa-19th-precolonial", "非洲十九世纪前殖民语境", "十九世纪至约 1880 年", "nineteenth-century African visual culture before colonial domination, specific to the selected polity and region"),
        record("africa-colonial", "非洲殖民统治时期", "约 1880—1935 年 · 地区不同", "African colonial era, circa 1880 to 1935, with regionally accurate local and colonial material culture"),
        record("africa-independence", "非洲独立运动时期", "约 1935—1970 年代 · 国家不同", "African independence era with country- and decade-appropriate fashion, objects, streets and political visual culture"),

        record("mesoamerican-preclassic", "中部美洲前古典期", "约公元前 2000 年—公元 250 年", "Mesoamerican Preclassic period with culture-specific clothing, objects, settlement and ceremonial architecture"),
        record("classic-maya", "古典玛雅", "约 250—900 年", "Classic Maya era with rank- and city-appropriate clothing, regalia, objects and architecture"),
        record("aztec", "阿兹特克时代", "约 1300—1521 年", "Aztec era with status-appropriate clothing, regalia, objects, markets and architecture"),
        record("andean-preinca", "前印加安第斯文明", "约公元前 3000 年—公元 1400 年，需按文化细分", "pre-Inca Andean civilization with culture-specific textiles, clothing, objects and architecture"),
        record("inca", "印加时代", "约 1438—1533 年", "Inca era with status- and region-appropriate textiles, clothing, objects, roads and architecture"),
        record("north-america-precontact", "北美原住民前接触时期", "欧洲殖民前，必须按具体民族与地区细分", "pre-contact Indigenous North America with nation- and region-specific clothing, objects, dwellings and lifeways, avoiding pan-Indigenous stereotypes"),
        record("colonial-americas", "美洲殖民时期", "约 16—18 世纪 · 西、葡、英、法等殖民语境", "colonial Americas with territory-, community- and century-appropriate clothing, objects and architecture"),
        record("americas-19c", "美洲十九世纪", "独立、扩张与工业化并行，需按国家细分", "nineteenth-century Americas with country-, community- and decade-appropriate clothing, objects, transport and architecture"),

        record("aboriginal-australia-deep-time", "澳大利亚原住民深时传统", "殖民前，必须按具体族群与 Country 细分", "pre-colonial Aboriginal Australian visual culture specific to the named nation and Country, avoiding generic pan-Aboriginal imagery"),
        record("polynesian-voyaging", "波利尼西亚航海与前殖民时代", "殖民前太平洋岛屿，需按具体岛群细分", "pre-colonial Polynesian voyaging era with island-specific clothing, vessels, objects and architecture"),
        record("pacific-colonial", "太平洋殖民与接触时期", "约 18—20 世纪 · 岛群不同", "Pacific colonial and contact era with island-, community- and decade-appropriate clothing, objects, vessels and architecture")
    ]

    private static func record(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ promptToken: String
    ) -> PromptParameterOptionRecord {
        PromptParameterOptionRecord(
            id: id,
            title: title,
            detail: detail,
            promptToken: promptToken
        )
    }
}
