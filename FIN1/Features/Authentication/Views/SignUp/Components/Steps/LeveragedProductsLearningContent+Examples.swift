import Foundation

// MARK: - In-app learning copy (calculation examples)

enum LeveragedProductsLearningExamples {
    static let formulaIntro = """
    Der Wert eines klassischen Optionsscheins zum Laufzeitende berechnet sich aus der Formel:
    """

    static let callFormulaAtExpiry = "Wert am Laufzeitende = (Aktienkurs − Basispreis) × Bezugsverhältnis"
    static let putFormulaAtExpiry = "Wert am Laufzeitende = (Basispreis − Aktienkurs) × Bezugsverhältnis"

    static let examplesIntro = """
    Hier sind zwei konkrete Rechenbeispiele für einen Call-Optionsschein (Spekulation auf steigende Kurse) \
    und einen Put-Optionsschein (Spekulation auf fallende Kurse) zum Ende der Laufzeit.
    """

    // MARK: Call example (XYZ)

    static let callExampleTitle = "Beispiel 1: Call-Optionsschein (auf steigende Kurse setzen)"
    static let callExampleSetup = """
    Sie erwarten, dass die Aktie XYZ steigt, und kaufen einen Call-Optionsschein.
    
    • Aktueller Aktienkurs bei Kauf: 100 Euro
    • Basispreis (Strike): 100 Euro
    • Bezugsverhältnis: 0,1 (10 Optionsscheine verbriefen das Recht für 1 Aktie)
    • Preis des Optionsscheins (Prämie): 1,50 Euro
    """

    static let callScenarioAGain = """
    Szenario A: Die Aktie steigt auf 130 Euro (Gewinn)
    
    Berechnung des inneren Werts:
    (130 Euro − 100 Euro) × 0,1 = 3,00 Euro
    
    Der Schein ist am Laufzeitende 3,00 Euro wert.
    
    Ihr Reingewinn:
    3,00 Euro (Wert) − 1,50 Euro (Kaufpreis) = 1,50 Euro Gewinn pro Schein
    
    Hebel-Effekt: Während die Aktie um 30 % gestiegen ist, hat Ihr Optionsschein eine Rendite von 100 % erzielt.
    """

    static let callScenarioBLoss = """
    Szenario B: Die Aktie fällt oder bleibt unter 100 Euro (Verlust)
    
    Notiert die Aktie am Ende bei z. B. 95 Euro, hat der Call-Optionsschein keinen inneren Wert.
    Es findet keine Auszahlung statt.
    
    Ergebnis: Totalverlust der eingesetzten 1,50 Euro pro Schein.
    """

    // MARK: Put example (XYZ)

    static let putExampleTitle = "Beispiel 2: Put-Optionsschein (auf fallende Kurse setzen)"
    static let putExampleSetup = """
    Sie erwarten, dass die Aktie XYZ fällt, und kaufen einen Put-Optionsschein.
    
    • Aktueller Aktienkurs bei Kauf: 50 Euro
    • Basispreis (Strike): 50 Euro
    • Bezugsverhältnis: 1,0 (1 Optionsschein verbrieft das Recht für 1 Aktie)
    • Preis des Optionsscheins (Prämie): 4,00 Euro
    """

    static let putScenarioAGain = """
    Szenario A: Die Aktie fällt auf 40 Euro (Gewinn)
    
    Berechnung des inneren Werts beim Put:
    (Basispreis − Aktienkurs) × Bezugsverhältnis
    (50 Euro − 40 Euro) × 1,0 = 10,00 Euro
    
    Der Schein ist am Laufzeitende 10,00 Euro wert.
    
    Ihr Reingewinn:
    10,00 Euro (Wert) − 4,00 Euro (Kaufpreis) = 6,00 Euro Gewinn pro Schein
    
    Hebel-Effekt: Die Aktie ist um 20 % gefallen, Ihr Optionsschein hat einen Gewinn von 150 % erzielt.
    """

    static let putScenarioBLoss = """
    Szenario B: Die Aktie steigt oder bleibt über 50 Euro (Verlust)
    
    Notiert die Aktie am Ende bei z. B. 55 Euro, ist das Recht zum Verkauf für 50 Euro wertlos.
    
    Ergebnis: Der Put-Optionsschein verfällt wertlos (Totalverlust des Einsatzes).
    """

    // MARK: Concrete stock (BMW)

    static let bmwExampleTitle = "Konkretes Beispiel: Call auf BMW AG"
    static let bmwExampleBody = """
    Sie kaufen einen Call-Optionsschein auf die BMW-Aktie und halten ihn bis zum Laufzeitende.
    
    • Aktienkurs bei Kauf: 90,00 Euro
    • Basispreis (Strike): 90,00 Euro
    • Bezugsverhältnis: 0,1
    • Prämie (Kaufpreis des Scheins): 1,20 Euro
    
    Am Laufzeitende notiert BMW bei 110,00 Euro:
    
    Innerer Wert = (110,00 − 90,00) × 0,1 = 2,00 Euro
    Reingewinn = 2,00 Euro − 1,20 Euro = 0,80 Euro pro Schein
    
    Die Aktie ist um rund 22 % gestiegen, der Optionsschein hat etwa 67 % Gewinn erzielt.
    
    Fällt BMW am Laufzeitende auf 88,00 Euro oder darunter, verfällt der Call wertlos — \
    Totalverlust der Prämie von 1,20 Euro pro Schein.
    """

    static let beforeExpiryNote = """
    Wichtiger Hinweis für den Handel vor Laufzeitende
    
    Die obigen Beispiele zeigen den Wert am exakten Laufzeitende. Wenn Sie Optionsscheine während der Laufzeit \
    an der Börse verkaufen, setzt sich der Preis aus dem inneren Wert und dem Zeitwert zusammen. \
    Der Zeitwert wird maßgeblich von der Restlaufzeit und der Schwankungsbreite (Volatilität) der Aktie beeinflusst.
    """
}
