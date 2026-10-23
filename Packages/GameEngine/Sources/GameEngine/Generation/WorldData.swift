import Foundation

/// A playable country with one top division. All club and league names are fictional.
public struct CountryInfo: Codable, Hashable, Identifiable, Sendable {
    public var id: String { code }
    public let code: String
    public let leagueName: String
    public let strength: Double
    let clubs: [ClubSeed]
}

struct ClubSeed: Codable, Hashable, Sendable {
    let name: String
    let shortName: String
    let stadium: String
    let primary: String
    let secondary: String
}

enum WorldData {
    static let countries: [CountryInfo] = [turkey, england, spain, germany, italy, france, portugal, netherlands]

    // MARK: - Türkiye

    static let turkey = CountryInfo(code: "TR", leagueName: "Hilal Lig", strength: 0.88, clubs: [
        ClubSeed(name: "Boğaziçi Yıldız SK", shortName: "BYS", stadium: "Yıldız Arena", primary: "1B3A8C", secondary: "F2C230"),
        ClubSeed(name: "Haliç Atletik", shortName: "HAT", stadium: "Haliç Stadı", primary: "8C1B2F", secondary: "F5D76E"),
        ClubSeed(name: "Moda Rüzgarı FK", shortName: "MRF", stadium: "Moda Parkı", primary: "0F2A4A", secondary: "F6E04B"),
        ClubSeed(name: "Başkent Kartal SK", shortName: "BKS", stadium: "Kartal Yuvası", primary: "111111", secondary: "D9D9D9"),
        ClubSeed(name: "Ege Martıları", shortName: "EGM", stadium: "Kordon Stadı", primary: "1E6FB8", secondary: "FFFFFF"),
        ClubSeed(name: "Körfez Dalgası FK", shortName: "KDF", stadium: "Körfez Arena", primary: "0E7C7B", secondary: "F2F2F2"),
        ClubSeed(name: "Bursa Yeşil Vadi FK", shortName: "BYV", stadium: "Vadi Stadı", primary: "1F7A3A", secondary: "FFFFFF"),
        ClubSeed(name: "Akdeniz Güneşi FK", shortName: "AGF", stadium: "Güneş Park", primary: "D9481C", secondary: "FFFFFF"),
        ClubSeed(name: "Doğu Karadeniz Atletik", shortName: "DKA", stadium: "Yayla Stadı", primary: "5B1A6E", secondary: "3BA0D9"),
        ClubSeed(name: "Kapadokya Atlıları", shortName: "KAP", stadium: "Peri Bacası Arena", primary: "B5651D", secondary: "1A1A1A"),
        ClubSeed(name: "Çukurova Pamuk FK", shortName: "ÇPF", stadium: "Pamuk Stadı", primary: "F3F3F3", secondary: "1D5FA8"),
        ClubSeed(name: "Mezopotamya SK", shortName: "MZP", stadium: "Dicle Stadı", primary: "2E7D32", secondary: "C62828"),
        ClubSeed(name: "Selçuklu Yıldırım FK", shortName: "SYF", stadium: "Yıldırım Arena", primary: "1C8C4B", secondary: "FFFFFF"),
        ClubSeed(name: "Toros Kaplanları", shortName: "TOR", stadium: "Toros Stadı", primary: "E57C00", secondary: "1A1A1A"),
        ClubSeed(name: "Antep Fıstık FK", shortName: "AFF", stadium: "Fıstık Arena", primary: "7CB342", secondary: "C62828"),
        ClubSeed(name: "Sakarya Nehir FK", shortName: "SNF", stadium: "Nehir Stadı", primary: "26A69A", secondary: "1A1A1A"),
        ClubSeed(name: "Kızılırmak Atletik", shortName: "KZA", stadium: "Irmak Stadı", primary: "B71C1C", secondary: "FFFFFF"),
        ClubSeed(name: "Porsuk SK", shortName: "POR", stadium: "Porsuk Parkı", primary: "C62828", secondary: "1A1A1A")
    ])

    // MARK: - England

    static let england = CountryInfo(code: "EN", leagueName: "Albion Premier", strength: 1.0, clubs: [
        ClubSeed(name: "Thamesbury FC", shortName: "THA", stadium: "Riverside Park", primary: "C8102E", secondary: "FFFFFF"),
        ClubSeed(name: "Kingsport Royals", shortName: "KIN", stadium: "Crown Ground", primary: "1D3C8F", secondary: "FFFFFF"),
        ClubSeed(name: "Northbridge Ironmen", shortName: "NOR", stadium: "The Foundry", primary: "6C1D45", secondary: "7FB2E5"),
        ClubSeed(name: "Eastholm Harriers", shortName: "EAS", stadium: "Harrier Lane", primary: "132257", secondary: "FFFFFF"),
        ClubSeed(name: "Merseyvale FC", shortName: "MER", stadium: "Vale Park Road", primary: "00369C", secondary: "FFFFFF"),
        ClubSeed(name: "Ravenmoor Town", shortName: "RAV", stadium: "Moorside", primary: "1A1A1A", secondary: "F2C230"),
        ClubSeed(name: "Westcliff Mariners", shortName: "WES", stadium: "Harbour Road", primary: "00A3E0", secondary: "FFFFFF"),
        ClubSeed(name: "Old Hartley FC", shortName: "OHA", stadium: "Hartley Fields", primary: "2E7D32", secondary: "F2F2F2"),
        ClubSeed(name: "Blackwater Forge", shortName: "BLA", stadium: "The Anvil", primary: "333333", secondary: "E57C00"),
        ClubSeed(name: "Calderford FC", shortName: "CAL", stadium: "Calder Park", primary: "FDB913", secondary: "231F20"),
        ClubSeed(name: "Stonebury Saints", shortName: "STO", stadium: "St. Alden's", primary: "D71920", secondary: "FFFFFF"),
        ClubSeed(name: "Highgate Lions", shortName: "HIG", stadium: "Lion Lane", primary: "001489", secondary: "FFFFFF"),
        ClubSeed(name: "Wexmoor Rangers", shortName: "WEX", stadium: "Wexmoor Road", primary: "7A263A", secondary: "1BB1E7"),
        ClubSeed(name: "Fenwick Park FC", shortName: "FEN", stadium: "Fenwick Park", primary: "FFFFFF", secondary: "1A1A1A"),
        ClubSeed(name: "Ellsworth County", shortName: "ELL", stadium: "County Ground", primary: "6CABDD", secondary: "1C2C5B"),
        ClubSeed(name: "Brookhampton FC", shortName: "BRO", stadium: "The Brook", primary: "0057B8", secondary: "F2C230"),
        ClubSeed(name: "Redhill Foundry", shortName: "RED", stadium: "Foundry Lane", primary: "EF0107", secondary: "063672"),
        ClubSeed(name: "Silverdale Hornets", shortName: "SIL", stadium: "The Hive", primary: "FBEE23", secondary: "1A1A1A")
    ])

    // MARK: - Spain

    static let spain = CountryInfo(code: "ES", leagueName: "Liga Ibérica", strength: 0.98, clubs: [
        ClubSeed(name: "Real Montesol CF", shortName: "RMS", stadium: "Estadio del Sol", primary: "FFFFFF", secondary: "6A3FA0"),
        ClubSeed(name: "Atlético Valderrío", shortName: "AVR", stadium: "Ribera Arena", primary: "C8102E", secondary: "FFFFFF"),
        ClubSeed(name: "CD Puerto Azul", shortName: "PAZ", stadium: "Estadio del Puerto", primary: "1E6FB8", secondary: "FFFFFF"),
        ClubSeed(name: "Deportivo Castaño", shortName: "DCA", stadium: "Los Castaños", primary: "7B4A12", secondary: "F2C230"),
        ClubSeed(name: "UD Olivar", shortName: "OLI", stadium: "El Olivar", primary: "556B2F", secondary: "FFFFFF"),
        ClubSeed(name: "CF Murallas", shortName: "MUR", stadium: "La Muralla", primary: "A50044", secondary: "004D98"),
        ClubSeed(name: "Racing Bahía Clara", shortName: "RBC", stadium: "Bahía Arena", primary: "00A651", secondary: "FFFFFF"),
        ClubSeed(name: "SD Campo Verde", shortName: "SCV", stadium: "Campo Verde", primary: "2E7D32", secondary: "F2C230"),
        ClubSeed(name: "Unión Peñaroja", shortName: "UPR", stadium: "La Peña", primary: "B71C1C", secondary: "1A1A1A"),
        ClubSeed(name: "CD Llanura", shortName: "LLA", stadium: "Estadio Llano", primary: "F2C230", secondary: "1D3C8F"),
        ClubSeed(name: "Real Arenal", shortName: "RAR", stadium: "Los Arenales", primary: "1D3C8F", secondary: "FFFFFF"),
        ClubSeed(name: "Atlético Brisamar", shortName: "ABR", stadium: "Brisamar", primary: "00A3E0", secondary: "C8102E"),
        ClubSeed(name: "CF Cumbres", shortName: "CUM", stadium: "Las Cumbres", primary: "4A4A4A", secondary: "F2C230"),
        ClubSeed(name: "UD Ríoseco", shortName: "RSE", stadium: "Ribera Seca", primary: "E57C00", secondary: "1A1A1A"),
        ClubSeed(name: "Deportivo Faro Norte", shortName: "DFN", stadium: "El Faro", primary: "0F2A4A", secondary: "FFFFFF"),
        ClubSeed(name: "SD Alcornal", shortName: "ALC", stadium: "El Alcornal", primary: "6D4C41", secondary: "FFFFFF"),
        ClubSeed(name: "CF Viñaplata", shortName: "VIÑ", stadium: "La Viña", primary: "7B1FA2", secondary: "D9D9D9"),
        ClubSeed(name: "Racing Solmar", shortName: "SOL", stadium: "Solmar Park", primary: "FDB913", secondary: "00A3E0")
    ])

    // MARK: - Germany

    static let germany = CountryInfo(code: "DE", leagueName: "Bundesklasse", strength: 0.96, clubs: [
        ClubSeed(name: "FC Rheinfurt", shortName: "RHE", stadium: "Rheinfurt Arena", primary: "DC052D", secondary: "FFFFFF"),
        ClubSeed(name: "SV Nordhafen", shortName: "NOH", stadium: "Hafenstadion", primary: "1D3C8F", secondary: "FFFFFF"),
        ClubSeed(name: "TSV Grünwalde", shortName: "GRÜ", stadium: "Waldstadion Grün", primary: "1F7A3A", secondary: "FFFFFF"),
        ClubSeed(name: "1. FC Eichenberg", shortName: "EIC", stadium: "Eichenpark", primary: "8C1B2F", secondary: "F2F2F2"),
        ClubSeed(name: "VfB Steinhausen", shortName: "STE", stadium: "Steinarena", primary: "FFFFFF", secondary: "C8102E"),
        ClubSeed(name: "SC Mühlental", shortName: "MÜH", stadium: "Mühlenstadion", primary: "FDB913", secondary: "1A1A1A"),
        ClubSeed(name: "FSV Bergstadt", shortName: "BER", stadium: "Bergblick Arena", primary: "6C1D45", secondary: "FFFFFF"),
        ClubSeed(name: "Union Hafenstadt", shortName: "UHS", stadium: "Am Kai", primary: "C8102E", secondary: "F2C230"),
        ClubSeed(name: "Eintracht Talburg", shortName: "TAL", stadium: "Talburg Park", primary: "1A1A1A", secondary: "C8102E"),
        ClubSeed(name: "SpVgg Lindenau", shortName: "LIN", stadium: "Lindenstadion", primary: "2E7D32", secondary: "FFFFFF"),
        ClubSeed(name: "FC Silberau", shortName: "SIA", stadium: "Silberau Arena", primary: "9E9E9E", secondary: "1D3C8F"),
        ClubSeed(name: "TuS Wolfsheim", shortName: "WOL", stadium: "Wolfsgrube", primary: "65B32E", secondary: "FFFFFF"),
        ClubSeed(name: "SV Kranichfeld", shortName: "KRA", stadium: "Kranichstadion", primary: "00A3E0", secondary: "1A1A1A"),
        ClubSeed(name: "FC Donaustadt", shortName: "DON", stadium: "Donau Arena", primary: "1E6FB8", secondary: "F2C230"),
        ClubSeed(name: "Hansa Ostkamp", shortName: "HAN", stadium: "Ostkampbahn", primary: "0F2A4A", secondary: "FFFFFF"),
        ClubSeed(name: "Fortuna Brückenau", shortName: "FOR", stadium: "Brückenstadion", primary: "C8102E", secondary: "FFFFFF"),
        ClubSeed(name: "VfL Sonnenberg", shortName: "SON", stadium: "Sonnenhang", primary: "F57C00", secondary: "1D3C8F"),
        ClubSeed(name: "SC Waldeck", shortName: "WAL", stadium: "Waldeck Park", primary: "33691E", secondary: "F2C230")
    ])

    // MARK: - Italy

    static let italy = CountryInfo(code: "IT", leagueName: "Serie Azzurra", strength: 0.96, clubs: [
        ClubSeed(name: "AS Vesuviana", shortName: "VES", stadium: "Stadio Vulcano", primary: "12A0D7", secondary: "FFFFFF"),
        ClubSeed(name: "US Lagoverde", shortName: "LAG", stadium: "Stadio del Lago", primary: "1F7A3A", secondary: "1A1A1A"),
        ClubSeed(name: "Calcio Torrenera", shortName: "TNE", stadium: "La Torre", primary: "1A1A1A", secondary: "FFFFFF"),
        ClubSeed(name: "FC Portofiore", shortName: "PFI", stadium: "Stadio del Porto", primary: "C8102E", secondary: "1D3C8F"),
        ClubSeed(name: "SS Montalto", shortName: "MON", stadium: "Monte Alto", primary: "87CEEB", secondary: "FFFFFF"),
        ClubSeed(name: "AC Fiumerosso", shortName: "FIU", stadium: "Stadio Fiume", primary: "8E1B1B", secondary: "F2C230"),
        ClubSeed(name: "Sporting Bellavalle", shortName: "BEL", stadium: "Bellavalle", primary: "7B1FA2", secondary: "FFFFFF"),
        ClubSeed(name: "US Pietrabianca", shortName: "PIE", stadium: "Pietra Arena", primary: "F2F2F2", secondary: "C8102E"),
        ClubSeed(name: "AS Marenostro", shortName: "MAR", stadium: "Stadio del Mare", primary: "0F2A4A", secondary: "00A3E0"),
        ClubSeed(name: "FC Castelluce", shortName: "CAS", stadium: "Castello", primary: "F2C230", secondary: "8C1B2F"),
        ClubSeed(name: "Atletico Valdorcia", shortName: "VAL", stadium: "Val d'Orcia", primary: "B5651D", secondary: "FFFFFF"),
        ClubSeed(name: "US Ventoforte", shortName: "VEN", stadium: "Stadio del Vento", primary: "1E6FB8", secondary: "1A1A1A"),
        ClubSeed(name: "AC Rupescura", shortName: "RUP", stadium: "La Rupe", primary: "4A4A4A", secondary: "E57C00"),
        ClubSeed(name: "FC Arcobaleno", shortName: "ARC", stadium: "Arcobaleno Park", primary: "E53935", secondary: "FDD835"),
        ClubSeed(name: "SS Olmeto", shortName: "OLM", stadium: "Stadio Olmo", primary: "2E7D32", secondary: "FFFFFF"),
        ClubSeed(name: "AS Campodoro", shortName: "CDO", stadium: "Campo d'Oro", primary: "FDB913", secondary: "1A1A1A"),
        ClubSeed(name: "US Torrealta", shortName: "TAL", stadium: "Torre Alta", primary: "1D3C8F", secondary: "F2C230"),
        ClubSeed(name: "AC Serenella", shortName: "SER", stadium: "Stadio Sereno", primary: "00897B", secondary: "FFFFFF")
    ])

    // MARK: - France

    static let france = CountryInfo(code: "FR", leagueName: "Ligue Tricolore", strength: 0.93, clubs: [
        ClubSeed(name: "Lumière Saint-Clair", shortName: "LSC", stadium: "Parc Saint-Clair", primary: "0B2A5B", secondary: "D7262E"),
        ClubSeed(name: "Olympique Phocée", shortName: "OPH", stadium: "Vélodrome du Vieux-Port", primary: "2FAEE0", secondary: "FFFFFF"),
        ClubSeed(name: "Olympique Confluence", shortName: "OCF", stadium: "Stade des Deux Fleuves", primary: "1B3A8C", secondary: "E30613"),
        ClubSeed(name: "AS Rocheval", shortName: "ROC", stadium: "Stade du Rocher", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Dogues de Flandre", shortName: "DGF", stadium: "Stade des Beffrois", primary: "C8102E", secondary: "1D2C5E"),
        ClubSeed(name: "Stade Armoricain", shortName: "ARM", stadium: "Parc de la Vilaine", primary: "E30613", secondary: "111111"),
        ClubSeed(name: "Gym Azuréen", shortName: "AZU", stadium: "Stade de la Baie", primary: "B71C1C", secondary: "111111"),
        ClubSeed(name: "Sang et Or d'Artois", shortName: "SOA", stadium: "Stade des Mineurs", primary: "FDB913", secondary: "E30613"),
        ClubSeed(name: "Canaris de Loire", shortName: "CDL", stadium: "Stade des Canaris", primary: "FFE100", secondary: "1F7A3A"),
        ClubSeed(name: "Racing Rhénan", shortName: "RRH", stadium: "Stade du Rhin", primary: "0055A4", secondary: "FFFFFF"),
        ClubSeed(name: "Girondins d'Aquitaine", shortName: "GAQ", stadium: "Stade de Garonne", primary: "1B2A49", secondary: "FFFFFF"),
        ClubSeed(name: "Pailladins d'Occitanie", shortName: "POC", stadium: "Stade de l'Hérault", primary: "F47920", secondary: "1B3A8C"),
        ClubSeed(name: "Violets du Capitole", shortName: "VDC", stadium: "Stadium des Violettes", primary: "5B2C83", secondary: "FFFFFF"),
        ClubSeed(name: "Stade Champenois", shortName: "SCH", stadium: "Stade des Sacres", primary: "C8102E", secondary: "FFFFFF"),
        ClubSeed(name: "Verts du Forez", shortName: "VDF", stadium: "Chaudron Vert", primary: "00A651", secondary: "FFFFFF"),
        ClubSeed(name: "Pirates du Finistère", shortName: "PDF", stadium: "Stade de la Pointe", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Merlus du Morbihan", shortName: "MDM", stadium: "Stade des Merlus", primary: "F47920", secondary: "111111"),
        ClubSeed(name: "AJ Bourguignonne", shortName: "AJB", stadium: "Stade de l'Abbaye", primary: "1B3A8C", secondary: "FFFFFF")
    ])

    // MARK: - Portugal

    static let portugal = CountryInfo(code: "PT", leagueName: "Liga Lusitana", strength: 0.86, clubs: [
        ClubSeed(name: "SL Águias do Tejo", shortName: "AGT", stadium: "Estádio do Farol", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "FC Dragões do Douro", shortName: "DRD", stadium: "Estádio do Douro", primary: "0055A4", secondary: "FFFFFF"),
        ClubSeed(name: "Leões da Capital", shortName: "LDC", stadium: "Estádio Verde Real", primary: "00843D", secondary: "FFFFFF"),
        ClubSeed(name: "Arsenal do Minho", shortName: "ADM", stadium: "Estádio da Pedreira", primary: "C8102E", secondary: "FFFFFF"),
        ClubSeed(name: "Vitória Conquistadora", shortName: "VCO", stadium: "Estádio do Castelo", primary: "FFFFFF", secondary: "111111"),
        ClubSeed(name: "Restelo Atlético", shortName: "RAT", stadium: "Estádio do Restelo", primary: "1B3A8C", secondary: "FFFFFF"),
        ClubSeed(name: "Axadrezados do Bessa", shortName: "AXB", stadium: "Estádio Xadrez", primary: "111111", secondary: "FFFFFF"),
        ClubSeed(name: "Marítimo Insular", shortName: "MIN", stadium: "Estádio dos Barreiros", primary: "00843D", secondary: "E30613"),
        ClubSeed(name: "Rio Vale FC", shortName: "RVF", stadium: "Estádio dos Arcos", primary: "00843D", secondary: "FFFFFF"),
        ClubSeed(name: "Famalicense SC", shortName: "FAM", stadium: "Estádio Minhoto", primary: "1B3A8C", secondary: "FFFFFF"),
        ClubSeed(name: "Galo de Barcelos", shortName: "GDB", stadium: "Estádio do Galo", primary: "E30613", secondary: "1B3A8C"),
        ClubSeed(name: "Costa do Sol FC", shortName: "CDS", stadium: "Estádio da Costa", primary: "FDB913", secondary: "1B3A8C"),
        ClubSeed(name: "Casa Lisboeta", shortName: "CLI", stadium: "Estádio Pina", primary: "111111", secondary: "FFFFFF"),
        ClubSeed(name: "Serra de Arouca", shortName: "SDA", stadium: "Estádio da Serra", primary: "FDB913", secondary: "1B3A8C"),
        ClubSeed(name: "Moreira Cónego", shortName: "MCO", stadium: "Parque do Cónego", primary: "00843D", secondary: "FFFFFF"),
        ClubSeed(name: "Açores Atlântico", shortName: "AAT", stadium: "Estádio do Atlântico", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Trás-os-Montes FC", shortName: "TMF", stadium: "Estádio das Termas", primary: "1B3A8C", secondary: "E30613"),
        ClubSeed(name: "Algarve Farense", shortName: "ALF", stadium: "Estádio do Algarve", primary: "111111", secondary: "FFFFFF")
    ])

    // MARK: - Netherlands

    static let netherlands = CountryInfo(code: "NL", leagueName: "Polder Divisie", strength: 0.84, clubs: [
        ClubSeed(name: "Amstel Ajacieden", shortName: "AMA", stadium: "Amstel Arena", primary: "D2122E", secondary: "FFFFFF"),
        ClubSeed(name: "Maasstad Rotterdam", shortName: "MAA", stadium: "Havenstadion", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Lichtstad Eindhoven", shortName: "LIE", stadium: "Lichtstad Stadion", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Kaasstad Alkmaar", shortName: "KAA", stadium: "Kaasmarkt Park", primary: "D2122E", secondary: "FFFFFF"),
        ClubSeed(name: "Tukkers Twente", shortName: "TUT", stadium: "De Veste", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Domstad Utrecht", shortName: "DOU", stadium: "Domstadion", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Friese Pompeblêden", shortName: "FRP", stadium: "Abe's Veld", primary: "1B3A8C", secondary: "FFFFFF"),
        ClubSeed(name: "Noorderlicht Groningen", shortName: "NOG", stadium: "Noorderpark", primary: "00843D", secondary: "FFFFFF"),
        ClubSeed(name: "Gelre Vitesse", shortName: "GEV", stadium: "Gelre Koepel", primary: "FDB913", secondary: "111111"),
        ClubSeed(name: "Kasteel Sparta", shortName: "KSP", stadium: "Het Kasteel", primary: "E30613", secondary: "FFFFFF"),
        ClubSeed(name: "Adelaars Deventer", shortName: "ADE", stadium: "De Adelaar", primary: "E30613", secondary: "FDB913"),
        ClubSeed(name: "Waal Nijmegen", shortName: "WAN", stadium: "Waalstadion", primary: "E30613", secondary: "00843D"),
        ClubSeed(name: "Almelo Heraclieden", shortName: "ALH", stadium: "Almelo Arena", primary: "111111", secondary: "FFFFFF"),
        ClubSeed(name: "Koning Willem Tilburg", shortName: "KWT", stadium: "Koningsstadion", primary: "1B3A8C", secondary: "E30613"),
        ClubSeed(name: "Fortuna Limburgia", shortName: "FOL", stadium: "Zitterd Park", primary: "FDB913", secondary: "00843D"),
        ClubSeed(name: "Blauwvingers Zwolle", shortName: "BLZ", stadium: "Blauwvinger Park", primary: "1B3A8C", secondary: "FFFFFF"),
        ClubSeed(name: "Polderstad Almere", shortName: "POA", stadium: "Polderstadion", primary: "E30613", secondary: "111111"),
        ClubSeed(name: "Baronie Breda", shortName: "BAB", stadium: "Baronie Stadion", primary: "FDB913", secondary: "111111")
    ])
}
