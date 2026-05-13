import Foundation

// MARK: - Derivative Category Mapper
/// Utility for mapping derivative category strings to display names
struct DerivativeCategoryMapper {

    static func mapCategory(_ category: String) -> String {
        let lowercasedCategory = category.lowercased()
        return self.categoryMappings[lowercasedCategory] ?? category.capitalized
    }

    // MARK: - Category Mappings

    private static let categoryMappings: [String: String] = [
        // Basic Options
        "call": "Call",
        "put": "Put",
        "knockout": "Knockout",
        "discount": "Discount",
        "bonus": "Bonus",
        "express": "Express",
        "turbos": "Turbos",
        "sprinters": "Sprinters",
        "flex": "Flex",
        "airbag": "Airbag",
        "capped": "Capped",
        "outperformance": "Outperformance",
        "revers": "Reverse",
        "factor": "Factor",
        "barrier": "Barrier",
        "touch": "Touch",

        // Structured Products
        "rainbow": "Rainbow",
        "basket": "Basket",
        "best-of": "Best-of",
        "worst-of": "Worst-of",
        "best-of-rainbow": "Best-of Rainbow",
        "worst-of-rainbow": "Worst-of Rainbow",
        "alpine": "Alpine",
        "himalaya": "Himalaya",
        "atlas": "Atlas",
        "everest": "Everest",
        "kilimanjaro": "Kilimanjaro",
        "annapurna": "Annapurna",
        "k2": "K2",
        "matterhorn": "Matterhorn",
        "mont-blanc": "Mont Blanc",
        "elbrus": "Elbrus",
        "aconcagua": "Aconcagua",
        "denali": "Denali",
        "logan": "Logan",

        // Complex Options
        "spread": "Spread",
        "straddle": "Straddle",
        "strangle": "Strangle",
        "butterfly": "Butterfly",
        "condor": "Condor",
        "iron": "Iron",
        "collar": "Collar",
        "fence": "Fence",
        "seagull": "Seagull",
        "jade": "Jade",
        "lizard": "Lizard",
        "twin": "Twin",
        "twin-win": "Twin-Win",

        // Exotic Options
        "snowball": "Snowball",
        "autocall": "Autocall",
        "phoenix": "Phoenix",
        "memory": "Memory",
        "lookback": "Lookback",
        "asian": "Asian",
        "american": "American",
        "european": "European",
        "bermudan": "Bermudan",
        "canary": "Canary",
        "cliquet": "Cliquet",
        "ratchet": "Ratchet",
        "ladder": "Ladder",
        "target": "Target",
        "target-redemption": "Target Redemption",
        "range": "Range",
        "digital": "Digital",
        "binary": "Binary",
        "gap": "Gap",
        "step": "Step",
        "power": "Power",
        "quanto": "Quanto",
        "compo": "Compo",

        // Mountain Products (Mexican Volcanoes)
        "citlaltepetl": "Citlaltepetl",
        "pico-de-orizaba": "Pico de Orizaba",
        "iztaccihuatl": "Iztaccihuatl",
        "popocatepetl": "Popocatepetl",
        "nevado-de-toluca": "Nevado de Toluca",
        "la-malinche": "La Malinche",
        "nevado-de-colima": "Nevado de Colima",
        "volcan-de-colima": "Volcan de Colima",
        "paricutin": "Paricutin",
        "el-chichon": "El Chichon",

        // Volcano Products (Central American Volcanoes)
        "tacana": "Tacana",
        "tajumulco": "Tajumulco",
        "santa-maria": "Santa Maria",
        "santiaguito": "Santiaguito",
        "fuego": "Fuego",
        "acatenango": "Acatenango",
        "agua": "Agua",
        "pacaya": "Pacaya",
        "izalco": "Izalco",
        "san-miguel": "San Miguel",
        "conchagua": "Conchagua",
        "san-cristobal": "San Cristobal",
        "casita": "Casita",
        "momotombo": "Momotombo",
        "cerro-negro": "Cerro Negro",
        "masaya": "Masaya",
        "mombacho": "Mombacho",
        "concepcion": "Concepcion",
        "maderas": "Maderas",
        "cosiguina": "Cosiguina",
        "san-jacinto": "San Jacinto",
        "telica": "Telica",
        "santa-clara": "Santa Clara",
        "pilas": "Pilas",
        "el-hoyo": "El Hoyo",
        "apoyo": "Apoyo",
        "xiloa": "Xiloa",
        "asososca": "Asososca",
        "negrra": "Negrra",
        "apoyeque": "Apoyeque",
        "jiloa": "Jiloa",
        "xiloá": "Xiloá"
    ]
}
