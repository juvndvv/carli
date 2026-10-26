import 'models.dart';
import 'text_fold.dart';

const _keywordsBySection = {
  'fruta y verdura': 'platano|manzana|pera|naranja|mandarina|limon|fresa|uva|melon|sandia|kiwi|aguacate|tomate|lechuga|cebolla|ajo|patata|zanahoria|pimiento|pepino|calabacin|berenjena|espinaca|brocoli|coliflor|champinon|seta|fruta|verdura|puerro|judia|calabaza|mango|pina|melocoton|cereza|rucula|canonigo|perejil|cilantro|albahaca',
  'carne y pescado': 'pollo|ternera|cerdo|cordero|pavo|carne|filete|hamburguesa|salchicha|chorizo|jamon|lomo|bacon|pescado|salmon|merluza|atun fresco|gamba|langostino|calamar|sepia|mejillon|bacalao|dorada|lubina|pechuga|muslo|costilla|embutido|fuet|pavo',
  'lacteos y huevos': 'leche|yogur|queso|mantequilla|nata|huevo|kefir|requeson|cuajada|flan|natillas',
  'panaderia': 'pan|baguette|barra|croissant|magdalena|bolleria|tostada|bizcocho|galleta',
  'despensa': 'arroz|pasta|macarron|espagueti|harina|azucar|sal|aceite|vinagre|cafe|te|infusion|cacao|cereal|avena|legumbre|garbanzo|lenteja|alubia|atun|sardina|conserva|tomate frito|especia|pimienta|mermelada|miel|chocolate|frutos secos|nuez|almendra|caldo|quinoa|cuscus|tortilla de trigo|salsa|mayonesa|ketchup|mostaza',
  'congelados': 'congelad|helado|pizza|hielo|croqueta|guisante',
  'bebidas': 'agua|cerveza|vino|refresco|zumo|cola|tonica|gaseosa|cava|bebida',
  'limpieza': 'lavavajillas|detergente|suavizante|lejia|friegasuelos|limpia|estropajo|bayeta|papel de cocina|servilleta|bolsa de basura|bolsas de basura|fregona|insecticida|ambientador|papel de aluminio|papel film|pastillas',
  'higiene': 'champu|gel|jabon|pasta de dientes|dentifrico|cepillo|desodorante|papel higienico|compresa|tampon|cuchilla|crema|colonia|algodon|toallita|panal|enjuague|seda dental',
};

/// Picks a supermarket section for a product the list has never seen, by keywords in its name.
String? guessSectionId(String productName, List<ShoppingSection> sections) {
  final name = ' ${fold(productName)} ';
  String? bestSection;
  var bestLength = 0;
  for (final MapEntry(key: section, value: keywords) in _keywordsBySection.entries) {
    for (final keyword in keywords.split('|')) {
      final match = name.contains(' $keyword') && keyword.length > bestLength;
      if (match) {
        bestSection = section;
        bestLength = keyword.length;
      }
    }
  }
  if (bestSection == null) return null;
  return sections.where((section) => fold(section.name) == bestSection).firstOrNull?.id;
}
