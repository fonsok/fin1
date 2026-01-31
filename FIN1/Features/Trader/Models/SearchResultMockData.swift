import Foundation

// MARK: - Search Result Mock Data
/// Mock data for SearchResult testing and development

let mockSearchResults: [SearchResult] = [
    // Optionsscheine - Call (Société Générale)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG3D56",
        strike: "22.200",
        askPrice: "1,23",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Aktie",
        isin: "DE000SG3D56",
        underlyingAsset: "Apple"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG7A89",
        strike: "15.500",
        askPrice: "2,45",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG7A89",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG1C23",
        strike: "19.800",
        askPrice: "3,15",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG1C23",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG4E56",
        strike: "12.100",
        askPrice: "1,88",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG4E56",
        underlyingAsset: "DAX"
    ),

    // Optionsscheine - Call (Deutsche Bank)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB4321",
        strike: "18.900",
        askPrice: "0,98",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB4321",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB9876",
        strike: "25.100",
        askPrice: "3,12",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB9876",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB5A43",
        strike: "21.300",
        askPrice: "2,67",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB5A43",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB8B21",
        strike: "16.700",
        askPrice: "1,45",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB8B21",
        underlyingAsset: "DAX"
    ),

    // Optionsscheine - Put (Société Générale)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG9F12",
        strike: "14.200",
        askPrice: "0,87",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG9F12",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG2H45",
        strike: "17.800",
        askPrice: "1,23",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG2H45",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG6K78",
        strike: "20.100",
        askPrice: "2,15",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG6K78",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "SG3L91",
        strike: "13.500",
        askPrice: "0,65",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000SG3L91",
        underlyingAsset: "DAX"
    ),

    // Optionsscheine - Put (Deutsche Bank)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB7M24",
        strike: "19.300",
        askPrice: "1,78",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB7M24",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB1N57",
        strike: "15.600",
        askPrice: "0,92",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB1N57",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB4P80",
        strike: "22.400",
        askPrice: "2,34",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB4P80",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "DB8Q13",
        strike: "18.700",
        askPrice: "1,56",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000DB8Q13",
        underlyingAsset: "DAX"
    ),

    // Optionsscheine - Call (Vontobel)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT1234",
        strike: "16.200",
        askPrice: "1,85",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT1234",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT5678",
        strike: "23.800",
        askPrice: "2,67",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT5678",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT9012",
        strike: "14.500",
        askPrice: "1,23",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT9012",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT3456",
        strike: "21.100",
        askPrice: "2,45",
        direction: "Call",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT3456",
        underlyingAsset: "DAX"
    ),

    // Optionsscheine - Put (Vontobel)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT7890",
        strike: "17.300",
        askPrice: "1,67",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT7890",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT2468",
        strike: "20.600",
        askPrice: "2,12",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT2468",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT1357",
        strike: "15.900",
        askPrice: "1,45",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT1357",
        underlyingAsset: "DAX"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "VT9753",
        strike: "18.400",
        askPrice: "1,89",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000VT9753",
        underlyingAsset: "DAX"
    ),

    // Aktien (Stocks)
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "865985",
        strike: "175.50",
        askPrice: "175,50",
        direction: nil,
        underlyingType: "Aktie",
        isin: "US0378331005",
        underlyingAsset: "Apple"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "519000",
        strike: "85.20",
        askPrice: "85,20",
        direction: nil,
        underlyingType: "Aktie",
        isin: "DE0005190003",
        underlyingAsset: "BMW"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "A1CX3T",
        strike: "245.80",
        askPrice: "245,80",
        direction: nil,
        underlyingType: "Aktie",
        isin: "US88160R1014",
        underlyingAsset: "Tesla"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "870747",
        strike: "420.15",
        askPrice: "420,15",
        direction: nil,
        underlyingType: "Aktie",
        isin: "US5949181045",
        underlyingAsset: "Microsoft"
    ),
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "A0B7X2",
        strike: "145.30",
        askPrice: "145,30",
        direction: nil,
        underlyingType: "Aktie",
        isin: "US02079K3059",
        underlyingAsset: "Google"
    ),

    // Index
    SearchResult(
        valuationDate: "31.12.2000",
        wkn: "846900",
        strike: "15.234,50",
        askPrice: "15.234,50",
        direction: nil,
        underlyingType: "Index",
        isin: "DE0008469008",
        underlyingAsset: "DAX"
    )
]
